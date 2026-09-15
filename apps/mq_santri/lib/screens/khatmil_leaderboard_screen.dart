import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Leaderboard campaign — HALAMAN PENUH (plan F4, mockup mobile3).
/// Strip total progres → podium top-3 → kartu list semua peserta
/// + highlight baris sendiri ("ANDA") + motivator peringkat.
class KhatmilLeaderboardScreen extends StatefulWidget {
  final dynamic campaignId;
  const KhatmilLeaderboardScreen({super.key, required this.campaignId});

  @override
  State<KhatmilLeaderboardScreen> createState() => _KhatmilLeaderboardScreenState();
}

class _KhatmilLeaderboardScreenState extends State<KhatmilLeaderboardScreen> {
  Map<String, dynamic>? _campaign;
  List<dynamic>? _participants;
  int? _myUserId;
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
      final me = await api.me().catchError((_) => null);
      final results = await Future.wait([
        api.get('/khatmil/campaigns/${widget.campaignId}'),
        api.get('/khatmil/campaigns/${widget.campaignId}/participants'),
      ]);
      if (!mounted) return;
      setState(() {
        _myUserId = me?['id'] as int?;
        _campaign = results[0] as Map<String, dynamic>;
        _participants = (results[1] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'Gagal memuat peringkat'; _loading = false; });
    }
  }

  /// Ranking: juz selesai DESC → nama ASC (rev 3.2/3.3 — tanpa menit).
  List<dynamic> get _ranked {
    final list = [...?_participants];
    list.sort((a, b) {
      final d = ((b['juz_done_count'] as num?) ?? 0).compareTo((a['juz_done_count'] as num?) ?? 0);
      return d != 0 ? d : '${a['full_name']}'.compareTo('${b['full_name']}');
    });
    return list;
  }

  String _initials(String name) =>
      name.split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();

  Color _avatarColor(String name) {
    const palette = [Color(0xFF1B7A4E), Color(0xFF0F766E), Color(0xFF0E7490), Color(0xFF16A34A), Color(0xFF57534E)];
    return palette[name.hashCode % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Peringkat'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
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
                      if (_campaign != null) _progressStrip(_campaign!),
                      const SizedBox(height: 12),
                      ..._podium(),
                      const SizedBox(height: 12),
                      _participantList(),
                      if (_myUserId != null) ...[
                        const SizedBox(height: 12),
                        _motivator(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  /* ---------------- Strip total progres ---------------- */

  Widget _progressStrip(Map<String, dynamic> c) {
    final juzMap = (c['juz_map'] ?? []) as List;
    final done = (c['juz_completed'] as num?)?.toInt() ?? 0;
    final target = 30 * ((c['target_khataman'] as num? ?? 1).toInt());
    final pct = (c['progress_pct'] as num? ?? 0).toDouble();
    final active = juzMap.where((j) => j['status'] != null && j['status'] != 'COMPLETED').length;
    final kosong = juzMap.where((j) => j['status'] == null).length;
    final penyumbang = (_participants ?? []).where((p) => ((p['juz_done_count'] as num?) ?? 0) > 0).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Progres Khataman', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                  '${pct % 1 == 0 ? pct.toInt() : pct}% · $done/$target juz',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: juzMap.map<Widget>((j) {
                final st = j['status'];
                return Expanded(
                  child: Container(
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: st == 'COMPLETED' ? AppColors.primary : (st != null ? AppColors.gold.withValues(alpha: 0.75) : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              '$done selesai · $active dibaca · $kosong kosong · $penyumbang peserta menyumbang',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------- Podium ---------------- */

  List<Widget> _podium() {
    final ranked = _ranked.where((p) => ((p['juz_done_count'] as num?) ?? 0) > 0).toList();
    if (ranked.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 6),
                Text('Belum ada yang menyelesaikan juz', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 2),
                const Text('Jadilah yang pertama! 🚀', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ];
    }
    final order = [1, 0, 2]; // juara 1 di tengah
    const medals = ['🥈', '🥇', '🥉'];
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: order.map((idx) {
          if (idx >= ranked.length) return Expanded(child: Container());
          final p = ranked[idx];

          final isMe = p['user_id'] == _myUserId;
          final isFirst = idx == 0;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.only(top: isFirst ? 18 : 10, bottom: 12),
              decoration: BoxDecoration(
                color: isFirst ? AppColors.gold.withValues(alpha: 0.08) : Colors.white,
                border: Border.all(color: isFirst ? AppColors.gold : Colors.grey.withValues(alpha: 0.25), width: isFirst ? 2 : 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(medals[order.indexOf(idx)], style: TextStyle(fontSize: isFirst ? 22 : 18)),
                  const SizedBox(height: 4),
                  Container(
                    width: isFirst ? 48 : 40,
                    height: isFirst ? 48 : 40,
                    decoration: BoxDecoration(color: _avatarColor('${p['full_name']}'), shape: BoxShape.circle, border: isMe ? Border.all(color: AppColors.gold, width: 3) : null),
                    child: Center(child: Text(_initials('${p['full_name']}'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isFirst ? 14 : 12))),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${p['full_name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  Text('${p['juz_done_count']} juz', style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                  Text(
                    p['contribution_pct'] != null ? '${p['contribution_pct']}%' : '—',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  /* ---------------- Daftar peserta ---------------- */

  Widget _participantList() {
    final ranked = _ranked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Semua Peserta (${ranked.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (ranked.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('Belum ada peserta yang mengklaim juz', style: TextStyle(fontSize: 13, color: Colors.grey[600])))))
        else
          ...ranked.asMap().entries.map((e) => _participantCard(e.key + 1, e.value)),
      ],
    );
  }

  Widget _participantCard(int rank, dynamic p) {
    final isMe = p['user_id'] == _myUserId;
    final active = (p['juz_active'] as List?) ?? [];
    final doneCnt = ((p['juz_done_count'] as num?) ?? 0).toInt();
    final activeJuz = active.map((j) => 'juz ${j['juz']}').join(', ');
    final bacaanPct = active.isNotEmpty ? active.first['progress_pct'] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.gold.withValues(alpha: 0.07) : Colors.white,
        border: Border.all(color: isMe ? AppColors.gold : Colors.grey.withValues(alpha: 0.2), width: isMe ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[500])),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _avatarColor('${p['full_name']}'), shape: BoxShape.circle),
                child: Center(child: Text(_initials('${p['full_name']}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${p['full_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(999)),
                            child: const Text('ANDA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      activeJuz.isNotEmpty ? '$activeJuz dipegang' : (doneCnt > 0 ? 'semua juznya selesai' : 'belum klaim juz'),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: doneCnt > 0 ? AppColors.success.withValues(alpha: 0.12) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$doneCnt juz',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: doneCnt > 0 ? AppColors.success : Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _labeledBar('Kontribusi', (p['contribution_pct'] as num?)?.toDouble()),
          const SizedBox(height: 5),
          _labeledBar('Progres Bacaan', (bacaanPct as num?)?.toDouble()),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'lapor ${_timeAgo(p['last_reported_at'] as String?)}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledBar(String label, double? pct) {
    final v = ((pct ?? 0)).clamp(0.0, 100.0);
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey[600]))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: v / 100, minHeight: 6, color: AppColors.primary, backgroundColor: Colors.grey[200]),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text('${pct == null ? '—' : '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}%'}', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
        ),
      ],
    );
  }

  /* ---------------- Motivator ---------------- */

  Widget _motivator() {
    final ranked = _ranked;
    final myIdx = ranked.indexWhere((p) => p['user_id'] == _myUserId);
    if (myIdx < 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Belum ikut khatmil — klaim juz pertamamu! 🚀', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      );
    }
    final myDone = ((ranked[myIdx]['juz_done_count'] as num?) ?? 0).toInt();
    if (myIdx == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Anda PERINGKAT #1 dengan $myDone juz — pertahankan! 👑', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ),
      );
    }
    // cari pesaing terdekat di atas dgn done > myDone
    int? aboveDone;
    for (var i = myIdx - 1; i >= 0; i--) {
      final d = ((ranked[i]['juz_done_count'] as num?) ?? 0).toInt();
      if (d > myDone) { aboveDone = d; break; }
    }
    final selisih = aboveDone != null ? aboveDone - myDone + 1 : 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Anda peringkat #${myIdx + 1} — selesaikan $selisih juz lagi untuk naik ke #${myIdx}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return 'belum pernah';
    final d = DateTime.tryParse('${iso}Z');
    if (d == null) return '—';
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return 'baru saja';
    if (s < 3600) return '${s ~/ 60} mnt lalu';
    if (s < 86400) return '${s ~/ 3600} jam lalu';
    return '${s ~/ 86400} hari lalu';
  }
}
