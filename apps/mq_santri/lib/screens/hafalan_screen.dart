import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'hafalan_submit_screen.dart';
import 'hafalan_detail_screen.dart';

class HafalanScreen extends StatefulWidget {
  const HafalanScreen({super.key});

  @override
  State<HafalanScreen> createState() => _HafalanScreenState();
}

class _HafalanScreenState extends State<HafalanScreen> {
  List<dynamic>? _submissions;
  List<dynamic>? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        api.getPage('/me/submissions', query: {'limit': 50}),
        api.get('/me/memorization/progress').catchError((_) => null),
      ]);
      setState(() {
        _submissions = (results[0] as dynamic).items;
        _progress = results[1] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hafalan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.onPrimary),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HafalanSubmitScreen()));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Progress rollup
                      if (_progress?.isNotEmpty == true) ...[
                        _progressCard(),
                        const SizedBox(height: 16),
                      ],
                      // Riwayat setoran
                      Text(
                        'Riwayat Setoran',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (_submissions?.isEmpty == true)
                        EmptyState(
                          icon: Icons.mic_none,
                          message: 'Belum ada setoran hafalan.\nRekam suara dan kirim untuk direview ustadz.',
                          actionLabel: 'Kirim Setoran',
                          onAction: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const HafalanSubmitScreen()));
                            _load();
                          },
                        )
                      else
                        ...(_submissions ?? []).map<Widget>((s) => _submissionTile(s)),
                    ],
                  ),
                ),
    );
  }

  Widget _progressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('Progress Hafalan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_progress ?? []).map<Widget>((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(p['surah_name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('${p['last_passed_ayah']} ayat', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
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
          await Navigator.push(context, MaterialPageRoute(builder: (_) => HafalanDetailScreen(submissionId: s['id'])));
          _load();
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _statusColor(s['status']).withValues(alpha: 0.15),
            child: Icon(_statusIcon(s['status']), color: _statusColor(s['status']), size: 20),
          ),
          title: Text(
            '${s['surah_name']} : ${s['ayah_start']}-${s['ayah_end']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel(s['status']), style: TextStyle(fontSize: 11, color: _statusColor(s['status']), fontWeight: FontWeight.w500)),
              Text(
                _formatDate(s['submitted_at']),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PASSED': return AppColors.success;
      case 'REVISION': return AppColors.warning;
      case 'REJECTED': return AppColors.error;
      default: return AppColors.info;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PASSED': return Icons.check_circle;
      case 'REVISION': return Icons.edit;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.hourglass_top;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING': return 'Menunggu review';
      case 'IN_REVIEW': return 'Sedang direview';
      case 'PASSED': return 'Lulus';
      case 'REVISION': return 'Perlu revisi';
      case 'REJECTED': return 'Ditolak';
      default: return status;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    return iso.replaceAll('T', ' ').replaceAll('Z', '').substring(0, 16);
  }
}
