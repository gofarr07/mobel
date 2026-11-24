import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/notification_model.dart';

class NotificationService {
  final String token;

  NotificationService({
    required this.token,
  });

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      };

  // =========================================================
  // REQUEST API
  // =========================================================

  Future<Map<String, dynamic>> _request(
    Future<http.Response> request, {
    required String endpoint,
  }) async {
    try {
      debugPrint('NOTIFICATION REQUEST: $endpoint');

      final response = await request.timeout(
        const Duration(seconds: 15),
      );

      debugPrint(
        'NOTIFICATION STATUS: ${response.statusCode}',
      );

      debugPrint(
        'NOTIFICATION RESPONSE: ${response.body}',
      );

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const NotificationException(
          'Respons server bukan JSON yang valid. '
          'Periksa kode PHP dan respons API.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw const NotificationException(
          'Format respons server tidak valid.',
        );
      }

      if (response.statusCode == 401) {
        throw const NotificationException(
          'Sesi login berakhir atau token tidak valid. '
          'Silakan login kembali.',
        );
      }

      if (response.statusCode == 403) {
        throw const NotificationException(
          'Akses notifikasi ditolak oleh server.',
        );
      }

      if (response.statusCode == 404) {
        throw const NotificationException(
          'Endpoint notifikasi tidak ditemukan. '
          'Periksa nama file PHP dan URL API.',
        );
      }

      if (response.statusCode >= 500) {
        throw NotificationException(
          'Server mengalami kesalahan '
          '(${response.statusCode}). Periksa PHP dan database.',
        );
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw NotificationException(
          decoded['message']?.toString() ??
              'Permintaan gagal. '
                  'HTTP ${response.statusCode}.',
        );
      }

      if (decoded['success'] != true) {
        throw NotificationException(
          decoded['message']?.toString() ??
              'Permintaan notifikasi gagal.',
        );
      }

      return decoded;
    } on TimeoutException {
      debugPrint(
        'NOTIFICATION TIMEOUT: $endpoint',
      );

      throw const NotificationException(
        'Server terlalu lama merespons. '
        'Periksa koneksi dan Apache XAMPP.',
      );
    } on http.ClientException catch (e) {
      debugPrint(
        'NOTIFICATION CLIENT ERROR: ${e.message}',
      );

      throw NotificationException(
        'Tidak dapat terhubung ke server. '
        'Periksa URL API, Apache, dan CORS. '
        'Detail: ${e.message}',
      );
    } on NotificationException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
        'NOTIFICATION UNKNOWN ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      throw const NotificationException(
        'Terjadi kesalahan saat memproses notifikasi.',
      );
    }
  }

  // =========================================================
  // MENGAMBIL DAFTAR NOTIFIKASI
  // =========================================================

  Future<NotificationResult> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    if (page < 1 || limit < 1) {
      throw const NotificationException(
        'Nomor halaman atau jumlah data tidak valid.',
      );
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications_list.php',
    ).replace(
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );

    final json = await _request(
      http.get(
        uri,
        headers: _headers,
      ),
      endpoint: uri.toString(),
    );

    final data = json['data'];

    if (data is! List) {
      throw const NotificationException(
        'Data notifikasi tidak berbentuk daftar.',
      );
    }

    final notifications = data
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();

    final pagination = json['pagination'];

    final info = pagination is Map<String, dynamic>
        ? pagination
        : <String, dynamic>{};

    return NotificationResult(
      notifications: notifications,
      unreadCount: _asInt(info['unread_count']),
      total: _asInt(info['total']),
      page: _asInt(
        info['page'],
        fallback: page,
      ),
      totalPages: _asInt(
        info['total_pages'],
        fallback: 1,
      ),
    );
  }

  // =========================================================
  // TES NOTIFIKASI UNTUK AKUN YANG SEDANG LOGIN
  // =========================================================

  Future<void> sendTestNotification() async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications_test.php',
    );

    await _request(
      http.post(
        uri,
        headers: _headers,
        body: jsonEncode({}),
      ),
      endpoint: uri.toString(),
    );
  }

  // =========================================================
  // MENANDAI SATU NOTIFIKASI SUDAH DIBACA
  // =========================================================

  Future<void> markAsRead(
    String notificationId,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications_read.php',
    );

    final parsedId = int.tryParse(notificationId);

    if (parsedId == null || parsedId <= 0) {
      throw const NotificationException(
        'ID notifikasi tidak valid.',
      );
    }

    await _request(
      http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'notification_id': parsedId,
        }),
      ),
      endpoint: uri.toString(),
    );
  }

  // =========================================================
  // MENANDAI SEMUA NOTIFIKASI SUDAH DIBACA
  // =========================================================

  Future<void> markAllAsRead() async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications_read_all.php',
    );

    await _request(
      http.post(
        uri,
        headers: _headers,
        body: jsonEncode({}),
      ),
      endpoint: uri.toString(),
    );
  }

  // =========================================================
  // KONVERSI DATA ANGKA
  // =========================================================

  static int _asInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }
}

// =========================================================
// HASIL PENGAMBILAN DAFTAR NOTIFIKASI
// =========================================================

class NotificationResult {
  final List<AppNotification> notifications;
  final int unreadCount;
  final int total;
  final int page;
  final int totalPages;

  const NotificationResult({
    required this.notifications,
    required this.unreadCount,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

// =========================================================
// ERROR KHUSUS NOTIFIKASI
// =========================================================

class NotificationException implements Exception {
  final String message;

  const NotificationException(this.message);

  @override
  String toString() => message;
}