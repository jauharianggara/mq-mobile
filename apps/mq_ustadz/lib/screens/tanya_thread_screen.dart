import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';

class TanyaThreadScreen extends StatefulWidget {
  final dynamic questionId;
  const TanyaThreadScreen({super.key, required this.questionId});

  @override
  State<TanyaThreadScreen> createState() => _TanyaThreadScreenState();
}

class _TanyaThreadScreenState extends State<TanyaThreadScreen> {
  Map<String, dynamic>? _thread;
  bool _loading = true;
  bool _busy = false;
  final _msgCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await api.get('/questions/${widget.questionId}');
      setState(() { _thread = d; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await api.post('/questions/${widget.questionId}/messages',
        data: {'type': 'TEXT', 'content': _msgCtrl.text.trim()},
        idempotencyKey: const Uuid().v4(),
      );
      _msgCtrl.clear();
      _load();
    } catch (_) {
      _snack('Gagal mengirim');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _answer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalisasi Jawaban'),
        content: const Text('Menandai pertanyaan ini sebagai TERJAWAB. Santri akan menerima notifikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Jawab')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await api.post('/questions/${widget.questionId}/answer');
      _snack('Pertanyaan ditandai terjawab', success: true);
      _load();
    } catch (_) { _snack('Gagal — mungkin sudah dijawab'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _publishRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Minta Publikasi'),
        content: const Text('Jawaban akan diperiksa moderator sebelum ditampilkan di arsip publik (dengan disclaimer).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajukan')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await api.post('/questions/${widget.questionId}/publish-request');
      _snack('Permintaan publikasi dikirim', success: true);
      _load();
    } catch (_) { _snack('Gagal — harus berstatus ANSWERED dulu'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  bool get _canReply {
    final s = _thread?['status'];
    return s == 'QUEUED' || s == 'ASSIGNED';
  }

  @override
  Widget build(BuildContext context) {
    final status = _thread?['status'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_thread?['title'] ?? 'Pertanyaan', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          if (status == 'ANSWERED')
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'publish') _publishRequest(); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'publish', child: Text('Ajukan Publikasi')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(_thread?['category_name'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      const SizedBox(width: 8),
                      if (_thread?['is_anonymous'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                          child: const Text('Anonim', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                        )
                      else
                        Text(_thread?['asker_name'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      const Spacer(),
                      StatusBadge(status: status ?? ''),
                    ],
                  ),
                ),
                // Messages
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: (_thread?['messages'] as List?)?.length ?? 0,
                    itemBuilder: (ctx, i) {
                      final m = (_thread!['messages'] as List)[i];
                      return _bubble(m);
                    },
                  ),
                ),
                // Actions
                if (_canReply) ...[
                  // Answer button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _answer,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Tandai Terjawab', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ),
                  ),
                ],
                // Input
                if (_canReply)
                  Container(
                    padding: EdgeInsets.only(
                      left: 12, right: 12, top: 4,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -1))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: InputDecoration(
                              hintText: 'Balas santri...',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            maxLines: 3,
                            minLines: 1,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _busy ? null : _send,
                          icon: _sending() ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  bool _sending() => _busy;

  Widget _bubble(Map<dynamic, dynamic> m) {
    final isUstadz = m['is_ustadz'] == true;
    return Align(
      alignment: isUstadz ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUstadz ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUstadz ? 14 : 4),
            bottomRight: Radius.circular(isUstadz ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUstadz ? 'Saya (Ustadz)' : (m['sender_name'] ?? 'Santri'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isUstadz ? AppColors.primary : Colors.grey),
            ),
            const SizedBox(height: 4),
            if (m['type'] == 'TEXT')
              Text(m['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5))
            else
              Row(
                children: [
                  Icon(m['type'] == 'VOICE' ? Icons.play_circle : Icons.image, size: 28, color: isUstadz ? AppColors.primary : Colors.grey),
                  const SizedBox(width: 6),
                  Text(m['type'] == 'VOICE' ? 'Pesan suara' : 'Gambar', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
