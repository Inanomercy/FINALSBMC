import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  SupabaseClient get _client => SupabaseService.client;

  List<AppNotification> _notifications = [];
  bool _loading = false;
  RealtimeChannel? _subscription;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _loading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications(String userId) async {
    _loading = true;
    notifyListeners();

    try {
      final res = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _notifications = (res as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _notifications = [];
    } finally {
      _loading = false;
      notifyListeners();
    }

    _subscribeToNotifications(userId);
  }

  void _subscribeToNotifications(String userId) {
    if (!SupabaseService.isInitialized) return;
    _subscription?.unsubscribe();

    try {
      _subscription = _client
          .channel('public:notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newNotif = AppNotification.fromJson(payload.newRecord);
              _notifications.insert(0, newNotif);
              notifyListeners();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('id', notificationId);
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _notifications[idx].isRead = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('user_id', userId);
      for (final n in _notifications) {
        n.isRead = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
