import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'tanya_thread_screen.dart';

class TanyaScreen extends StatefulWidget {
  const TanyaScreen({super.key});

  @override
  State<TanyaScreen> createState() => _TanyaScreenState();
}

class _TanyaScreenState extends State<TanyaScreen> {
  List<dynamic>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final page = await api.getPage('/ustadz/questions/inbox', query: {'limit': 50});
      setState(() { _items = page.items; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tanya Ustadz', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.onPrimary,
            unselectedLabelColor: AppColors.onPrimary.withValues(alpha: 0.6),
            tabs: const [
              Tab(text: 'Inbox'),
              Tab(text: 'Arsip'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _inbox(),
                  _archive(),
                ],
              ),
      ),
    );
  }

  Widget _inbox() {
    if (_items?.isEmpty == true) {
      return EmptyState(icon: Icons.inbox, message: 'Tidak ada pertanyaan.\nPertanyaan baru akan muncul di sini.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items?.length ?? 0,
        itemBuilder: (ctx, i) {
          final q = _items![i];
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => TanyaThreadScreen(questionId: q['id'])));
                _load();
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  child: q['is_anonymous'] == true
                      ? const Icon(Icons.visibility_off, color: AppColors.primary, size: 18)
                      : const Icon(Icons.person, color: AppColors.primary, size: 18),
                ),
                title: Text(q['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(q['category_name'], style: const TextStyle(fontSize: 11)),
                trailing: StatusBadge(status: q['status']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _archive() {
    return FutureBuilder<({List<dynamic> items, String? nextCursor, bool hasMore})>(
      future: api.getPage('/questions/archive', query: {'limit': 50}),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data?.items ?? [];
        if (items.isEmpty) {
          return EmptyState(icon: Icons.public, message: 'Belum ada jawaban publik');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final q = items[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.public, color: AppColors.success, size: 18),
                title: Text(q['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${q['category_name']} · ${q['asker_name'] ?? 'Anonim'}', style: const TextStyle(fontSize: 10)),
              ),
            );
          },
        );
      },
    );
  }
}
