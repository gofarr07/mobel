import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';

class AttendancePage extends StatefulWidget {
  final AppUser user;

  const AttendancePage({super.key, required this.user});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _shifts = [];

  bool _loading = true;
  bool _processing = false;
  String? _error;

  Uri get _attendanceUri => Uri.parse('${ApiConfig.baseUrl}/attendance.php');

  Uri get _shiftsUri => Uri.parse('${ApiConfig.baseUrl}/shifts.php');

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${widget.user.token}',
      };

  bool get _isManager => widget.user.role == UserRole.manager;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, dynamic>> _getJson(http.Response response) async {
    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format respons server tidak valid.');
    }

    if (response.statusCode == 401) {
      throw Exception(
        'Sesi login tidak valid atau kedaluwarsa. Silakan login kembali.',
      );
    }

    if (decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'Permintaan gagal.');
    }

    return decoded;
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait([
        http
            .get(_attendanceUri, headers: _headers)
            .timeout(const Duration(seconds: 15)),
        if (!_isManager)
          http
              .get(_shiftsUri, headers: _headers)
              .timeout(const Duration(seconds: 15)),
      ]);

      final attendanceJson = await _getJson(responses[0]);
      final attendanceData = attendanceJson['data'];

      if (attendanceData is! List) {
        throw Exception('Data riwayat absensi tidak valid.');
      }

      List<Map<String, dynamic>> shifts = [];

      if (!_isManager) {
        final shiftsJson = await _getJson(responses[1]);
        final shiftsData = shiftsJson['data'];

        if (shiftsData is List) {
          shifts = shiftsData
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }

      if (!mounted) return;

      setState(() {
        _records = attendanceData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _shifts = shifts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception(
        'Aktifkan layanan lokasi/GPS pada perangkat terlebih dahulu.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi belum diberikan.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan aplikasi.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _submitAttendance({
    required String action,
    required int id,
    required bool skipLocation,
  }) async {
    if (_processing) return;

    setState(() {
      _processing = true;
    });

    try {
      final body = <String, dynamic>{
        'action': action,
        'skip_location': skipLocation,
      };

      // GPS hanya diminta jika menggunakan tombol dengan lokasi.
      if (!skipLocation) {
        final position = await _getPosition();

        body['latitude'] = position.latitude;
        body['longitude'] = position.longitude;
      }

      if (action == 'check_in') {
        body['shift_id'] = id;
      } else {
        body['attendance_id'] = id;
      }

      final response = await http
          .post(
            _attendanceUri,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final result = await _getJson(response);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Absensi berhasil.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _confirmAttendance({
    required String action,
    required int id,
    required bool skipLocation,
  }) async {
    final isCheckIn = action == 'check_in';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isCheckIn ? 'Konfirmasi Check-in' : 'Konfirmasi Check-out',
          ),
          content: Text(
            skipLocation
                ? 'Kamu akan melakukan ${isCheckIn ? 'check-in' : 'check-out'} TANPA pemeriksaan lokasi. '
                    'Fitur ini ditujukan untuk uji coba. Lanjutkan?'
                : 'Kamu akan melakukan ${isCheckIn ? 'check-in' : 'check-out'} dengan pemeriksaan GPS dan radius 100 meter. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: skipLocation
                    ? Colors.orange.shade800
                    : const Color(0xFF8C5E3C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lanjutkan'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _submitAttendance(
        action: action,
        id: id,
        skipLocation: skipLocation,
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';

    final text = value.toString();
    final parts = text.split('-');

    if (parts.length != 3) return text;

    return '${parts[2].split(' ').first}/${parts[1]}/${parts[0]}';
  }

  String _formatTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';

    final text = value.toString();
    if (text.length >= 16) return text.substring(11, 16);
    if (text.length >= 5) return text.substring(0, 5);

    return text;
  }

  String _statusLabel(dynamic value) {
    switch (value?.toString()) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat':
        return 'Terlambat';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
        return 'Alpa';
      case 'belum_absen':
        return 'Belum absen';
      default:
        return value?.toString() ?? '-';
    }
  }

  bool _isOpenAttendance(Map<String, dynamic> record) {
    return record['check_in'] != null &&
        record['check_in'].toString().isNotEmpty &&
        (record['check_out'] == null ||
            record['check_out'].toString().isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    const lightBg = Color(0xFFFAFAFA);
    const primaryBrown = Color(0xFF8C5E3C);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Absensi',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _processing ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryBrown),
            )
          : RefreshIndicator(
              color: primaryBrown,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  _buildInfoCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorCard(),
                  ],
                  if (!_isManager) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Jadwal untuk Check-in',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildShiftList(),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    _isManager
                        ? 'Riwayat Absensi Karyawan'
                        : 'Riwayat Absensi Saya',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Belum ada data absensi.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    )
                  else
                    ..._records.map(_buildAttendanceCard),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    const primaryBrown = Color(0xFF8C5E3C);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE8E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 24,
              color: primaryBrown,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Absensi Cabang A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pilih metode absensi dengan lokasi atau tanpa lokasi (uji coba). '
                  'Metode dengan lokasi tetap memerlukan GPS dan radius 100 meter.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _error!,
        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
      ),
    );
  }

  Widget _buildShiftList() {
    const primaryBrown = Color(0xFF8C5E3C);

    final availableShifts = _shifts.where((shift) {
      final id = int.tryParse(shift['id']?.toString() ?? '');

      if (id == null) return false;

      return !_records.any(
        (record) =>
            record['shift_id']?.toString() == id.toString() &&
            record['check_in'] != null &&
            record['check_in'].toString().isNotEmpty,
      );
    }).toList();

    if (availableShifts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Tidak ada jadwal yang tersedia untuk check-in. Pastikan jadwal shift sudah dibuat.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      );
    }

    return Column(
      children: availableShifts.map((shift) {
        final shiftId = int.tryParse(shift['id'].toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9F5F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: primaryBrown,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${shift['branch'] ?? 'Cabang'} • ${_formatDate(shift['shift_date'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatTime(shift['start_time'])}–${_formatTime(shift['end_time'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _processing || shiftId == null
                        ? null
                        : () => _confirmAttendance(
                              action: 'check_in',
                              id: shiftId,
                              skipLocation: false,
                            ),
                    icon: const Icon(Icons.location_on_rounded),
                    label: const Text('Check-in dengan Lokasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _processing || shiftId == null
                        ? null
                        : () => _confirmAttendance(
                              action: 'check_in',
                              id: shiftId,
                              skipLocation: true,
                            ),
                    icon: const Icon(Icons.location_off_rounded),
                    label: const Text(
                      'Check-in tanpa Lokasi (Uji Coba)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange.shade800,
                      side: BorderSide(
                        color: Colors.deepOrange.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    const primaryBrown = Color(0xFF8C5E3C);

    final open = _isOpenAttendance(record);
    final employeeName =
        record['actual_employee_name'] ??
        record['scheduled_employee_name'] ??
        'Karyawan';

    final statusText = _statusLabel(record['status']);
    final notes = record['notes']?.toString() ?? '';
    final noLocation = notes.contains('[ABSEN TANPA LOKASI - UJI COBA]');

    Color statusBgColor = Colors.grey.withValues(alpha: 0.1);
    Color statusTextColor = Colors.grey.shade700;

    if (statusText == 'Hadir') {
      statusBgColor = Colors.green.withValues(alpha: 0.1);
      statusTextColor = Colors.green.shade700;
    } else if (statusText == 'Terlambat') {
      statusBgColor = Colors.orange.withValues(alpha: 0.1);
      statusTextColor = Colors.orange.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9F5F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: primaryBrown,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isManager
                            ? employeeName.toString()
                            : '${record['branch'] ?? 'Cabang'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(record['shift_date'])} • ${_formatTime(record['start_time'])}–${_formatTime(record['end_time'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Check-in: ${_formatTime(record['check_in'])}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Check-out: ${_formatTime(record['check_out'])}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (noLocation) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    color: Colors.deepOrange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Check-in tanpa lokasi (uji coba)',
                    style: TextStyle(
                      color: Colors.deepOrange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (open && !_isManager) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _confirmAttendance(
                            action: 'check_out',
                            id: int.parse(record['id'].toString()),
                            skipLocation: false,
                          ),
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('Check-out dengan Lokasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _confirmAttendance(
                            action: 'check_out',
                            id: int.parse(record['id'].toString()),
                            skipLocation: true,
                          ),
                  icon: const Icon(Icons.location_off_rounded),
                  label: const Text(
                    'Check-out tanpa Lokasi (Uji Coba)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange.shade800,
                    side: BorderSide(
                      color: Colors.deepOrange.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
