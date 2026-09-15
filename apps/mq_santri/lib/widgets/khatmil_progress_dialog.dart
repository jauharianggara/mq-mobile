import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Input manual posisi bacaan (mushaf fisik) — mobile plan F1b.
/// Dropdown Surah+Ayat dibatasi rentang juz; indikator live "x/y · z%".
Future<void> showKhatmilManualProgress(
  BuildContext context, {
  required Map<dynamic, dynamic> assignment,
  required void Function() onSaved,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ManualProgressDialog(assignment: assignment, onSaved: onSaved),
  );
}

class _ManualProgressDialog extends StatefulWidget {
  final Map<dynamic, dynamic> assignment;
  final void Function() onSaved;
  const _ManualProgressDialog({required this.assignment, required this.onSaved});

  @override
  State<_ManualProgressDialog> createState() => _ManualProgressDialogState();
}

class _ManualProgressDialogState extends State<_ManualProgressDialog> {
  static final Map<int, List<dynamic>?> _cache = {};

  List<dynamic>? _ayahs;
  bool _loading = true;
  int? _surah;
  int? _ayah;
  bool _busy = false;

  int get _juz => widget.assignment['juz'] as int;
  int get _assignmentId => widget.assignment['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      List<dynamic>? ayahs = _cache[_juz];
      ayahs ??= (((await api.get('/quran/juzs/$_juz/ayahs')) as Map?)?['ayahs'] as List?) ?? [];
      _cache[_juz] = ayahs;
      // pre-select posisi tersimpan
      final cs = widget.assignment['current_surah'];
      final ca = widget.assignment['current_ayah'];
      int? s, a;
      if (cs != null && ca != null) {
        s = cs as int;
        a = ca as int;
      } else if (ayahs.isNotEmpty) {
        s = ayahs.first['surah_id'] as int;
        a = ayahs.first['ayah_number'] as int;
      }
      setState(() { _ayahs = ayahs; _surah = s; _ayah = a; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _surahs {
    final seen = <int>{};
    return (_ayahs ?? []).where((a) => seen.add(a['surah_id'] as int)).toList();
  }

  List<dynamic> get _ayahsOfSurah =>
      (_ayahs ?? []).where((a) => a['surah_id'] == _surah).toList();

  int get _offset {
    final idx = (_ayahs ?? []).indexWhere((a) => a['surah_id'] == _surah && a['ayah_number'] == _ayah);
    return idx < 0 ? 0 : idx + 1;
  }

  int get _total => _ayahs?.length ?? 0;

  @override
  Widget build(BuildContext context) {
    final pct = _total > 0 ? _offset / _total * 100 : 0.0;
    return AlertDialog(
      title: const Text('✍️ Laporan Manual'),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Untuk yang membaca Al-Qur\'an fisik — isi sampai mana bacaan terakhir.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Text('Surah (dalam Juz $_juz)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _surah,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: _surahs
                      .map((s) => DropdownMenuItem(
                            value: s['surah_id'] as int,
                            child: Text('${s['surah_name_latin']} (${s['surah_id']})', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final first = _ayahs!.firstWhere((a) => a['surah_id'] == v);
                    setState(() { _surah = v; _ayah = first['ayah_number'] as int; });
                  },
                ),
                const SizedBox(height: 10),
                Text('Ayat terakhir yang dibaca', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _ayah,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: _ayahsOfSurah
                      .map((a) => DropdownMenuItem(value: a['ayah_number'] as int, child: Text('${a['ayah_number']}')))
                      .toList(),
                  onChanged: (v) => setState(() => _ayah = v),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text('$_offset/$_total', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: pct / 100, minHeight: 6, color: AppColors.primary, backgroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _busy || _surah == null || _ayah == null
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final d = await api.post('/khatmil/assignments/$_assignmentId/progress', data: {
                      'current_surah': _surah,
                      'current_ayah': _ayah,
                    });
                    if (context.mounted) Navigator.pop(context);
                    widget.onSaved();
                    if (d?['status'] == 'COMPLETED') {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🎉 Juz $_juz selesai — terverifikasi sistem'), backgroundColor: AppColors.success),
                        );
                      }
                    }
                  } catch (e) {
                    setState(() => _busy = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().contains('429') ? 'Terlalu cepat — tunggu sebentar' : 'Gagal menyimpan'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
          child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan Progres'),
        ),
      ],
    );
  }
}
