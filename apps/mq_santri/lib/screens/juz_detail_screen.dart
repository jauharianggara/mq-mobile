import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'khatmil_reader_screen.dart';
import 'khatmil_manual_progress_screen.dart';

/// Detail Juz — HALAMAN PENUH (pengganti bottom sheet):
/// info pemilik & posisi bacaan + aksi (ambil juz / lanjut baca / lapor manual).
class JuzDetailScreen extends StatefulWidget {
  final int campaignId;
  final Map<dynamic, dynamic> juz; // dari juz_map
  final List<dynamic> groups; // kelompok campaign
  final Map<dynamic, dynamic>? myAssignment; // assignment milik saya di juz ini (bila ada)

  const JuzDetailScreen({
    super.key,
    required this.campaignId,
    required this.juz,
    this.groups = const [],
    this.myAssignment,
  });

  @override
  State<JuzDetailScreen> createState() => _JuzDetailScreenState();
}

class _JuzDetailScreenState extends State<JuzDetailScreen> {
  int? _pickedGroup;
  bool _claiming = false;

  List<Map<String, dynamic>> get _openGroups => widget.groups
      .map((g) => {
            'id': g['id'] as int,
            'no': g['group_no'] as int,
            'cnt': g['member_count'] as int,
            'pembina': (g['pembina'] as String?) ?? 'Ustadz',
          })
      .where((g) => (g['cnt'] as int) < 30)
      .toList();

  bool get _isEmpty => widget.juz['status'] == null;
  bool get _isMine =>
      widget.myAssignment != null && widget.myAssignment!['status'] != 'COMPLETED';

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      await api.post('/khatmil/campaigns/${widget.campaignId}/juz/claim',
          data: {'juz': widget.juz['juz'], 'group_id': _pickedGroup});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Juz ${widget.juz['juz']} sekarang milik Anda'),
          backgroundColor: AppColors.success));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _claiming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e, 'Gagal mengambil juz'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.juz;
    final status = j['status'];
    final pct = (j['progress_pct'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(title: Text('Juz ${j['juz']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Juz ${j['juz']}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      if (status != null) StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (status == null)
                    Text('Juz ini kosong.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant))
                  else ...[
                    Text('Pemilik: ${j['owner_name'] ?? '—'}',
                        style: const TextStyle(fontSize: 13)),
                    if (pct != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            'Posisi bacaan: QS ${j['current_surah']}:${j['current_ayah']} · $pct%',
                            style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---------- AKSI ----------
          if (_isEmpty) ...[
            if (widget.groups.length > 1) ...[
              Text('Pilih kelompok',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _pickedGroup,
                decoration: const InputDecoration(
                    labelText: 'Kelompok', border: OutlineInputBorder()),
                items: _openGroups
                    .map((g) => DropdownMenuItem(
                        value: g['id'] as int,
                        child: Text(
                            'Kelompok ${g['no']} · ${g['pembina']} · ${g['cnt']}/30',
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _pickedGroup = v),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed:
                  (_claiming || (widget.groups.length > 1 && _pickedGroup == null))
                      ? null
                      : _claim,
              icon: _claiming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle_outline),
              label: Text(_claiming ? 'Mengambil…' : 'Ambil Juz Ini'),
            ),
          ] else if (_isMine && widget.myAssignment != null) ...[
            FilledButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => KhatmilReaderScreen(
                            assignment: widget.myAssignment!)));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lanjut Baca'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => KhatmilManualProgressScreen(
                            assignment: widget.myAssignment!)));
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Lapor Manual'),
            ),
          ],
        ],
      ),
    );
  }
}
