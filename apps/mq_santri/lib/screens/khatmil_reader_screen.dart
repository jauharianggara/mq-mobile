import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

/// Reader Juz utk Khatmil (mobile plan rev 3.2/3.3 — F1a).
/// - Scroll kontinu lintas surah (data GET /quran/juzs/{n}/ayahs)
/// - Auto-resume ke posisi terakhir + badge "TERAKHIR DIBACA"
/// - Ayat aktif terlacak dari scroll (marker hijau + AppBar % live)
/// - Auto-save maju (debounce 4 dtk + saat keluar) — anti lupa klik simpan
/// - Tombol "✓ Sampai sini" per ayat (konfirmasi manual, boleh mundur sengaja)
/// - Ayat terakhir juz → konfirmasi "Selesaikan Juz" → COMPLETED
class KhatmilReaderScreen extends StatefulWidget {
  final Map<dynamic, dynamic> assignment; // id, juz, campaign_name, current_surah, current_ayah, progress_pct...
  const KhatmilReaderScreen({super.key, required this.assignment});

  @override
  State<KhatmilReaderScreen> createState() => _KhatmilReaderScreenState();
}

class _KhatmilReaderScreenState extends State<KhatmilReaderScreen> {
  List<dynamic>? _ayahs;
  bool _loading = true;
  String? _error;
  bool _showTranslation = false;

  final _itemScrollCtrl = ItemScrollController();
  final _itemPositions = ItemPositionsListener.create();
  Timer? _saveDebounce;
  Timer? _scrollIdle;
  bool _saving = false;

  int _savedIndex = -1;   // posisi tersimpan (server)
  int _activeIndex = -1;  // ayat paling terlihat (scroll)

