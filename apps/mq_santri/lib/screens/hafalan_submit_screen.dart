import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';

class HafalanSubmitScreen extends StatefulWidget {
  const HafalanSubmitScreen({super.key});

  @override
  State<HafalanSubmitScreen> createState() => _HafalanSubmitScreenState();
}

class _HafalanSubmitScreenState extends State<HafalanSubmitScreen> {
  List<dynamic>? _surahs;
  Map<dynamic, dynamic>? _selectedSurah;
  int _ayahStart = 1;
  int _ayahEnd = 1;
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  bool _recording = false;
  Duration _recordDuration = Duration.zero;
  String? _recordPath;
  AudioRecorder? _recorder;

  // Max durasi 5 menit
  static const maxDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  @override
  void dispose() {
    _recorder?.stop();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      final list = await api.get('/quran/surahs');
      setState(() => _surahs = list as List?);
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      // Stop
      final path = await _recorder?.stop();
      setState(() { _recording = false; _recordPath = path; });
    } else {
      // Start
      _recorder ??= AudioRecorder();
      final hasPerm = await _recorder!.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan untuk merekam')),
          );
        }
        return;
      }
      final path = await _recorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: '${Directory.systemTemp.path}/setoran_${const Uuid().v4()}.m4a',
      );
      setState(() { _recording = true; _recordPath = null; _recordDuration = Duration.zero; });

      // Timer
      _tickTimer();
    }
  }

  void _tickTimer() async {
    while (_recording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_recording || !mounted) break;
      setState(() => _recordDuration += const Duration(seconds: 1));
      if (_recordDuration >= maxDuration) {
        await _toggleRecording();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maksimal 5 menit — rekaman dihentikan')),
          );
        }
        break;
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedSurah == null) {
      _showError('Pilih surah terlebih dahulu');
      return;
    }
    if (_recordPath == null) {
      _showError('Rekam audio setoran terlebih dahulu');
      return;
    }
    if (_ayahEnd < _ayahStart) {
      _showError('Ayat akhir harus >= ayat awal');
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Get file size & duration
      final file = File(_recordPath!);
      final fileSize = await file.length();

      // 2. Presign upload
      final uploadData = await api.post('/media/uploads', data: {
        'kind': 'AUDIO',
        'mime_type': 'audio/mp4',
        'byte_size': fileSize,
        'duration_ms': _recordDuration.inMilliseconds,
      });
      if (uploadData == null) throw Exception('Presign gagal');

      final mediaId = uploadData['media_id'];
      final uploadUrl = uploadData['upload_url'];

      // 3. PUT file to presigned URL
      final bytes = await file.readAsBytes();
      final dio = api.dio;
      await dio.put(
        uploadUrl,
        data: Stream.fromIterable(bytes.map((b) => [b])),
        options: Options(
          headers: {'Content-Type': 'audio/mp4', 'Content-Length': fileSize},
        ),
      );

      // 4. Complete upload
      await api.post('/media/uploads/$mediaId/complete');

      // 5. Submit setoran with idempotency key
      final idemKey = const Uuid().v4();
      final result = await api.post('/memorization/submissions',
        data: {
          'surah_id': _selectedSurah!['id'],
          'ayah_start': _ayahStart,
          'ayah_end': _ayahEnd,
          'audio_media_id': mediaId,
          'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        },
        idempotencyKey: idemKey,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setoran berhasil dikirim! Menunggu review ustadz.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      _showError('Gagal mengirim: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxAyat = _selectedSurah?['ayah_count'] ?? 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Setoran Hafalan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Surah picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pilih Surah', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Map<dynamic, dynamic>>(
                      value: _selectedSurah,
                      decoration: const InputDecoration(hintText: 'Pilih surah...', isDense: true),
                      items: (_surahs ?? []).map((s) {
                        return DropdownMenuItem<Map<dynamic, dynamic>>(
                          value: s,
                          child: Text('${s['id']}. ${s['name_latin']} (${s['ayah_count']} ayat)', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (s) => setState(() {
                        _selectedSurah = s;
                        _ayahStart = 1;
                        _ayahEnd = 1;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Ayah range
            if (_selectedSurah != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Rentang Ayat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Surah ${_selectedSurah!['name_latin']} — $maxAyat ayat', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Dari', style: TextStyle(fontSize: 11)),
                                Text('$_ayahStart', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: RangeSlider(
                              values: RangeValues(_ayahStart.toDouble(), _ayahEnd.toDouble()),
                              min: 1,
                              max: maxAyat.toDouble(),
                              divisions: maxAyat,
                              activeColor: AppColors.primary,
                              onChanged: (v) => setState(() {
                                _ayahStart = v.start.round();
                                _ayahEnd = v.end.round();
                              }),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Sampai', style: TextStyle(fontSize: 11)),
                                Text('$_ayahEnd', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Recorder
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Rekam Setoran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Maksimal 5 menit · Format AAC',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    // Wave animation placeholder
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _recording ? AppColors.error : AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: (_recording ? AppColors.error : AppColors.primary).withValues(alpha: 0.3),
                              blurRadius: _recording ? 20 : 8,
                              spreadRadius: _recording ? 4 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _recording ? Icons.stop : Icons.mic,
                          color: AppColors.onPrimary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _recording
                          ? 'Merekam... ${_fmtDuration(_recordDuration)}'
                          : _recordPath != null
                              ? 'Rekaman siap (${_fmtDuration(_recordDuration)}) — tap untuk re-rekam'
                              : 'Tap untuk mulai merekam',
                      style: TextStyle(
                        fontSize: 13,
                        color: _recording ? AppColors.error : _recordPath != null ? AppColors.success : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_recording) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _recordDuration.inSeconds / maxDuration.inSeconds,
                        backgroundColor: Colors.grey[300],
                        color: AppColors.error,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: sudah hafal 3 hari...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Submit
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                  : const Icon(Icons.send),
              label: Text(_loading ? 'Mengirim...' : 'Kirim Setoran'),
            ),
          ],
        ),
      ),
    );
  }
}
