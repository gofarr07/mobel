
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/local_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  final AppUser user;

  const NotificationsPage({
    super.key,
    required this.user,
  });

  @override
  State<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationService _service;

  List<AppNotification> _notifications = [];

  bool _loading = true;
  bool _markingAll = false;
  bool _sendingTest = false;

  String? _error;

  int _unreadCount = 0;
  int _page = 1;
  int _totalPages = 1;

  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();

    _service = NotificationService(
      token: widget.user.token,
    );

    // Minta izin notifikasi Android (Android 13+) jika belum diizinkan
    LocalNotificationService.requestPermission();

    _loadNotifications();
  }

  // =========================================================
  // MEMUAT NOTIFIKASI
  // =========================================================

  Future<void> _loadNotifications({
    int page = 1,
    bool notifyPhone = false,
  }) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getNotifications(
        page: page,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        _notifications = result.notifications;
        _unreadCount = result.unreadCount;
        _page = result.page;
        _totalPages =
            result.totalPages < 1 ? 1 : result.totalPages;
        _loading = false;
      });

      // Jika tombol Cek Notifikasi ditekan, tampilkan juga di status bar HP
      if (notifyPhone) {
        final unreadItems =
            result.notifications.where((n) => !n.isRead).toList();

        if (unreadItems.isNotEmpty) {
          // Tampilkan notifikasi yang belum dibaca (maksimal 3 agar tidak spam)
          for (int i = 0; i < unreadItems.length && i < 3; i++) {
            final item = unreadItems[i];
            final id = int.tryParse(item.id) ??
                ((item.createdAt?.millisecondsSinceEpoch ?? 1000) % 100000 + i);

            await LocalNotificationService.showNotification(
              id: id,
              title: item.title,
              body: item.body,
            );
          }

          _showMessage(
            '${unreadItems.length} notifikasi belum dibaca ditampilkan di status bar HP.',
            backgroundColor: Colors.green,
          );
        } else {
          // Tetap berikan notifikasi di status bar HP bahwa cek selesai
          await LocalNotificationService.showNotification(
            id: 888888,
            title: 'Cek Notifikasi Kafe',
            body:
                'Tidak ada notifikasi baru. Semua notifikasi sudah dibaca.',
          );

          _showMessage(
            'Tidak ada notifikasi baru.',
            backgroundColor: const Color(0xFF6F4E37),
          );
        }
      }
    } on NotificationException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Terjadi kesalahan saat memuat notifikasi.';
        _loading = false;
      });
    }
  }

  // =========================================================
  // TES NOTIFIKASI
  // =========================================================

  Future<void> _sendTestNotification() async {
    if (_sendingTest || _loading) return;

    setState(() {
      _sendingTest = true;
    });

    try {
      // 1. Munculkan langsung notifikasi tes ke status bar HP
      await LocalNotificationService.showTestNotification();

      // 2. Simpan juga ke database server via API
      await _service.sendTestNotification();

      if (!mounted) return;

      _showMessage(
        'Notifikasi tes berhasil dimunculkan di HP & dibuat di server.',
        backgroundColor: Colors.green,
      );

      // Muat ulang daftar agar notifikasi tes langsung tampil di list
      await _loadNotifications(page: 1);
    } on NotificationException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message,
        backgroundColor: Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal mengirim notifikasi tes.',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingTest = false;
        });
      }
    }
  }

  // =========================================================
  // WIDGET TOMBOL TES NOTIFIKASI
  // =========================================================

  Widget _buildTestNotificationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sendingTest || _loading
            ? null
            : _sendTestNotification,
        icon: _sendingTest
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.notifications_active),
        label: Text(
          _sendingTest ? 'Mengirim...' : 'Tes Notif',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6F4E37),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.brown.shade200,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MENANDAI SATU NOTIFIKASI SUDAH DIBACA
  // =========================================================

  Future<void> _markRead(
    AppNotification notification,
  ) async {
    if (notification.isRead) return;

    if (_processingIds.contains(notification.id)) return;

    setState(() {
      _processingIds.add(notification.id);
    });

    try {
      await _service.markAsRead(notification.id);

      if (!mounted) return;

      setState(() {
        _notifications = _notifications.map((item) {
          if (item.id == notification.id) {
            return AppNotification(
              id: item.id,
              title: item.title,
              body: item.body,
              type: item.type,
              relatedId: item.relatedId,
              actionUrl: item.actionUrl,
              isRead: true,
              createdAt: item.createdAt,
              readAt: DateTime.now(),
            );
          }

          return item;
        }).toList();

        if (_unreadCount > 0) {
          _unreadCount--;
        }

        _processingIds.remove(notification.id);
      });
    } on NotificationException catch (e) {
      if (!mounted) return;

      setState(() {
        _processingIds.remove(notification.id);
      });

      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _processingIds.remove(notification.id);
      });

      _showMessage(
        'Gagal menandai notifikasi sebagai sudah dibaca.',
      );
    }
  }

  // =========================================================
  // MEMBUKA DETAIL NOTIFIKASI
  // =========================================================

  Future<void> _openNotification(
    AppNotification notification,
  ) async {
    if (_processingIds.contains(notification.id)) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                _getNotificationIcon(notification.type),
                color: const Color(0xFF6F4E37),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(),
                Text(
                  'Tipe: ${notification.type}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Waktu: ${_formatDate(notification.createdAt)}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notification.isRead
                      ? 'Status: Sudah dibaca'
                      : 'Status: Belum dibaca',
                  style: const TextStyle(
                    color: Color(0xFF6F4E37),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4E37),
                foregroundColor: Colors.white,
              ),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );

    // Setelah detail dibuka, tandai sebagai sudah dibaca.
    if (!notification.isRead && mounted) {
      await _markRead(notification);
    }
  }

  // =========================================================
  // MENANDAI SEMUA NOTIFIKASI SUDAH DIBACA
  // =========================================================

  Future<void> _markAllRead() async {
    if (_unreadCount == 0 || _markingAll) return;

    setState(() {
      _markingAll = true;
    });

    try {
      await _service.markAllAsRead();

      if (!mounted) return;

      setState(() {
        _notifications = _notifications.map((item) {
          return AppNotification(
            id: item.id,
            title: item.title,
            body: item.body,
            type: item.type,
            relatedId: item.relatedId,
            actionUrl: item.actionUrl,
            isRead: true,
            createdAt: item.createdAt,
            readAt: item.readAt ?? DateTime.now(),
          );
        }).toList();

        _unreadCount = 0;
        _markingAll = false;
        _processingIds.clear();
      });

      _showMessage(
        'Semua notifikasi berhasil ditandai sudah dibaca.',
        backgroundColor: Colors.green,
      );
    } on NotificationException catch (e) {
      if (!mounted) return;

      setState(() {
        _markingAll = false;
      });

      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _markingAll = false;
      });

      _showMessage(
        'Gagal menandai semua notifikasi.',
      );
    }
  }

  // =========================================================
  // PESAN SNACKBAR
  // =========================================================

  void _showMessage(
    String message, {
    Color? backgroundColor,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
        ),
      );
  }

  // =========================================================
  // FORMAT TANGGAL
  // =========================================================

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  // =========================================================
  // IKON BERDASARKAN TIPE NOTIFIKASI
  // =========================================================

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'transaction':
        return Icons.receipt_long;

      case 'payment':
        return Icons.payments_outlined;

      case 'order':
        return Icons.shopping_bag_outlined;

      case 'stock':
        return Icons.inventory_2_outlined;

      case 'system':
        return Icons.settings_outlined;

      case 'shift_reminder':
        return Icons.schedule;

      case 'test':
        return Icons.notifications_active;

      default:
        return Icons.notifications_active_outlined;
    }
  }

  // =========================================================
  // WARNA BERDASARKAN STATUS
  // =========================================================

  Color _getCardColor(AppNotification notification) {
    if (notification.isRead) {
      return Colors.white;
    }

    return const Color(0xFFFFEEDB);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : () => _loadNotifications(page: 1, notifyPhone: true),
            tooltip: 'Cek notifikasi terbaru',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _markingAll || _unreadCount == 0
                ? null
                : _markAllRead,
            tooltip: 'Tandai semua sudah dibaca',
            icon: _markingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.done_all),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  // =========================================================
  // BODY
  // =========================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6F4E37),
        ),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_notifications.isEmpty) {
      return _buildEmpty();
    }

    return Column(
      children: [
        _buildUnreadHeader(),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: _buildTestNotificationButton(),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _loadNotifications(page: 1, notifyPhone: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Cek Notifikasi Terbaru'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6F4E37),
                side: const BorderSide(
                  color: Color(0xFF6F4E37),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              return _loadNotifications(page: _page, notifyPhone: true);
            },
            color: const Color(0xFF6F4E37),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final notification = _notifications[index];

                return _buildNotificationCard(notification);
              },
            ),
          ),
        ),

        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  // =========================================================
  // HEADER JUMLAH BELUM DIBACA
  // =========================================================

  Widget _buildUnreadHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: Color(0xFF6F4E37),
          ),
          const SizedBox(width: 10),
          const Text(
            'Belum dibaca',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E342E),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF6F4E37),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CARD NOTIFIKASI
  // =========================================================

  Widget _buildNotificationCard(
    AppNotification notification,
  ) {
    final isProcessing =
        _processingIds.contains(notification.id);

    return Card(
      elevation: notification.isRead ? 1 : 2,
      margin: EdgeInsets.zero,
      color: _getCardColor(notification),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isProcessing
            ? null
            : () => _openNotification(notification),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFF6F4E37),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                        color: const Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Ketuk untuk melihat detail notifikasi',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6F4E37),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildReadButton(notification, isProcessing),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TOMBOL BACA SATU NOTIFIKASI
  // =========================================================

  Widget _buildReadButton(
    AppNotification notification,
    bool isProcessing,
  ) {
    if (isProcessing) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6F4E37),
          ),
        ),
      );
    }

    if (notification.isRead) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 23,
      );
    }

    return IconButton(
      tooltip: 'Tandai sudah dibaca',
      onPressed: () => _markRead(notification),
      icon: const Icon(
        Icons.mark_email_read_outlined,
        color: Color(0xFF6F4E37),
      ),
    );
  }

  // =========================================================
  // PAGINATION
  // =========================================================

  Widget _buildPagination() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Halaman sebelumnya',
            onPressed: _page > 1
                ? () => _loadNotifications(page: _page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Halaman $_page dari $_totalPages',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            tooltip: 'Halaman berikutnya',
            onPressed: _page < _totalPages
                ? () => _loadNotifications(page: _page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: () => _loadNotifications(page: 1, notifyPhone: true),
      color: const Color(0xFF6F4E37),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 90),
          const Icon(
            Icons.notifications_none,
            size: 75,
            color: Color(0xFF6F4E37),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Belum ada notifikasi.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Notifikasi baru akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tombol tes tetap tersedia meskipun daftar kosong.
          _buildTestNotificationButton(),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _loadNotifications(page: 1, notifyPhone: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Cek Notifikasi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6F4E37),
                side: const BorderSide(
                  color: Color(0xFF6F4E37),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.brown,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),

            // Tes notif juga tersedia saat gagal memuat daftar.
            _buildTestNotificationButton(),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {
                _loadNotifications(page: _page);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4E37),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}