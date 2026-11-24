
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _testNotificationId = 999999;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'shift_reminder_channel',
    'Pengingat Jadwal Shift',
    channelDescription: 'Pengingat jadwal kerja karyawan',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const AndroidNotificationDetails _generalNotificationDetails =
      AndroidNotificationDetails(
    'general_notification_channel',
    'Notifikasi Kafe',
    channelDescription: 'Pemberitahuan dan update notifikasi kafe',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    // Mengatur zona waktu sesuai perangkat.
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(
      tz.getLocation(timezoneInfo.identifier),
    );

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Meminta izin notifikasi Android 13+.
    await androidPlugin?.requestNotificationsPermission();

    // Meminta izin alarm tepat waktu.
    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;

    if (!canScheduleExact) {
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  // Menjadwalkan pengingat 3 jam sebelum shift.
  static Future<void> scheduleShiftReminders(
    List<Map<String, dynamic>> shifts,
  ) async {
    // Membatalkan jadwal pengingat sebelumnya.
    await _plugin.cancelAll();

    for (final shift in shifts) {
      final shiftId = int.tryParse(
        shift['id']?.toString() ?? '',
      );

      if (shiftId == null) continue;

      final shiftDate = shift['shift_date']?.toString() ?? '';
      final startTime = shift['start_time']?.toString() ?? '';

      final dateParts = shiftDate.split('-');
      final timeParts = startTime.split(':');

      if (dateParts.length != 3 || timeParts.length < 2) {
        continue;
      }

      final year = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final day = int.tryParse(dateParts[2]);
      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      if (year == null ||
          month == null ||
          day == null ||
          hour == null ||
          minute == null) {
        continue;
      }

      final shiftStart = DateTime(
        year,
        month,
        day,
        hour,
        minute,
      );

      final reminderTime = shiftStart.subtract(
        const Duration(hours: 3),
      );

      if (!reminderTime.isAfter(DateTime.now())) {
        continue;
      }

      final branch = shift['branch']?.toString() ?? '-';

      final scheduledDate = tz.TZDateTime.from(
        reminderTime,
        tz.local,
      );

      await _plugin.zonedSchedule(
        id: shiftId,
        title: 'Pengingat Jadwal Shift',
        body:
            'Shift Cabang $branch dimulai pukul '
            '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}. '
            'Persiapkan diri kamu!',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: _androidDetails,
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  // Meminta izin notifikasi secara eksplisit jika belum diberikan (Android 13+).
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission() ?? false;
  }

  // Menampilkan notifikasi langsung ke status bar HP.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _generalNotificationDetails,
      ),
      payload: payload,
    );
  }

  // Menampilkan notifikasi tes secara langsung.
  static Future<void> showTestNotification() async {
    await _plugin.show(
      id: _testNotificationId,
      title: 'Tes Notifikasi Kafe',
      body: 'Notifikasi berhasil muncul di status bar HP kamu!',
      notificationDetails: const NotificationDetails(
        android: _generalNotificationDetails,
      ),
    );
  }

  // Membatalkan seluruh notifikasi.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}