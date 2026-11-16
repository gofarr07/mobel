
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

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

  String? _error;

  int _unreadCount = 0;
  int _page = 1;
  int _totalPages = 1;

  // Menyimpan ID notifikasi yang sedang diproses.
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();

    _service = NotificationService(
      token: widget.user.token,
    );

    _loadNotifications();
  }

  // =========================================================
  // MEMUAT NOTIFIKASI
  // =========================================================

  Future<void> _loadNotifications({
    int page = 1,
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
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

        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              return _loadNotifications(page: _page);
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

        if (_totalPages > 1)
          _buildPagination(),
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

        // Klik seluruh kartu menandai sudah dibaca.
        onTap: notification.isRead || isProcessing
            ? null
            : () => _markRead(notification),

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
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _formatDate(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),

                    if (!notification.isRead)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Ketuk untuk menandai sudah dibaca',
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
      onRefresh: () => _loadNotifications(page: _page),
      color: const Color(0xFF6F4E37),

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),

          Icon(
            Icons.notifications_none,
            size: 75,
            color: Color(0xFF6F4E37),
          ),

          SizedBox(height: 18),

          Center(
            child: Text(
              'Belum ada notifikasi.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),

          SizedBox(height: 8),

          Center(
            child: Text(
              'Notifikasi baru akan muncul di sini.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
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
