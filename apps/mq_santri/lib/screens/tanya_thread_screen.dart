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
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await api.get('/questions/${widget.questionId}');
      setState(() { _thread = d; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await api.post('/questions/${widget.questionId}/messages',
        data: {'type': 'TEXT', 'content': text},
        idempotencyKey: const Uuid().v4(),
      );
      _msgCtrl.clear();
      _load();
    } catch (e) {
      _showSnack('Gagal mengirim');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeQuestion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup Pertanyaan'),
        content: const Text('Pertanyaan akan ditandai selesai. Anda tidak bisa menulis lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tutup')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.post('/questions/${widget.questionId}/close');
      _showSnack('Pertanyaan ditutup', success: true);
      _load();
    } catch (_) {
      _showSnack('Gagal menutup');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  bool get _canReply {
    final status = _thread?['status'];
    return status == 'QUEUED' || status == 'ASSIGNED' || status == 'ANSWERED' || status == 'PUBLISH_REQUESTED';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _thread?['title'] ?? 'Pertanyaan',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_thread?['status'] != 'CLOSED' && _thread?['status'] != 'PUBLISHED')
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Tutup pertanyaan',
              onPressed: _closeQuestion,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(_thread?['category_name'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      const SizedBox(width: 12),
                      if (_thread?['is_anonymous'] == true)
                        const Icon(Icons.visibility_off, size: 14, color: Colors.grey)
                      else
                        Text(_thread?['asker_name'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      const Spacer(),
                      StatusBadge(status: _thread?['status'] ?? ''),
                    ],
                  ),
                ),
                // Messages
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: (_thread?['messages'] as List?)?.length ?? 0,
                    itemBuilder: (ctx, i) => _messageTile((_thread!['messages'] as List)[i]),
                  ),
                ),
                // Input
                if (_canReply)
                  Container(
                    padding: EdgeInsets.only(
                      left: 12, right: 12, top: 8,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: InputDecoration(
                              hintText: 'Tulis pesan...',
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
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _messageTile(Map<dynamic, dynamic> m) {
    final isUstadz = m['is_ustadz'] == true;
    final isVoice = m['type'] == 'VOICE';
    final isImage = m['type'] == 'IMAGE';

    return Align(
      alignment: isUstadz ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUstadz
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUstadz ? 4 : 14),
            bottomRight: Radius.circular(isUstadz ? 14 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUstadz ? 'Ustadz' : (m['sender_name'] ?? 'Saya'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isUstadz ? AppColors.primary : AppColors.gold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(m['created_at']),
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (isVoice || isImage)
              // Voice/image placeholder — audio player & image viewer menyusul
              Row(
                children: [
                  Icon(isVoice ? Icons.play_circle : Icons.image, size: 32, color: isUstadz ? AppColors.primary : AppColors.gold),
                  const SizedBox(width: 8),
                  Text(isVoice ? 'Pesan suara' : 'Gambar', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              )
            else
              Text(
                m['content'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    return iso.substring(11, 16);
  }
}
