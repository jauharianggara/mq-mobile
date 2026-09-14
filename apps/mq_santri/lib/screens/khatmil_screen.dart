import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'khatmil_detail_screen.dart';

class KhatmilScreen extends StatefulWidget {
  const KhatmilScreen({super.key});

  @override
  State<KhatmilScreen> createState() => _KhatmilScreenState();
}

class _KhatmilScreenState extends State<KhatmilScreen> {
  List<dynamic>? _campaigns;
  List<dynamic>? _myAssignments;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        api.get('/khatmil/campaigns'),
        api.get('/me/khatmil/assignments').catchError((_) => null),
      ]);
      setState(() {
        _campaigns = results[0] as List?;
        _myAssignments = results[1] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khatmil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // My assignments
                      if (_myAssignments?.isNotEmpty == true) ...[
                        Text('Juz Saya', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...(_myAssignments!).map<Widget>((a) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                              child: Text('J${a['juz']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                            ),
                            title: Text(a['campaign_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('${a['pages_read']}/22 hal · ${a['minutes_read']} mnt'),
                            trailing: StatusBadge(status: a['status']),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => KhatmilDetailScreen(campaignId: a['campaign_id'])));
                              _load();
                            },
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                      // Campaigns
                      Text('Campaign', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (_campaigns?.isEmpty == true)
                        EmptyState(icon: Icons.people_outline, message: 'Belum ada campaign khatmil.\nNantikan pengumuman dari pengurus.')
                      else
                        ...(_campaigns ?? []).map<Widget>((c) => _campaignCard(c)),
                    ],
                  ),
                ),
    );
  }

  Widget _campaignCard(Map<dynamic, dynamic> c) {
    final pct = (c['progress_pct'] as num? ?? 0).toDouble();
    final isActive = c['status'] == 'ACTIVE';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isActive ? () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => KhatmilDetailScreen(campaignId: c['id'])));
          _load();
        } : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c['name'],
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  StatusBadge(status: c['status']),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c['mode'] == 'PARALLEL' ? 'Paralel' : 'Bergiliran'} · ${c['participants']} peserta · min. ${c['min_minutes_per_juz']} mnt/juz',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.grey[200],
                        color: AppColors.primary,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${c['juz_completed']}/30 juz',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
