import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// HALAMAN input manual posisi bacaan (mushaf fisik) — mobile plan F1b rev 3.4.
/// Rev 3.4: bukan AlertDialog popup — HALAMAN PENUH (form lega, tombol simpan di bawah).
class KhatmilManualProgressScreen extends StatefulWidget {
  final Map<dynamic, dynamic> assignment; // id, juz, campaign_name, current_surah, current_ayah
  const KhatmilManualProgressScreen({super.key, required this.assignment});

  @override
  State<KhatmilManualProgressScreen> createState() => _KhatmilManualProgressScreenState();
}

class _KhatmilManualProgressScreenState extends State<KhatmilManualProgressScreen> {
  static final Map<int, List<dynamic>?> _cache = {};

  List<dynamic>? _ayahs;
  bool _loading = true;
  String? _error;
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
    setState(() { _loading = true; _error = null; });
    try {
      List<dynamic>? ayahs = _cache[_juz];
      ayahs ??= (((await api.get('/quran/juzs/$_juz/ayahs')) as Map?)?['ayahs'] as List?) ?? [];
      _cache[_juz] = ayahs;
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
      setState(() { _error = 'Gagal memuat data juz'; _loading = false; });
    }
  }

  List<dynamic> get _surahs {
    final seen = <int>{};
    return (_ayahs ?? []).where((a) => seen.add(a['surah_id'] as int)).toList();
  }

  List<dynamic> get _ayahsOfSurah => (_ayahs ?? []).where((a) => a['surah_id'] == _surah).toList();

  int get _offset {
    final idx = (_ayahs ?? []).indexWhere((a) => a['surah_id'] == _surah && a['ayah_number'] == _ayah);
    return idx < 0 ? 0 : idx + 1;
  }

  int get _total => _ayahs?.length ?? 0;

  Future<void> _save() async {
    if (_surah == null || _ayah == null) return;
    setState(() => _busy = true);
    try {
      final d = await api.post('/khatmil/assignments/$_assignmentId/progress', data: {
        'current_surah': _surah,
        'current_ayah': _ayah,
      });
      if (!mounted) return;
      final completed = d?['status'] == 'COMPLETED';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completed ? '🎉 Juz $_juz selesai — terverifikasi sistem' : 'Progres tersimpan'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('429') ? 'Terlalu cepat — tunggu sebentar' : 'Gagal menyimpan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _total > 0 ? _offset / _total * 100 : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('✍️ Laporan Manual')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Untuk yang membaca Al-Qur\'an fisik — cukup isi sampai mana bacaan terakhir di Juz $_juz. Posisi tersinkron dengan mode baca in-app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Text('Surah (dalam Juz $_juz)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _surah,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Pilih surah'),
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
                    const SizedBox(height: 14),
                    Text('Ayat terakhir yang dibaca', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _ayah,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Pilih ayat'),
                      items: _ayahsOfSurah
                          .map((a) => DropdownMenuItem(value: a['ayah_number'] as int, child: Text('Ayat ${a['ayah_number']}')))
                          .toList(),
                      onChanged: (v) => setState(() => _ayah = v),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('$_offset/$_total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(value: pct / 100, minHeight: 8, color: AppColors.primary, backgroundColor: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('${pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ],
                          ),
                          if (_offset >= _total && _total > 0)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('✓ Posisi akhir juz — juz akan terselesaikan', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy || _surah == null || _ayah == null ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Progres', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}
