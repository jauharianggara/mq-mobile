import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'khatmil_leaderboard_screen.dart';
import 'khatmil_manual_progress_screen.dart';
import 'khatmil_reader_screen.dart';

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

  /// ATURAN: santri pilih juz sendiri (tap peta) + pilih kelompok bila >1.
  Future<void> _claimJuz(int juz, int groupId) async {
    try {
      await api.post('/khatmil/campaigns/${widget.campaignId}/juz/claim',
        data: {'juz': juz, 'group_id': groupId});
      _showSnack('Juz $juz sekarang milik Anda di ${_groupName(groupId)}', success: true);
      _load();
    } catch (e) {
      _showSnack(apiErrorMessage(e, 'Gagal mengambil juz'));
    }
  }

  List<dynamic> get _groups => (_detail?['groups'] as List?) ?? const [];

  String _groupName(int id) {
    for (final g in _groups) {
      if (g['id'] == id) return 'Kelompok ${g['group_no']}';
    }
    return 'Kelompok';
  }

  /// Dropdown pilih kelompok (muncul bila campaign punya >1 kelompok).
  int? _pickedGroup;

  Widget _groupPicker() {
    final open = _groups
        .map((g) => {
              'id': g['id'] as int,
              'no': g['group_no'] as int,
              'cnt': g['member_count'] as int,
              'pembina': (g['pembina'] as String?) ?? 'Ustadz',
            })
        .where((g) => (g['cnt'] as int) < 30)
        .toList();
    if (_pickedGroup == null && open.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pickedGroup == null && open.isNotEmpty) {
          setState(() => _pickedGroup = open.first['id'] as int);
        }
      });
    }
    return DropdownButtonFormField<int>(
      initialValue: _pickedGroup,
      decoration: const InputDecoration(
          labelText: 'Pilih kelompok', border: OutlineInputBorder()),
      items: open
          .map((g) => DropdownMenuItem(
                value: g['id'] as int,
                child: Text(
                    'Kelompok ${g['no']} · ${g['pembina']} · ${g['cnt']}/30',
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) => setState(() => _pickedGroup = v),
    );
  }

  void _openReader(Map<dynamic, dynamic> a) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => KhatmilReaderScreen(assignment: a)))
        .then((_) => _load());
  }

  void _openManual(Map<dynamic, dynamic> a) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => KhatmilManualProgressScreen(assignment: a)))
        .then((_) => _load());
  }

  /// Bottom sheet info juz — nama PEMILIK + posisi + aksi (plan F3).
  void _showJuzSheet(dynamic j) {
    final status = j['status'];
    final isMine = (_myAssignments ?? []).any((a) => a['juz'] == j['juz'] && a['status'] != 'COMPLETED');
    final mine = (_myAssignments ?? []).cast<Map<dynamic, dynamic>?>().firstWhere((a) => a!['juz'] == j['juz'], orElse: () => null);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Juz ${j['juz']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (status == 'COMPLETED')
                    StatusBadge(status: 'COMPLETED')
                  else if (status != null)
                    StatusBadge(status: status)
                  else
                    Text('kosong', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 8),
              if (status == null) ...[
                Text('Juz ini kosong.', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                if (_myAssignments == null || _myAssignments!.isEmpty) ...[
                  if (_groups.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _groupPicker(),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: _pickedGroup == null
                          ? null
                          : () { Navigator.pop(ctx); _claimJuz(j['juz'] as int, _pickedGroup!); },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Ambil Juz Ini'),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  isMine ? 'Anda' : '${j['owner_name'] ?? '—'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                if (status != 'COMPLETED') ...[
                  if (j['current_surah'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Posisi bacaan: QS ${j['current_surah']}:${j['current_ayah']} · ${j['progress_pct'] ?? 0}%',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Belum ada laporan posisi bacaan', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ),
                ] else if (j['completed_at'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Selesai & terverifikasi: ${j['completed_at'].toString().substring(0, 10)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
                if (isMine && mine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () { Navigator.pop(ctx); _openReader(mine); },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Lanjut Baca'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () { Navigator.pop(ctx); _openManual(mine); },
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                          child: const Text('✍️'),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
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
      appBar: AppBar(
        title: Text(_detail?['name'] ?? 'Khatmil'),
        actions: [
          IconButton(
            icon: const Text('🏆', style: TextStyle(fontSize: 20)),
            tooltip: 'Peringkat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => KhatmilLeaderboardScreen(campaignId: widget.campaignId)),
            ),
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
                      _progressStrip(),
                      const SizedBox(height: 12),

                      if (!_joined)
                        ElevatedButton.icon(
                          onPressed: _join,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join Campaign'),
                        )
                      else ...[
                        ...(_myAssignments ?? []).cast<Map<dynamic, dynamic>>().map<Widget>(_myJuzCard),
                      ],
                      const SizedBox(height: 16),

                      Text('Peta Juz', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Tap juz utk lihat pemilik & posisi', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      _juzMap(),
                    ],
                  ),
                ),
    );
  }

  /// Tanggal Indonesia ringkas: "1 Sep 2026".
  String _fmt(String? iso) {
    final d = iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month - 1]} ${d.year}';
  }

  /// Strip progres campaign (plan F3) — bar + angka ringkas.
  Widget _progressStrip() {
    final d = _detail!;
    final total = 30 * ((d['target_khataman'] as num? ?? 1).toInt());
    final done = (d['juz_completed'] as num).toInt();
    final pct = (d['progress_pct'] as num).toDouble();
    final period = [
      _fmt(d['period_start'] as String?),
      _fmt(d['period_end'] as String?),
    ].where((s) => s.isNotEmpty).join(' – ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${d['participants']} peserta', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('$done/$total juz · ${pct % 1 == 0 ? pct.toInt() : pct}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: AppColors.primary,
                minHeight: 8,
              ),
            ),
            if (period.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(period, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ),
          ],
        ),
      ),
    );
  }

  /// Kartu "Juz Saya" — posisi QS + Lanjut Baca + input manual (plan F3).
  Widget _myJuzCard(Map<dynamic, dynamic> a) {
    final isCompleted = a['status'] == 'COMPLETED';
    final cs = a['current_surah'];
    final ca = a['current_ayah'];
    final read = a['read_ayat'];
    final total = (a['juz_total_ayat'] as num?)?.toInt() ?? 0;
    final sisa = (cs != null && read != null) ? total - (read as num).toInt() : null;
    final pct = a['progress_pct'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.success.withValues(alpha: 0.15) : AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Juz ${a['juz']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isCompleted ? AppColors.success : AppColors.goldDark)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Juz ${a['juz']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    isCompleted
                        ? 'Selesai — terverifikasi'
                        : cs != null
                            ? 'QS $cs:$ca · ${pct ?? 0}%' + (sisa != null && sisa > 0 ? ' · sisa $sisa ayat' : '')
                            : 'Belum ada laporan posisi',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isCompleted)
              const Icon(Icons.check_circle, color: AppColors.success)
            else ...[
              ElevatedButton.icon(
                onPressed: () => _openReader(a),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Baca', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              ),
              IconButton(
                onPressed: () => _openManual(a),
                icon: Icon(Icons.edit_note, color: Colors.grey[600]),
                tooltip: 'Input manual (mushaf fisik)',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Peta juz — juz_map v2: COMPLETED hijau (fix), aktif oranye, milik saya emas, kosong abu.
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
            final isMine = (_myAssignments ?? []).any((a) => a['juz'] == j['juz'] && a['status'] != 'COMPLETED');

            // Juz milik sendiri (sedang dibaca) = emas solid + border tebal —
            // paling menonjol dibanding juz aktif orang lain (oranye muda).
            return GestureDetector(
              onTap: () => _showJuzSheet(j),
              child: Container(
                decoration: BoxDecoration(
                  color: isMine
                      ? AppColors.gold
                      : isCompleted
                          ? AppColors.success.withValues(alpha: 0.2)
                          : isActive
                              ? AppColors.warning.withValues(alpha: 0.2)
                              : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: isMine ? Border.all(color: AppColors.gold, width: 2) : null,
                  boxShadow: isMine
                      ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${j['juz']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isMine ? FontWeight.w800 : FontWeight.w700,
                      color: isMine
                          ? Colors.white
                          : isCompleted
                              ? AppColors.success
                              : isActive
                                  ? AppColors.warning
                                  : Colors.grey,
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
