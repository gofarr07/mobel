
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client})
      : _client = client ?? http.Client();

  // =========================================================
  // LOGIN
  // =========================================================

  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const AuthException(
        'Username dan password wajib diisi.',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': normalizedUsername,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'LOGIN STATUS: ${response.statusCode}',
      );

      final decoded = _decodeResponse(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const AuthException(
          'Format respons dari server tidak valid.',
        );
      }

      if (response.statusCode == 401) {
        return null;
      }

      if (response.statusCode != 200) {
        throw AuthException(
          _getMessage(
            decoded,
            'Server gagal memproses login.',
          ),
        );
      }

      if (decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        throw AuthException(
          _getMessage(
            decoded,
            'Respons login tidak sesuai format.',
          ),
        );
      }

      final userData = Map<String, dynamic>.from(
        decoded['data'] as Map<String, dynamic>,
      );

      final user = AppUser.fromJson(userData);

      if (!user.isActive) {
        return null;
      }

      if (user.token.trim().isEmpty) {
        throw const AuthException(
          'Token login tidak ditemukan dari server. '
          'Periksa login.php.',
        );
      }

      // Log aman: tidak menampilkan token asli.
      debugPrint('LOGIN BERHASIL');
      debugPrint('USER ID: ${user.id}');
      debugPrint('ROLE: ${user.role.name}');
      debugPrint(
        'TOKEN TERSEDIA: ${user.token.isNotEmpty}',
      );
      debugPrint(
        'TOKEN LENGTH: ${user.token.length}',
      );

      return user;
    } on TimeoutException {
      throw const AuthException(
        'Server terlalu lama merespons. Coba lagi.',
      );
    } on http.ClientException catch (e) {
      debugPrint('LOGIN CLIENT ERROR: ${e.message}');

      throw const AuthException(
        'Tidak dapat terhubung ke server. '
        'Periksa koneksi dan URL API.',
      );
    } on FormatException {
      throw const AuthException(
        'Respons server bukan JSON yang valid.',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      throw const AuthException(
        'Terjadi kesalahan saat login.',
      );
    }
  }

  // =========================================================
  // VALIDASI SESSION
  // =========================================================

  Future<AppUser?> validateSession(String token) async {
    if (token.trim().isEmpty) {
      debugPrint('VALIDATE SESSION: Token kosong.');
      return null;
    }

    try {
      final response = await _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/validate_session.php',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'VALIDATE SESSION STATUS: ${response.statusCode}',
      );

      debugPrint(
        'VALIDATE SESSION RESPONSE: ${response.body}',
      );

      if (response.statusCode == 401) {
        debugPrint('VALIDATE SESSION: Token tidak valid.');
        return null;
      }

      if (response.statusCode != 200) {
        debugPrint(
          'VALIDATE SESSION: HTTP ${response.statusCode}',
        );
        return null;
      }

      final decoded = _decodeResponse(response.body);

      if (decoded is! Map<String, dynamic>) {
        debugPrint(
          'VALIDATE SESSION: Format JSON tidak valid.',
        );
        return null;
      }

      if (decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        debugPrint(
          'VALIDATE SESSION: Respons tidak berhasil.',
        );
        return null;
      }

      final data = Map<String, dynamic>.from(
        decoded['data'] as Map<String, dynamic>,
      );

      // Endpoint validasi sesi tidak harus mengirim token kembali.
      // Token yang sedang digunakan dipertahankan di Flutter.
      data['token'] = token;

      final user = AppUser.fromJson(data);

      if (!user.isActive || user.token.trim().isEmpty) {
        debugPrint(
          'VALIDATE SESSION: User tidak aktif atau token kosong.',
        );
        return null;
      }

      debugPrint('VALIDATE SESSION BERHASIL');
      debugPrint('USER ID: ${user.id}');
      debugPrint('ROLE: ${user.role.name}');

      return user;
    } on TimeoutException {
      debugPrint('VALIDATE SESSION: Request timeout.');
      return null;
    } on http.ClientException catch (e) {
      debugPrint(
        'VALIDATE SESSION CLIENT ERROR: ${e.message}',
      );
      return null;
    } on FormatException catch (e) {
      debugPrint(
        'VALIDATE SESSION JSON ERROR: $e',
      );
      return null;
    } catch (e) {
      debugPrint(
        'VALIDATE SESSION ERROR: $e',
      );
      return null;
    }
  }

  // =========================================================
  // HELPER: DECODE JSON
  // =========================================================

  dynamic _decodeResponse(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const AuthException(
        'Respons server bukan JSON yang valid.',
      );
    }
  }

  // =========================================================
  // HELPER: AMBIL PESAN SERVER
  // =========================================================

  String _getMessage(
    Map<String, dynamic> data,
    String defaultMessage,
  ) {
    final message = data['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return defaultMessage;
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  void dispose() {
    _client.close();
  }
}

// ===========================================================
// AUTH EXCEPTION
// ===========================================================

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
