import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

class HafalanDetailScreen extends StatefulWidget {
  final dynamic submissionId;
  const HafalanDetailScreen({super.key, required this.submissionId});

  @override
  State<HafalanDetailScreen> createState() => _HafalanDetailScreenState();
}

class _HafalanDetailScreenState extends State<HafalanDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  AudioPlayer? _player;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _player?.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await api.get('/me/submissions/${widget.submissionId}');
      setState(() { _data = d; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _play(String url) async {
    _player?.dispose();
    _player = AudioPlayer();
    await _player!.setUrl(url);
    await _player!.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Setoran')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Tidak ditemukan'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                                StatusBadge(status: _data!['status']),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(_data!['submitted_at']),
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                    // Audio
                    if (_data!['audio_presigned_url'] != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.play_circle, color: AppColors.primary, size: 36),
                          title: const Text('Audio Setoran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('Durasi: ${_formatDuration(_data!['duration_ms'])}'),
                          onTap: () => _play(_data!['audio_presigned_url']),
                        ),
                      ),
                    // Review
                    if (_data!['review'] != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.rate_review, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text('Review Ustadz', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              StatusBadge(status: _data!['review']['verdict']),
                              if (_data!['review']['notes'] != null) ...[
                                const SizedBox(height: 8),
                                Text(_data!['review']['notes'], style: const TextStyle(fontSize: 13)),
                              ],
                              if (_data!['review']['reply_audio_presigned_url'] != null) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _play(_data!['review']['reply_audio_presigned_url']),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.volume_up, color: AppColors.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Putar balasan voice ustadz', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                ),
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

  String _formatDuration(dynamic ms) {
    if (ms == null) return '—';
    final d = Duration(milliseconds: ms is int ? ms : int.tryParse(ms.toString()) ?? 0);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
