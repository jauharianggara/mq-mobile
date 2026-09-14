import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'quran_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  List<dynamic>? _surahs;
  List<dynamic>? _bookmarks;
  Map<String, dynamic>? _lastRead;
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.get('/quran/surahs'),
        api.get('/me/bookmarks').catchError((_) => null),
        api.get('/me/reading/last-read').catchError((_) => null),
      ]);
      setState(() {
        _surahs = results[0] as List<dynamic>?;
        _bookmarks = results[1] as List<dynamic>?;
        _lastRead = results[2] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_surahs == null) return [];
    if (_search.isEmpty) return _surahs!;
    final q = _search.toLowerCase();
    return _surahs!.where((s) =>
        s['name_latin'].toString().toLowerCase().contains(q) ||
        s['name_id'].toString().toLowerCase().contains(q) ||
        s['id'].toString() == q).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Al-Quran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Last read banner
          if (_lastRead != null)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.bookmark, color: AppColors.gold),
                title: Text(
                  'Terakhir dibaca: ${_lastRead!['surah_name']} : ${_lastRead!['ayah_number']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Juz ${_lastRead!['juz']} · Hal. ${_lastRead!['page']}', style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.play_arrow, color: AppColors.primary),
                onTap: () => _openReader(_lastRead!['surah_id']),
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari surah...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Surah list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final s = _filtered[i];
                        final bookmarked = (_bookmarks ?? []).any((b) => b['surah_id'] == s['id']);
                        return _surahTile(s, bookmarked);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _surahTile(Map<dynamic, dynamic> s, bool bookmarked) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openReader(s['id']),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Number circle
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${s['id']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              // Names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s['name_latin'],
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        if (bookmarked)
                          const Icon(Icons.bookmark, size: 16, color: AppColors.gold),
                      ],
                    ),
                    Text(
                      '${s['name_id']} · ${s['ayah_count']} ayat · ${s['revelation'] == 'MAKKAH' ? 'Makkiyah' : 'Madaniyah'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Arabic name
              Text(
                s['name_arabic'],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openReader(dynamic surahId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuranReaderScreen(surahId: surahId)),
    );
  }
}
