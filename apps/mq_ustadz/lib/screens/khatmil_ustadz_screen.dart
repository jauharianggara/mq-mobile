import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'khatmil_binaan_detail_screen.dart';

/// Tab Khatmil ustadz — MEMANTAU progres (bukan ikut khatam):
/// penugasan pembina menunggu ACC + khatmil yang dibina + khatmil aktif umum.
class KhatmilUstadzScreen extends StatefulWidget {
  const KhatmilUstadzScreen({super.key});

  @override
  State<KhatmilUstadzScreen> createState() => _KhatmilUstadzScreenState();
}

class _KhatmilUstadzScreenState extends State<KhatmilUstadzScreen> {
  List<dynamic> _pending = [];
  List<dynamic> _dibina = [];
  List<dynamic> _aktif = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await api.ustadzKhatmil();
      if (!mounted) return;
      setState(() {
        _pending = (d?['pending'] ?? []) as List<dynamic>;
        _dibina = (d?['dibina'] ?? []) as List<dynamic>;
        _aktif = (d?['aktif'] ?? []) as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _acc(Map<String, dynamic> g) async {
    try {
      await api.ustadzKhatmilGroupAccept(g['group_id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penugasan diterima — Anda kini Pembina kelompok ini')));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal menerima penugasan')));
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> g) async {
    try {
      await api.ustadzKhatmilGroupReject(g['group_id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penugasan ditolak — admin akan menugaskan ustadz lain')));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal menolak penugasan')));
      }
    }
  }

  String _fmt(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khatmil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_pending.isNotEmpty) ...[
                    Text('Penugasan Menunggu ACC ($_pending)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    ..._pending.map<Widget>((g) => _pendingCard(g as Map<String, dynamic>)),
                    const SizedBox(height: 16),
                  ],
                  Text('Khatmil yang Dibina',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_dibina.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Belum menjadi Pembina kelompok.\nAdmin pondok yang menugaskan pembina.',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                        ),
                      ),
                    )
                  else
                    ..._dibina.map<Widget>((g) => _dibinaCard(g as Map<String, dynamic>)),
                  const SizedBox(height: 16),
                  Text('Khatmil Aktif Lainnya',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_aktif.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Tidak ada khatmil aktif.',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                      ),
                    )
                  else
                    ..._aktif.map<Widget>((c) => _aktifCard(c as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${g['campaign_name'] ?? 'Khatmil'} — Kelompok ${g['group_no']}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                'Admin menugaskan Anda menjadi Pembina kelompok ini.\n'
                'Tugas: memantau progres 30 santri sampai khatam.',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _acc(g),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Terima'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(g),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Tolak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dibinaCard(Map<String, dynamic> g) {
    final filled = (g['filled'] as num?)?.toInt() ?? 0;
    final completed = (g['completed'] as num?)?.toInt() ?? 0;
    final khatam = g['khatam'] == true || completed >= 30;
    final periode = [_fmt(g['period_start'] as String?), _fmt(g['period_end'] as String?)]
        .where((s) => s.isNotEmpty && s != '-')
        .join(' – ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => KhatmilBinaanDetailScreen(
                      campaignId: (g['campaign_id'] as num).toInt(),
                      campaignName: g['campaign_name'] ?? 'Khatmil',
                      groupNo: (g['group_no'] as num?)?.toInt() ?? 1,
                      periodStart: g['period_start'] as String?,
                      periodEnd: g['period_end'] as String?,
                    ))),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${g['campaign_name'] ?? 'Khatmil'} — Kelompok ${g['group_no']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                StatusBadge(status: khatam || completed >= 30 ? 'KHATAM' : 'AKTIF'),
              ],
            ),
            const SizedBox(height: 8),
            if (periode.isNotEmpty)
              Text(periode, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Text('$filled dari 30 juz terisi · $completed juz selesai',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: completed / 30,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text('Ketuk untuk lihat progres 30 juz santri',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
      ),
    );
  }

  Widget _aktifCard(Map<String, dynamic> c) {
    final periode = [_fmt(c['period_start'] as String?), _fmt(c['period_end'] as String?)]
        .where((s) => s.isNotEmpty && s != '-')
        .join(' – ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(c['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            periode.isNotEmpty ? periode : 'Periode belum diatur pengurus',
            style: const TextStyle(fontSize: 12)),
        trailing: StatusBadge(status: c['status'] ?? ''),
      ),
    );
  }
}
