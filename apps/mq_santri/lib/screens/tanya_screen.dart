import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import 'tanya_thread_screen.dart';

class TanyaScreen extends StatefulWidget {
  const TanyaScreen({super.key});

  @override
  State<TanyaScreen> createState() => _TanyaScreenState();
}

class _TanyaScreenState extends State<TanyaScreen> {
  List<dynamic>? _questions;
  List<dynamic>? _categories;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0; // 0 = saya, 1 = arsip

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        api.getPage('/me/questions', query: {'limit': 50}),
        api.get('/question-categories').catchError((_) => null),
      ]);
      setState(() {
        _questions = (results[0] as dynamic).items;
        _categories = results[1] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  Future<void> _createQuestion() async {
    if (_categories?.isEmpty == true) return;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    int? categoryId;
    bool anonymous = false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tanya Ustadz', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              // Category
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Kategori', isDense: true),
                items: (_categories ?? []).map((c) {
                  return DropdownMenuItem(value: c['id'] as int, child: Text(c['name']));
                }).toList(),
                onChanged: (v) => categoryId = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul pertanyaan (5-200 huruf)', isDense: true),
                maxLength: 200,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Detail pertanyaan (opsional)', isDense: true),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: anonymous,
                onChanged: (v) => setModalState(() => anonymous = v ?? false),
                title: const Text('Sembunyikan identitas saya (anonim)', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Ustadz & moderator tetap dapat melihat identitas untuk keamanan', style: TextStyle(fontSize: 10)),
                dense: true,
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, {
                    'category_id': categoryId,
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'is_anonymous': anonymous,
                  });
                },
                child: const Text('Kirim Pertanyaan'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    if (result['title'] == null || (result['title'] as String).length < 5) {
      _showSnack('Judul minimal 5 huruf');
      return;
    }
    if (result['category_id'] == null) {
      _showSnack('Pilih kategori');
      return;
    }

    try {
      final idemKey = const Uuid().v4();
      await api.post('/questions',
        data: {
          'category_id': result['category_id'],
          'title': result['title'],
          'body': result['body'],
          'is_anonymous': result['is_anonymous'],
        },
        idempotencyKey: idemKey,
      );
      _showSnack('Pertanyaan terkirim! Menunggu penugasan ustadz.', success: true);
      _load();
    } catch (e) {
      _showSnack('Gagal mengirim: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AppColors.success : AppColors.error),
    );
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
              Tab(text: 'Pertanyaan Saya'),
              Tab(text: 'Arsip Publik'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _createQuestion,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: AppColors.onPrimary),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _myQuestions(),
                  _archive(),
                ],
              ),
      ),
    );
  }

  Widget _myQuestions() {
    if (_questions?.isEmpty == true) {
      return EmptyState(
        icon: Icons.help_outline,
        message: 'Belum ada pertanyaan.\nTap + untuk bertanya kepada ustadz.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _questions?.length ?? 0,
        itemBuilder: (ctx, i) {
          final q = _questions![i];
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
                  child: const Icon(Icons.question_answer, color: AppColors.primary, size: 20),
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
          return EmptyState(icon: Icons.public, message: 'Belum ada jawaban yang dipublikasikan');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final q = items[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TanyaThreadScreen(questionId: q['id']))),
                child: ListTile(
                  leading: const Icon(Icons.public, color: AppColors.success, size: 20),
                  title: Text(q['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('${q['category_name']} · ${q['asker_name'] ?? 'Anonim'}', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
