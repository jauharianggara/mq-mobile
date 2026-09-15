import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import '../services/deeplink.dart';

/// Inbox notifikasi — HALAMAN PENUH (minimal, plan F6).
/// Tap notifikasi → tandai dibaca + eksekusi deeplink (mis. langsung ke Reader khatmil).
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dynamic d = await api.get('/me/notifications');
      final List list = (d is List) ? d : (((d as Map?)?['data'] as List?) ?? <dynamic>[]);
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'Gagal memuat notifikasi'; _loading = false; });
    }
  }

  Future<void> _markRead(dynamic n, {bool navigate = true}) async {
    try {
      await api.post('/me/notifications/${n['id']}/read');
    } catch (_) {/* best-effort */}
    setState(() {
      final i = _items?.indexWhere((x) => x['id'] == n['id']);
      if (i != null && i >= 0) _items![i] = {...n, 'read_at': 'x'};
    });
    if (navigate) {
      final data = n['data'];
      final deeplink = data is Map ? data['deeplink'] as String? : null;
      if (deeplink != null && mounted) await handleDeeplink(context, deeplink);
    }
  }

  Future<void> _readAll() async {
    try {
      await api.post('/me/notifications/read-all');
      _load();
    } catch (_) {}
  }

  IconData _iconFor(String? code) {
    if (code == null) return Icons.notifications_outlined;
    if (code.startsWith('KHOTMIL') || code.startsWith('KHATMIL')) return Icons.auto_stories;
    if (code.startsWith('MEMORIZATION')) return Icons.mic;
    if (code.startsWith('QUESTION')) return Icons.question_answer;
    return Icons.notifications_outlined;
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse('${iso}Z');
    if (d == null) return '';
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return 'baru saja';
    if (s < 3600) return '${s ~/ 60} mnt lalu';
    if (s < 86400) return '${s ~/ 3600} jam lalu';
    return '${s ~/ 86400} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    final unread = (_items ?? []).where((n) => n['read_at'] == null).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _readAll,
              child: const Text('Tandai dibaca', style: TextStyle(color: AppColors.onPrimary)),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_items ?? []).isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Icon(Icons.notifications_none, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Center(child: Text('Belum ada notifikasi', style: TextStyle(color: Colors.grey[500]))),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final n = _items![i];
                            final isUnread = n['read_at'] == null;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _markRead(n),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUnread ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                                  border: Border.all(color: isUnread ? AppColors.primary.withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: (isUnread ? AppColors.primary : Colors.grey).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(_iconFor(n['template_code']), size: 20, color: isUnread ? AppColors.primary : Colors.grey),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${n['title']}',
                                                  style: TextStyle(fontSize: 13.5, fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600),
                                                ),
                                              ),
                                              if (isUnread)
                                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text('${n['body']}', style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.grey[700])),
                                          const SizedBox(height: 4),
                                          Text(_timeAgo(n['created_at']), style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
