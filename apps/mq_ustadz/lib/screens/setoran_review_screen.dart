import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

class SetoranReviewScreen extends StatefulWidget {
  final dynamic submissionId;
  const SetoranReviewScreen({super.key, required this.submissionId});

  @override
  State<SetoranReviewScreen> createState() => _SetoranReviewScreenState();
}

class _SetoranReviewScreenState extends State<SetoranReviewScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  AudioPlayer? _player;
  bool _isPlaying = false;
  double _speed = 1.0;
  final _notesCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _player?.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await api.get('/me/submissions/${widget.submissionId}');
      setState(() { _data = d; _loading = false; });
      if (d?['review']?['notes'] != null) {
        _notesCtrl.text = d!['review']['notes'];
      }
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _togglePlay() async {
    final url = _data?['audio_presigned_url'];
    if (url == null) return;
    if (_isPlaying) {
      await _player?.pause();
      setState(() => _isPlaying = false);
    } else {
      _player ??= AudioPlayer();
      if (_player!.audioSource == null) {
        await _player!.setUrl(url);
        _player!.playerStateStream.listen((s) {
          if (mounted) setState(() => _isPlaying = s.playing);
        });
      }
      await _player!.setSpeed(_speed);
      await _player!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _cycleSpeed() {
    setState(() {
      _speed = _speed == 1.0 ? 0.75 : _speed == 0.75 ? 0.5 : 1.0;
      _player?.setSpeed(_speed);
    });
  }

  Future<void> _action(String action, {String? verdict}) async {
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{'action': action};
      if (verdict != null) body['verdict'] = verdict;
      if (_notesCtrl.text.trim().isNotEmpty) body['notes'] = _notesCtrl.text.trim();

      final d = await api.post('/memorization/submissions/${widget.submissionId}/review', data: body);

      if (!mounted) return;
      if (action == 'CLAIM') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setoran diklaim — silakan beri penilaian'), backgroundColor: AppColors.info),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review tersimpan: $verdict'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context); // kembali ke queue
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _data?['status'];

    return Scaffold(
      appBar: AppBar(title: const Text('Review Setoran')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Tidak ditemukan'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_data!['surah_name']} : ${_data!['ayah_start']}-${_data!['ayah_end']}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                StatusBadge(status: status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Santri: ${_data!['user_name'] ?? '#${_data!['user_id']}'} · ${_formatDate(_data!['submitted_at'])}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (_data!['note'] != null) ...[
                              const Divider(),
                              Text(_data!['note'], style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Audio player
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _togglePlay,
                                  child: Container(
                                    width: 56, height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: AppColors.onPrimary,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Audio Setoran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      Text(
                                        _data!['duration_ms'] != null
                                            ? _fmtDur(_data!['duration_ms'])
                                            : 'Durasi tidak diketahui',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                // Speed
                                InkWell(
                                  onTap: _cycleSpeed,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_speed}x',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Actions
                    if (status == 'PENDING') ...[
                      ElevatedButton.icon(
                        onPressed: _busy ? null : () => _action('CLAIM'),
                        icon: const Icon(Icons.pan_tool),
                        label: const Text('Klaim untuk Review'),
                      ),
                    ],
                    if (status == 'IN_REVIEW') ...[
                      TextField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Catatan untuk santri (opsional)',
                          hintText: 'Contoh: masyaAllah lancar, perhatikan mad...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Text('Beri Penilaian', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _action('SUBMIT', verdict: 'PASSED'),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Lulus', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _action('SUBMIT', verdict: 'REVISION'),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Revisi', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _action('SUBMIT', verdict: 'REJECTED'),
                              icon: const Icon(Icons.cancel, size: 18),
                              label: const Text('Tolak', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Hasil review
                    if (['PASSED', 'REVISION', 'REJECTED'].contains(status) && _data!['review'] != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hasil Review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 8),
                              StatusBadge(status: _data!['review']['verdict']),
                              if (_data!['review']['notes'] != null) ...[
                                const SizedBox(height: 8),
                                Text(_data!['review']['notes'], style: const TextStyle(fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    return iso.replaceAll('T', ' ').replaceAll('Z', '').substring(0, 16);
  }

  String _fmtDur(dynamic ms) {
    if (ms == null) return '—';
    final d = Duration(milliseconds: ms is int ? ms : 0);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
