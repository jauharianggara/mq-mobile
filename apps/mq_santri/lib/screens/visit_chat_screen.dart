import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart';

/// Chat transaksi — aktif saat CONFIRMED (riwayat tetap terbaca setelahnya).
/// Polling 5 detik (WebSocket = backlog). Pola bubble: TanyaThread.
class VisitChatScreen extends StatefulWidget {
  final int visitId;

  const VisitChatScreen({super.key, required this.visitId});

  @override
  State<VisitChatScreen> createState() => _VisitChatScreenState();
}

class _VisitChatScreenState extends State<VisitChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<dynamic> _items = [];
  int _myId = -1;
  bool _loading = true;
  bool _sending = false;
  bool _chatOpen = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final me = await api.me();
      _myId = me?['id'] as int? ?? -1;
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    try {
      final d = await api.visitDetail(widget.visitId);
      _chatOpen = d?['status'] == 'CONFIRMED';
      final items = await api.visitMessages(widget.visitId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      _schedulePoll();
      _autoScroll();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (_chatOpen) {
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await api.visitSendMessage(widget.visitId, text);
      _ctrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        String msg = 'Gagal mengirim';
        final es = e.toString();
        if (es.contains('403')) msg = 'Chat hanya aktif saat kunjungan dikonfirmasi';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Kunjungan')),
      body: Column(
        children: [
          if (!_loading && !_chatOpen)
            Container(
              width: double.infinity,
              color: Colors.amber.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(10),
              child: const Text(
                'Chat hanya bisa dikirim saat kunjungan dikonfirmasi. Riwayat tetap bisa dibaca.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('Belum ada pesan', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final m = _items[i] as Map<String, dynamic>;
                          final mine = m['sender_id'] == _myId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFC9A227).withValues(alpha: 0.2)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(mine ? 14 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(m['body'] ?? '', style: const TextStyle(fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtTime(m['created_at'] as String?) +
                                        (mine && m['read_at'] != null ? ' ✓' : ''),
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: _chatOpen,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _chatOpen ? 'Tulis pesan…' : 'Chat tertutup',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _chatOpen ? null : Colors.grey,
                    child: IconButton(
                      onPressed: _chatOpen ? _send : null,
                      icon: _sending
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
