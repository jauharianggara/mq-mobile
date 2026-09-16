import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'visit_chat_screen.dart';

/// Detail kunjungan ustadz: incoming (acc/tolak + review santri dari ustadz lain)
/// & upcoming (chat + tandai selesai + nilai santri).
class VisitRequestScreen extends StatefulWidget {
  final int visitId;

  const VisitRequestScreen({super.key, required this.visitId});

  @override
  State<VisitRequestScreen> createState() => _VisitRequestScreenState();
}

class _VisitRequestScreenState extends State<VisitRequestScreen> {
  Map<String, dynamic>? _v;
  bool _loading = true;
  bool _busy = false;
  Timer? _poll;
  // form inline (bukan popup)
  bool _showDeclineForm = false;
  final _declineCtrl = TextEditingController();
  int _rating = 5;
  final _reviewCtrl = TextEditingController();
  bool _showReviewForm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await api.visitDetail(widget.visitId);
      if (!mounted) return;
      setState(() {
        _v = d;
        _loading = false;
      });
      final s = d?['status'];
      if (s == 'WAITING_CONFIRM') {
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load());
      } else {
        _poll?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await api.ustadzVisitConfirm(widget.visitId);
      _load();
    } catch (e) {
      _showErr(e, 'Gagal mengonfirmasi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_declineCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await api.ustadzVisitDecline(widget.visitId, _declineCtrl.text.trim());
      setState(() {
        _showDeclineForm = false;
        _declineCtrl.clear();
      });
      _load();
    } catch (e) {
      _showErr(e, 'Gagal menolak');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai selesai?'),
        content: const Text('Pastikan kunjungan sudah dilaksanakan. Santri akan diminta menilai Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Belum')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesai')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await api.ustadzVisitComplete(widget.visitId);
      _load();
    } catch (e) {
      _showErr(e, 'Gagal menandai selesai (mungkin di luar jadwal)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReview() async {
    setState(() => _busy = true);
    try {
      await api.ustadzVisitReview(widget.visitId, rating: _rating, comment: _reviewCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Terima kasih - penilaian tampil setelah santri juga menilai.')));
      }
      setState(() => _showReviewForm = false);
      _load();
    } catch (e) {
      _showErr(e, 'Gagal mengirim penilaian');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showErr(Object e, String fallback) {
    if (!mounted) return;
    final es = e.toString();
    String msg = fallback;
    if (es.contains('409') && es.contains('schedule')) msg = 'Bentrok jadwal dengan kunjungan lain';
    if (es.contains('409') && es.contains('limit')) msg = 'Kapasitas kunjungan aktif penuh';
    if (es.contains('409')) msg = 'Pesanan sudah diproses';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Scaffold(
      appBar: AppBar(title: const Text('Permintaan Kunjungan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : v == null
              ? Center(child: EmptyState(icon: Icons.error_outline, message: 'Pesanan tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _header(v),
                      const SizedBox(height: 12),
                      _infoCard(v),
                      if (v['status'] == 'WAITING_CONFIRM') ...[
                        const SizedBox(height: 12),
                        _requesterSection(v),
                      ],
                      const SizedBox(height: 20),
                      ..._actions(v),
                      if (_showDeclineForm && v['status'] == 'WAITING_CONFIRM') ...[
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Alasan penolakan (utk santri)',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _declineCtrl,
                                  decoration: const InputDecoration(
                                      hintText: 'cth: jadwal bentrok, maaf', isDense: true),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444)),
                                    onPressed: _busy ? null : _decline,
                                    icon: const Icon(Icons.close),
                                    label: const Text('Tolak & Kembalikan Dana'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_showReviewForm && v['status'] == 'COMPLETED') ...[
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          color: const Color(0xFFC9A227).withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Penilaian Anda utk santri',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Privat - hanya ustadz lain yang melihat saat santri ini memesan lagi.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (i) {
                                    return IconButton(
                                      onPressed: () => setState(() => _rating = i + 1),
                                      icon: Icon(
                                          i < _rating ? Icons.star : Icons.star_border,
                                          color: const Color(0xFFC9A227),
                                          size: 34),
                                    );
                                  }),
                                ),
                                TextField(
                                  controller: _reviewCtrl,
                                  decoration: const InputDecoration(
                                      hintText: 'Catatan (wajib santun)', isDense: true),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submitReview,
                                    child: Text(_busy ? 'Mengirim...' : 'Kirim Penilaian'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _header(Map<String, dynamic> v) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Kunjungan ${v['duration_hours'] ?? '-'} jam — Rp ${_rp(v['price_total'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                StatusBadge(status: v['status']),
              ],
            ),
            if (v['decline_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Ditolak: ${v['decline_reason']}',
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Map<String, dynamic> v) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(Icons.event, 'Jadwal', _fmt(v['scheduled_at'])),
            _row(Icons.timelapse, 'Durasi', '${v['duration_hours'] ?? '-'} jam'),
            _row(Icons.person_outline, 'Santri', v['requester']?['full_name'] ?? '-'),
            _row(Icons.place_outlined, 'Patokan', v['address_label'] ?? '-'),
            if (v['status'] == 'CONFIRMED' && v['lat'] != null)
              _row(Icons.location_on, 'Titik', '${(v['lat'] as num).toStringAsFixed(5)}, ${(v['lng'] as num).toStringAsFixed(5)}'),
            if (v['status'] == 'CONFIRMED' && v['requester']?['phone'] != null)
              _row(Icons.call_outlined, 'Kontak santri', v['requester']['phone']),
            if ((v['note'] as String?)?.isNotEmpty == true) _row(Icons.notes, 'Catatan', v['note']),
          ],
        ),
      ),
    );
  }

  Widget _requesterSection(Map<String, dynamic> v) {
    final r = v['requester'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF16A34A).withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_search, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Profil santri pemesan',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Text(
                  r['rating_avg'] == null
                      ? 'Santri baru'
                      : '★ ${(r['rating_avg'] as num).toStringAsFixed(1)} (${r['rating_count']})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8a6d1a)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (r['rating_avg'] == null)
              const Text('Santri baru — belum pernah dinilai ustadz lain.',
                  style: TextStyle(fontSize: 12))
            else
              const Text(
                  'Rating dihitung dari penilaian ustadz lain setelah kunjungan selesai (privat).',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// Waktu kunjungan berakhir (UTC) = scheduled_at + duration_hours.
  /// Aturan 16Sep: ustadz hanya bisa menandai selesai SETELAH waktu ini.
  DateTime? _visitEndAt(Map<String, dynamic> v) {
    final s = v['scheduled_at'] as String?;
    if (s == null) return null;
    final dur = (v['duration_hours'] as num?)?.toInt() ?? 0;
    return DateTime.tryParse(s)?.add(Duration(hours: dur));
  }

  List<Widget> _actions(Map<String, dynamic> v) {
    switch (v['status'] as String) {
      case 'WAITING_CONFIRM':
        return [
          FilledButton.icon(
            onPressed: _busy ? null : _confirm,
            icon: const Icon(Icons.check),
            label: const Text('Terima (ACC)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => setState(() => _showDeclineForm = !_showDeclineForm),
            icon: const Icon(Icons.close),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            label: const Text('Tolak — dana santri kembali penuh'),
          ),
        ];
      case 'CONFIRMED':
        final end = _visitEndAt(v);
        final canComplete = end == null || DateTime.now().toUtc().isAfter(end);
        return [
          FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VisitChatScreen(visitId: widget.visitId))),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat dengan Santri'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: (_busy || !canComplete) ? null : _complete,
            icon: const Icon(Icons.task_alt),
            label: const Text('Tandai Kunjungan Selesai'),
          ),
          if (!canComplete)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                end != null
                    ? 'Belum selesai waktunya — bisa ditandai selesai setelah ${end.toLocal().hour.toString().padLeft(2, '0')}.${end.toLocal().minute.toString().padLeft(2, '0')} WIB.'
                    : 'Belum selesai waktunya — kunjungan bisa ditandai selesai setelah jam kunjungan berakhir.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ];
      case 'COMPLETED':
        return [
          FilledButton.icon(
            onPressed: () => setState(() => _showReviewForm = !_showReviewForm),
            icon: const Icon(Icons.star),
            label: const Text('Nilai Santri'),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _row(IconData i, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 10),
            SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  String _fmt(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _rp(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
