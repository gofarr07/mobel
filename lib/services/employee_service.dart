
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/employee.dart';

class EmployeeService {
  final String token;

  EmployeeService({required this.token});

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${token.trim()}',
  };

  Future<List<Employee>> getEmployees() async {
    if (token.trim().isEmpty) {
      throw Exception('Token login tidak ditemukan.');
    }

    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/employees.php'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));

    final dynamic result = jsonDecode(response.body);

    if (response.statusCode != 200 ||
        result is! Map<String, dynamic> ||
        result['success'] != true ||
        result['data'] is! List) {
      throw Exception(
        result is Map
            ? result['message'] ?? 'Gagal mengambil data karyawan.'
            : 'Gagal mengambil data karyawan.',
      );
    }

    final List<dynamic> data = result['data'];

    return data
        .map(
          (item) => Employee.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> addEmployee({
    required String fullName,
    required String phone,
    required String position,
    required String username,
    required String password,
    required double shiftRate,
    required String hireDate,
  }) async {
    if (token.trim().isEmpty) {
      throw Exception('Token login tidak ditemukan.');
    }

    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/employees.php'),
          headers: _headers,
          body: jsonEncode({
            'full_name': fullName.trim(),
            'phone': phone.trim(),
            'position': position.trim(),
            'username': username.trim(),
            'password': password,
            'shift_rate': shiftRate,
            'hire_date': hireDate,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final dynamic result = jsonDecode(response.body);

    if (result is! Map<String, dynamic> ||
        response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] != true) {
      throw Exception(
        result is Map
            ? result['message'] ?? 'Gagal menambahkan karyawan.'
            : 'Respons server tidak valid.',
      );
    }
  }
}
