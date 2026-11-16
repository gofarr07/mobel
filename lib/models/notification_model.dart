
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? relatedId;
  final String? actionUrl;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.relatedId,
    this.actionUrl,
    this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? 'Notifikasi',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      relatedId: json['related_id']?.toString(),
      actionUrl: json['action_url']?.toString(),
      isRead: json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['is_read']?.toString() == '1',
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      ),
      readAt: DateTime.tryParse(
        json['read_at']?.toString() ?? '',
      ),
    );
  }
}
