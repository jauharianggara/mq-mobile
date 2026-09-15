import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'setoran_review_screen.dart';

class SetoranScreen extends StatefulWidget {
  const SetoranScreen({super.key});

  @override
  State<SetoranScreen> createState() => _SetoranScreenState();
}

class _SetoranScreenState extends State<SetoranScreen> {
  List<dynamic>? _items;
  bool _loading = true;
  String? _error;
  String _filter = ""; // kosong = semua

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final page = await api.getPage('/ustadz/memorization/queue', query: {
        'limit': 50,
        if (_filter.isNotEmpty) 'status': _filter,
      });
      setState(() { _items = page.items; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrean Setoran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(label: const Text('Semua'), selected: _filter.isEmpty, onSelected: (_) { setState(() => _filter = ''); _load(); }),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('Menunggu'), selected: _filter == 'PENDING', onSelected: (_) { setState(() => _filter = 'PENDING'); _load(); }),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('Saya Review'), selected: _filter == 'IN_REVIEW', onSelected: (_) { setState(() => _filter = 'IN_REVIEW'); _load(); }),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items?.isEmpty == true
                      ? EmptyState(icon: Icons.check_circle_outline, message: 'Antrean kosong — semua setoran sudah direview ✓')
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items?.length ?? 0,
                          itemBuilder: (ctx, i) => _submissionTile(_items![i]),
                        ),
                ),
    );
  }

  Widget _submissionTile(Map<dynamic, dynamic> s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => SetoranReviewScreen(submissionId: s['id'])));
          _load();
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: s['status'] == 'PENDING'
                ? AppColors.warning.withValues(alpha: 0.15)
                : AppColors.info.withValues(alpha: 0.15),
            child: Icon(
              s['status'] == 'PENDING' ? Icons.hourglass_top : Icons.edit,
              color: s['status'] == 'PENDING' ? AppColors.warning : AppColors.info,
              size: 20,
            ),
          ),
          title: Text(
            '${s['surah_name']} : ${s['ayah_start']}-${s['ayah_end']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['user_name'] ?? 'Santri #${s['user_id']}', style: const TextStyle(fontSize: 11)),
              Text(
                '${_formatDate(s['submitted_at'])} · ${s['duration_ms'] != null ? _fmtDur(s['duration_ms']) : '—'}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: StatusBadge(status: s['status']),
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    return iso.replaceAll('T', ' ').replaceAll('Z', '').substring(0, 16);
  }

  String _fmtDur(dynamic ms) {
    if (ms == null) return '—';
    final d = Duration(milliseconds: ms is int ? ms : 0);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
