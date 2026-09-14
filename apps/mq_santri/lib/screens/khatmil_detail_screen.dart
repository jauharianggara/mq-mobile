import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

class KhatmilDetailScreen extends StatefulWidget {
  final dynamic campaignId;
  const KhatmilDetailScreen({super.key, required this.campaignId});

  @override
  State<KhatmilDetailScreen> createState() => _KhatmilDetailScreenState();
}

class _KhatmilDetailScreenState extends State<KhatmilDetailScreen> {
  Map<String, dynamic>? _detail;
  List<dynamic>? _myAssignments;
  bool _loading = true;
  String? _error;
  bool _joined = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        api.get('/khatmil/campaigns/${widget.campaignId}'),
        api.get('/me/khatmil/assignments').catchError((_) => null),
      ]);
      final d = results[0] as Map<String, dynamic>;
      final mine = results[1] as List? ?? [];
      final myCampaignJuz = mine.where((a) => a['campaign_id'] == widget.campaignId).toList();
      setState(() {
        _detail = d;
        _myAssignments = myCampaignJuz;
        _joined = myCampaignJuz.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  Future<void> _join() async {
    try {
      await api.post('/khatmil/campaigns/${widget.campaignId}/join');
      _load();
    } catch (e) {
      _showSnack('Gagal join: ${_errMsg(e)}');
    }
  }

  Future<void> _claimJuz([int? juz]) async {
    try {
      final d = await api.post('/khatmil/campaigns/${widget.campaignId}/juz/claim',
        data: juz != null ? {'juz': juz} : {});
      final j = d?['juz'];
      _showSnack('Juz $j berhasil diklaim!', success: true);
      _load();
    } catch (e) {
      _showSnack(_errMsg(e));
    }
  }

  Future<void> _postProgress(Map<dynamic, dynamic> assignment) async {
    final pagesCtrl = TextEditingController(text: assignment['pages_read'].toString());
    final minutesCtrl = TextEditingController(text: assignment['minutes_read'].toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Progress Juz ${assignment['juz']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pagesCtrl,
              decoration: const InputDecoration(labelText: 'Halaman dibaca (1-22)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: minutesCtrl,
              decoration: const InputDecoration(labelText: 'Menit membaca'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final d = await api.post('/khatmil/assignments/${assignment['id']}/progress', data: {
        'pages_read': int.tryParse(pagesCtrl.text) ?? 0,
        'minutes_read': int.tryParse(minutesCtrl.text) ?? 0,
      });
      _showSnack('Juz ${d?['juz']}: ${d?['status']}', success: true);
      _load();
    } catch (e) {
      _showSnack(_errMsg(e));
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  String _errMsg(dynamic e) {
    if (e is Exception) {
      final s = e.toString();
      if (s.contains('409')) return 'Juz sudah diklaim peserta lain';
      if (s.contains('422')) return 'Data tidak valid';
      if (s.contains('429')) return 'Terlalu cepat — tunggu sebentar';
    }
    return 'Terjadi kesalahan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_detail?['name'] ?? 'Khatmil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Info card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_detail!['participants']} peserta'),
                                  Text('${_detail!['juz_completed']}/30 juz selesai'),
                                  Text('${_detail!['progress_pct']}%'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (_detail!['progress_pct'] as num).toDouble() / 100,
                                  backgroundColor: Colors.grey[200],
                                  color: AppColors.primary,
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Min. ${_detail!['min_minutes_per_juz']} menit per juz · ${_detail!['mode'] == 'PARALLEL' ? 'Paralel' : 'Bergiliran'}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Join / Claim buttons
                      if (!_joined)
                        ElevatedButton.icon(
                          onPressed: _join,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join Campaign'),
                        )
                      else ...[
                        // My juz cards
                        ...(_myAssignments ?? []).map<Widget>((a) {
                          final isCompleted = a['status'] == 'COMPLETED';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCompleted ? AppColors.success.withValues(alpha: 0.15) : AppColors.gold.withValues(alpha: 0.15),
                                child: Text('J${a['juz']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCompleted ? AppColors.success : AppColors.gold)),
                              ),
                              title: Text('Juz ${a['juz']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${a['pages_read']}/22 hal · ${a['minutes_read']} mnt · ${a['verification']}'),
                              trailing: isCompleted
                                  ? const Icon(Icons.check_circle, color: AppColors.success)
                                  : ElevatedButton(
                                      onPressed: () => _postProgress(a),
                                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                      child: const Text('Update', style: TextStyle(fontSize: 12)),
                                    ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        // Claim button
                        ElevatedButton.icon(
                          onPressed: () => _claimJuz(),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Klaim Juz Kosong'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Atau tap juz kosong di peta untuk klaim juz tertentu',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Juz map (30 grid)
                      Text('Peta Juz', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _juzMap(),
                    ],
                  ),
                ),
    );
  }

  Widget _juzMap() {
    final juzMap = (_detail!['juz_map'] ?? []) as List;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: juzMap.length,
          itemBuilder: (ctx, i) {
            final j = juzMap[i];
            final status = j['status'];
            final isCompleted = status == 'COMPLETED';
            final isActive = status == 'ASSIGNED' || status == 'IN_PROGRESS';
            final isEmpty = status == null;
            final isMine = (_myAssignments ?? []).any((a) => a['juz'] == j['juz']);

            return GestureDetector(
              onTap: isEmpty && _joined ? () => _claimJuz(j['juz']) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.2)
                      : isActive
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : isMine
                              ? AppColors.gold.withValues(alpha: 0.15)
                              : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: isMine ? Border.all(color: AppColors.gold, width: 2) : null,
                ),
                child: Center(
                  child: Text(
                    '${j['juz']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCompleted ? AppColors.success : isActive ? AppColors.warning : isMine ? AppColors.gold : Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