  int get _juz => widget.assignment['juz'] as int;
  int get _assignmentId => widget.assignment['id'] as int;
  int get _total => _ayahs?.length ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
    _itemPositions.itemPositions.addListener(_onPositions);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await api.get('/quran/juzs/$_juz/ayahs');
      final ayahs = ((d as Map?)?['ayahs'] as List?) ?? [];
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _ayahs = ayahs;
        _showTranslation = prefs.getBool('reader_show_translation') ?? false;
        _loading = false;

      });
      _afterLoad();
    } catch (e) {
      setState(() { _error = 'Gagal memuat ayat'; _loading = false; });
    }
  }

  void _afterLoad() {
    final cs = widget.assignment['current_surah'];
    final ca = widget.assignment['current_ayah'];
    if (cs != null && ca != null) {
      final idx = _ayahs!.indexWhere((a) => a['surah_id'] == cs && a['ayah_number'] == ca);
      if (idx >= 0) {
        _savedIndex = idx;
        _activeIndex = idx;
        // langsung lompat ke ayat terakhir dibaca (posisi atas viewport)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _itemScrollCtrl.jumpTo(index: idx);
        });
      }
    }
    final ayahs = _ayahs;
    if (_savedIndex < 0 && ayahs != null && ayahs.isNotEmpty) {
      _activeIndex = 0;
    }
  }



  /* ---------------- Scroll tracking ---------------- */

  void _onPositions() {
    // debounce deteksi ayat aktif
    _scrollIdle?.cancel();
    _scrollIdle = Timer(const Duration(milliseconds: 350), _detectActive);
    // auto-save debounce 4 dtk setelah aktivitas scroll berhenti
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 4), _autoSave);
  }

  void _detectActive() {
    if (!mounted) return;
    final positions = _itemPositions.itemPositions.value;
    if (positions.isEmpty) return;
    // ayat aktif = item paling bawah yang garis atasnya sudah melewati top viewport
    int best = 0;
    for (final p in positions) {
      final idx = p.index ?? 0;
      if (p.itemLeadingEdge <= 0.2 && idx > best) best = idx;
    }
    if (best != _activeIndex) setState(() => _activeIndex = best);
  }

  double get _pctLive {
    final idx = (_activeIndex >= 0 ? _activeIndex : _savedIndex);
    if (_total == 0 || idx < 0) return 0;
    return (idx + 1) / _total * 100;
  }

  /* ---------------- Simpan progres ---------------- */

  Future<void> _postPosition(int index, {bool silent = false, String? note}) async {
    if (_saving || index < 0 || _ayahs == null) return;
    final a = _ayahs![index];
    _saving = true;
    try {
      final d = await api.post('/khatmil/assignments/$_assignmentId/progress', data: {
        'current_surah': a['surah_id'],
        'current_ayah': a['ayah_number'],
        if (note != null) 'note': note,
      });
      final completed = d?['status'] == 'COMPLETED';
      if (!mounted) return;
      setState(() => _savedIndex = index);
      if (completed) {
        _onJuzCompleted(d);
      } else if (!silent) {
        _showSnack('Tersimpan · QS ${a['surah_id']}:${a['ayah_number']} · ${(index + 1)}/$_total (${_fmtPct((index + 1) / _total * 100)})', success: true);
      }
    } catch (e) {
      if (!silent) _showSnack(_errMsg(e));
    } finally {
      _saving = false;
    }
  }

  /// Auto-save hanya MAJU — tidak pernah mundur diam-diam (plan rev 3.3).
  Future<void> _autoSave() async {
    if (_activeIndex > _savedIndex && _activeIndex >= 0) {
      await _postPosition(_activeIndex, silent: true);
      if (mounted && _activeIndex >= 0) {
        final a = _ayahs![_activeIndex];
        _showSnack('⏱ Tersimpan otomatis · QS ${a['surah_id']}:${a['ayah_number']} · ${_fmtPct(_pctLive)}%', success: true);
      }
    }
  }

  Future<bool> _confirmComplete() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Selesaikan Juz $_juz? 🎉'),
        content: Text('Anda telah mencapai ayat terakhir Juz $_juz ($_total ayat) dalam campaign "${widget.assignment['campaign_name']}". Juz akan ditandai selesai & terverifikasi sistem.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Baca dulu lagi')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Selesaikan')),
        ],
      ),
    ) ?? false;
  }

  void _onJuzCompleted(dynamic d) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text('Juz $_juz Selesai', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Terverifikasi sistem (posisi mencapai ayat terakhir)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Alhamdulillah'))],
      ),
    );
  }

  Future<void> _markHere(int index) async {
    final isLast = index >= _total - 1;
    if (isLast && _savedIndex < _total - 1) {
      if (!await _confirmComplete()) return;
    }
    await _postPosition(index);
  }

  /* ---------------- UI ---------------- */

  String _fmtPct(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ));
  }

  String _errMsg(dynamic e) {
    final s = e.toString();
    if (s.contains('422')) return 'Posisi tidak valid';
    if (s.contains('429')) return 'Terlalu cepat — tunggu sebentar';
    if (s.contains('409')) return 'Juz sudah selesai';
    return 'Gagal menyimpan';
  }

  Future<void> _toggleTranslation() async {
    final v = !_showTranslation;
    setState(() => _showTranslation = v);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('reader_show_translation', v);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollIdle?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _autoSave(); // simpan posisi terakhir saat keluar
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Juz $_juz', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                '${widget.assignment['campaign_name']} · ${_activeIndex >= 0 ? _activeIndex + 1 : (_savedIndex >= 0 ? _savedIndex + 1 : 0)}/$_total',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                  child: Text('${_fmtPct(_pctLive)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ),
            IconButton(
              icon: Icon(_showTranslation ? Icons.translate : Icons.translate_outlined),
              tooltip: 'Terjemahan',
              onPressed: _toggleTranslation,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _pctLive / 100,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: AppColors.gold,
            ),
          ),
        ),
        bottomNavigationBar: _ayahs == null ? null : Container(
          padding: EdgeInsets.only(left: 14, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.25)))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _posisiText(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
                : ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollCtrl,
                    itemPositionsListener: _itemPositions,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _ayahs!.length,
                    itemBuilder: (ctx, i) => _ayahCard(i),
                  ),
      ),
    );
  }

  String _posisiText() {
    final idx = _activeIndex >= 0 ? _activeIndex : _savedIndex;
    if (idx < 0) return 'Belum ada posisi — mulai membaca';
    final a = _ayahs![idx];
    return 'QS ${a['surah_name_latin']} ${a['surah_id']}:${a['ayah_number']} · ${idx + 1}/$_total ayat · ${_fmtPct(_pctLive)}%';
  }

  Widget _ayahCard(int i) {
    final a = _ayahs![i];
    final prev = i > 0 ? _ayahs![i - 1] : null;
    final isNewSurah = prev == null || prev['surah_id'] != a['surah_id'];
    final isNewPage = prev == null || prev['page'] != a['page'];
    final isLast = i >= _total - 1;
    final isSaved = i == _savedIndex;
    final isActive = i == _activeIndex;
    final alreadyMarked = i <= _savedIndex && _savedIndex >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isNewSurah)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Column(
              children: [
                Text('${a['surah_name_arabic']}', style: const TextStyle(fontFamily: 'serif', fontSize: 21, color: AppColors.primaryDark, height: 1.6), textDirection: TextDirection.rtl),
                Text(
                  '${a['surah_name_latin']} (${a['surah_id']})${i == 0 ? ' · awal Juz $_juz' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        if (isNewPage && !isNewSurah)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            child: Row(
              children: [
                const Expanded(child: Divider(height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('HAL. ${a['page']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.gold)),
                ),
                const Expanded(child: Divider(height: 1)),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSaved ? AppColors.gold.withValues(alpha: 0.07) : (isActive ? AppColors.success.withValues(alpha: 0.04) : Colors.white),
            border: Border.all(
              color: isSaved ? AppColors.gold : (isActive ? AppColors.success.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2)),
              width: isSaved ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              if (isSaved)
                Positioned(
                  top: 0, right: 10,
                  child: Container(
                    margin: const EdgeInsets.only(top: 0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: const BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
                    child: const Text('✓ TERAKHIR DIBACA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                )
              else if (isActive && !isSaved)
                Positioned(
                  top: 0, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
                    child: Text('► SEDANG DIBACA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.success)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                          child: Text('${a['surah_id']}:${a['ayah_number']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                        const Spacer(),
                        Text('Hal. ${a['page']}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${a['text_uthmani']}',
                      style: const TextStyle(fontFamily: 'serif', fontSize: 23, height: 2.1, color: Color(0xFF143D2B)),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                    // Terjemahan — default tersembunyi, preferensi permanen (plan hide-translation)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.linear,
                      alignment: Alignment.topCenter,
                      child: _showTranslation && a['translation'] != null
                          ? Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2), style: BorderStyle.solid))),
                              child: Text('${a['translation']}', style: TextStyle(fontSize: 12.5, height: 1.6, color: Colors.grey[800])),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : () => _markHere(i),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: alreadyMarked ? Colors.grey[200] : (isLast ? AppColors.primary : AppColors.primary),
                              foregroundColor: alreadyMarked ? Colors.grey : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            icon: Icon(isLast ? Icons.emoji_events : Icons.check, size: 15),
                            label: Text(isLast ? 'Selesaikan Juz $_juz' : (alreadyMarked ? 'Sudah ditandai' : 'Sampai sini')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
