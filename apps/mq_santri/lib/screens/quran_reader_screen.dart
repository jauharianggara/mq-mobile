import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

class QuranReaderScreen extends StatefulWidget {
  final dynamic surahId;
  const QuranReaderScreen({super.key, required this.surahId});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  List<dynamic>? _ayahs;
  Map<String, dynamic>? _surahInfo;
  bool _loading = true;
  String? _error;
  bool _showTranslation = true;

  // Audio
  AudioPlayer? _player;
  int? _playingAyahIndex;
  bool _isPlaying = false;
  double _speed = 1.0;

  // Bookmark
  Set<dynamic> _bookmarkedAyahIds = {};

  // Scroll
  final _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final page = await api.getPage('/quran/surahs/${widget.surahId}/ayahs', query: {'limit': 300});
      final surahs = await api.get('/quran/surahs');
      final surah = (surahs as List).firstWhere((s) => s['id'] == widget.surahId, orElse: () => null);
      final bookmarks = await api.get('/me/bookmarks').catchError((_) => null);
      setState(() {
        _ayahs = page.items;
        _surahInfo = surah is Map<String, dynamic> ? surah : null;
        _bookmarkedAyahIds = (bookmarks as List? ?? []).map((b) => b['ayah_id']).toSet();
        _loading = false;
      });
      // set last-read ke ayah pertama surah ini
      if (_ayahs?.isNotEmpty == true) {
        _setLastRead(_ayahs!.first['id']);
      }
    } catch (e) {
      setState(() { _error = 'Gagal memuat ayat'; _loading = false; });
    }
  }

  Future<void> _setLastRead(dynamic ayahId) async {
    try { await api.put('/me/reading/last-read', data: {'ayah_id': ayahId}); } catch (_) {}
  }

  Future<void> _toggleBookmark(Map<dynamic, dynamic> ayah) async {
    final ayahId = ayah['id'];
    try {
      if (_bookmarkedAyahIds.contains(ayahId)) {
        await api.delete('/me/bookmarks/$ayahId');
        setState(() => _bookmarkedAyahIds.remove(ayahId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bookmark ${ayah['ayah_number']} dihapus'), duration: const Duration(seconds: 1)),
          );
        }
      } else {
        await api.post('/me/bookmarks', data: {'ayah_id': ayahId});
        setState(() => _bookmarkedAyahIds.add(ayahId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bookmark ayat ${ayah['ayah_number']} disimpan'), duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _playAudio(int index) async {
    if (_ayahs == null || index < 0 || index >= _ayahs!.length) return;
    final ayah = _ayahs![index];
    _player?.dispose();
    _player = AudioPlayer();

    setState(() { _playingAyahIndex = index; _isPlaying = true; });

    try {
      // get audio URL
      final audioList = await api.get('/quran/audio', query: {'ayah_id': ayah['id']});
      final url = (audioList as List).firstOrNull?['audio_url'];
      if (url == null) return;

      await _player!.setUrl(url);
      await _player!.setSpeed(_speed);
      _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          // auto-next ayah
          _playAudio(index + 1);
        }
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
      await _player!.play();

      // scroll to playing ayah
      _scrollToAyah(index);
    } catch (e) {
      if (mounted) {
        setState(() { _isPlaying = false; _playingAyahIndex = null; });
      }
    }
  }

  void _scrollToAyah(int index) {
    final key = _ayahKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    }
  }

  void _stopAudio() {
    _player?.stop();
    setState(() { _isPlaying = false; _playingAyahIndex = null; });
  }

  @override
  Widget build(BuildContext context) {
    final surahName = _surahInfo?['name_latin'] ?? 'Surah';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(surahName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (_surahInfo != null)
              Text(
                '${_surahInfo!['name_arabic']} · ${_surahInfo!['ayah_count']} ayat',
                style: const TextStyle(fontSize: 11, color: AppColors.gold),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showTranslation ? Icons.translate : Icons.translate_outlined),
            tooltip: 'Terjemahan',
            onPressed: () => setState(() => _showTranslation = !_showTranslation),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _ayahs!.length,
                      itemBuilder: _ayahTile,
                    ),
                    // Audio controls bar
                    if (_playingAyahIndex != null) ...[
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: _audioBar(),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _ayahTile(BuildContext ctx, int index) {
    final ayah = _ayahs![index];
    final isPlaying = _playingAyahIndex == index;
    final isBookmarked = _bookmarkedAyahIds.contains(ayah['id']);
    final pageNum = ayah['page'];

    // page marker (tampilkan di ayah pertama halaman)
    final showPageMarker = index == 0 || (index > 0 && _ayahs![index - 1]['page'] != pageNum);

    return Column(
      key: _ayahKeys.putIfAbsent(index, () => GlobalKey()),
      children: [
        if (showPageMarker)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Hal. $pageNum',
                      style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
        // Bismillah (ayat pertama surah selain 1 & 9)
        if (index == 0 && widget.surahId != 1 && widget.surahId != 9)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, height: 1.8),
              textDirection: TextDirection.rtl,
            ),
          ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isPlaying ? AppColors.primary.withValues(alpha: 0.06) : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onLongPress: () => _showAyahActions(ayah),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Ayah number + bookmark + play
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPlaying ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${ayah['surah_id']}:${ayah['ayah_number']}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPlaying ? AppColors.onPrimary : AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isBookmarked)
                        const Icon(Icons.bookmark, size: 16, color: AppColors.gold),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => isPlaying ? _stopAudio() : _playAudio(index),
                        child: Icon(
                          isPlaying ? Icons.stop_circle : Icons.play_circle_outline,
                          size: 22,
                          color: isPlaying ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Arabic text
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      ayah['text_uthmani'],
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 2.0,
                        fontFamily: 'serif',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  // Translation
                  if (_showTranslation && ayah['translation'] != null) ...[
                    const Divider(height: 16),
                    Text(
                      ayah['translation'],
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _audioBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous, color: AppColors.onPrimary),
            onPressed: _playingAyahIndex != null && _playingAyahIndex! > 0
                ? () => _playAudio(_playingAyahIndex! - 1)
                : null,
          ),
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppColors.onPrimary,
              size: 36,
            ),
            onPressed: () {
              if (_isPlaying) {
                _player?.pause();
              } else {
                _player?.play();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: AppColors.onPrimary),
            onPressed: _playingAyahIndex != null && _playingAyahIndex! < (_ayahs?.length ?? 0) - 1
                ? () => _playAudio(_playingAyahIndex! + 1)
                : null,
          ),
          const Spacer(),
          // Speed
          InkWell(
            onTap: () {
              setState(() {
                _speed = _speed == 1.0 ? 0.75 : _speed == 0.75 ? 0.5 : 1.0;
                _player?.setSpeed(_speed);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_speed}x',
                style: const TextStyle(color: AppColors.onPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Ayat ${_playingAyahIndex != null ? _ayahs![_playingAyahIndex!]['ayah_number'] : '-'}',
            style: const TextStyle(color: AppColors.onPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showAyahActions(Map<dynamic, dynamic> ayah) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _bookmarkedAyahIds.contains(ayah['id']) ? Icons.bookmark : Icons.bookmark_border,
                color: AppColors.gold,
              ),
              title: Text(_bookmarkedAyahIds.contains(ayah['id']) ? 'Hapus Bookmark' : 'Bookmark Ayat Ini'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleBookmark(ayah);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: AppColors.primary),
              title: const Text('Putar Audio'),
              onTap: () {
                Navigator.pop(ctx);
                final idx = _ayahs!.indexWhere((a) => a['id'] == ayah['id']);
                if (idx >= 0) _playAudio(idx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book, color: AppColors.primary),
              title: const Text('Tandai Terakhir Dibaca'),
              onTap: () {
                Navigator.pop(ctx);
                _setLastRead(ayah['id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Terakhir dibaca disimpan'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
