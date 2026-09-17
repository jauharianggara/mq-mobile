import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Detail progres kelompok binaan (read-only) — ustadz memantau, bukan ikut khatam.
/// Data: GET /ustadz/khatmil/{campaign_id} → kelompok[{group_no, terisi, selesai, juz[...]}]
class KhatmilBinaanDetailScreen extends StatefulWidget {
  final int campaignId;
  final String campaignName;
  final int groupNo;
  final String? periodStart; // YYYY-MM-DD (dari overview)
  final String? periodEnd;

  const KhatmilBinaanDetailScreen({
    super.key,
    required this.campaignId,
    required this.campaignName,
    required this.groupNo,
    this.periodStart,
    this.periodEnd,
  });

  @override
  State<KhatmilBinaanDetailScreen> createState() => _KhatmilBinaanDetailScreenState();
}

class _KhatmilBinaanDetailScreenState extends State<KhatmilBinaanDetailScreen> {
  Map<String, dynamic>? _data;
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
      final d = await api.get('/ustadz/khatmil/${widget.campaignId}');
      if (!mounted) return;
      setState(() { _data = d as Map<String, dynamic>?; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Gagal memuat progres kelompok'; _loading = false; });
    }
  }

  String _fmt(String? iso) {
    final d = iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final kelompok = (_data?['kelompok'] as List?)
            ?.cast<Map<String, dynamic>>()
            .firstWhere((k) => k['group_no'] == widget.groupNo, orElse: () => <String, dynamic>{})
        as Map<String, dynamic>?;
    final juzs = (kelompok?['juz'] as List? ?? []);
    final terisi = (kelompok?['terisi'] as num?)?.toInt() ?? 0;
    final selesai = (kelompok?['selesai'] as num?)?.toInt() ?? 0;
    final periode = [_fmt(widget.periodStart), _fmt(widget.periodEnd)]
        .where((s) => s.isNotEmpty)
        .join(' – ');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.campaignName} — Kelompok ${widget.groupNo}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.groups_outlined, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('$terisi dari 30 juz terisi · $selesai selesai',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  if (kelompok?['khatam'] == true)
                                    const StatusBadge(status: 'KHATAM')
                                  else
                                    const StatusBadge(status: 'AKTIF'),
                                ],
                              ),
                              if (periode.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(periode,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (selesai / 30).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Anda pembina kelompok ini — pantau progres santri di bawah.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Progres 30 Juz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...List.generate(30, (i) {
                        final j = juzs.where((x) => (x as Map)['juz'] == i + 1).cast<Map<String, dynamic>>().firstOrNull;
                        final done = j?['status'] == 'COMPLETED';
                        final kosong = j == null || (j['pemilik'] as String?) == '-';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          color: done ? AppColors.success.withValues(alpha: 0.07) : null,
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: done ? AppColors.success.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Juz ${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: done ? AppColors.success : AppColors.primary,
                                  )),
                            ),
                            title: kosong
                                ? Text('Belum diambil santri mana pun',
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor))
                                : Text(j!['pemilik'] as String? ?? '-',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: kosong || j!['posisi'] == null
                                ? null
                                : Text('${j['posisi']} · ${j['status'] == 'COMPLETED' ? 'Selesai' : 'Sedang Dibaca'}',
                                    style: const TextStyle(fontSize: 11)),
                            trailing: done
                                ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                                : null,
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}