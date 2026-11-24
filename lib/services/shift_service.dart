import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/shift.dart';

class ShiftService {
  final String token;
  final http.Client _client;

  ShiftService({
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      };

  void _checkToken() {
    if (token.trim().isEmpty) {
      throw Exception(
        'Token login kosong. Silakan login kembali.',
      );
    }
  }

  dynamic _decodeResponse(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw Exception(
        'Respons server bukan JSON yang valid.',
      );
    }
  }

  String _getMessage(
    dynamic result,
    String defaultMessage,
  ) {
    if (result is Map<String, dynamic>) {
      final message = result['message'];

      if (message != null &&
          message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }

    return defaultMessage;
  }

  /// Mengambil jadwal shift.
  Future<List<Shift>> getShifts({
    String? date,
    String? branch,
  }) async {
    _checkToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/shifts.php',
    );

    final response = await _client
        .get(
          uri,
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));

    final result = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        _getMessage(
          result,
          'Gagal mengambil jadwal shift.',
        ),
      );
    }

    if (result is! Map<String, dynamic> ||
        result['success'] != true ||
        result['data'] is! List) {
      throw Exception(
        _getMessage(
          result,
          'Format respons jadwal tidak valid.',
        ),
      );
    }

    return (result['data'] as List)
        .map(
          (item) => Shift.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Menambahkan jadwal shift.
  Future<void> addShift({
    required int employeeId,
    required String branch,
    required String shiftDate,
  }) async {
    _checkToken();

    if (branch != 'A' && branch != 'B') {
      throw Exception(
        'Cabang hanya boleh A atau B.',
      );
    }

    final response = await _client
        .post(
          Uri.parse(
            '${ApiConfig.baseUrl}/shifts.php',
          ),
          headers: {
            ..._headers,
            'Content-Type':
                'application/json; charset=UTF-8',
          },
          body: jsonEncode({
            'employee_id': employeeId,
            'branch': branch,
            'shift_date': shiftDate,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final result = _decodeResponse(response.body);

    if (result is! Map<String, dynamic>) {
      throw Exception(
        'Format respons server tidak valid.',
      );
    }

    if (response.statusCode != 201 ||
        result['success'] != true) {
      throw Exception(
        _getMessage(
          result,
          'Gagal menambahkan jadwal shift.',
        ),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
