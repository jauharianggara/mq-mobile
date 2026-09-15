import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import 'visit_status_screen.dart';

/// Daftar ustadz terdekat (radius global admin) — santri pilih sendiri (keputusan user #3).
/// Response TIDAK berisi koordinat ustadz (privacy by design).
class VisitPickUstadzScreen extends StatefulWidget {
  final int serviceTypeId;
  final DateTime schedule;
  final double lat;
  final double lng;
  final int accuracyM;
  final String addressLabel;
  final String? note;

  const VisitPickUstadzScreen({
    super.key,
    required this.serviceTypeId,
    required this.schedule,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.addressLabel,
    this.note,
  });

  @override
  State<VisitPickUstadzScreen> createState() => _VisitPickUstadzScreenState();
}

class _VisitPickUstadzScreenState extends State<VisitPickUstadzScreen> {
  List<dynamic> _ustadz = [];
  bool _loading = true;
  String? _error;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.visitNearby(widget.lat, widget.lng, serviceTypeId: widget.serviceTypeId);
      if (!mounted) return;
      setState(() {
        _ustadz = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Tidak bisa mencari ustadz sekarang.';
        _loading = false;
      });
    }
  }

  String _isoSchedule() {
    final u = widget.schedule.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}T'
        '${u.hour.toString().padLeft(2, '0')}:${u.minute.toString().padLeft(2, '0')}:00Z';
  }

  Future<void> _showDetail(Map<String, dynamic> u) async {
    // bottom sheet: profil ringkas + review + tombol pesan
    final reviews = await api.visitUstadzReviews(u['ustadz_id'] as int).catchError((_) => <dynamic>[]);
    if (!mounted) return;
    final tarif = (u['services'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['service_type_id'] == widget.serviceTypeId, orElse: () => <String, dynamic>{});
    final price = (tarif['price_amount'] as num?)?.toInt() ?? 0;
    final dur = (tarif['duration_minutes'] as num?)?.toInt() ?? 60;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (ctx, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text((u['full_name'] as String? ?? 'U')[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['full_name'] as String? ?? 'Ustadz',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                      Text('${(u['distance_km'] as num?)?.toStringAsFixed(1)} km dari lokasi Anda',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                _ratingBadge(u),
              ],
            ),
            const Divider(height: 24),
            _row(Icons.sell_outlined, 'Tarif', 'Rp ${_rp(price)} • $dur menit'),
            const SizedBox(height: 8),
            const Text('Penilaian santri lain', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (reviews.isEmpty)
              const Text('Belum ada penilaian.', style: TextStyle(fontSize: 13))
            else
              ...reviews.take(10).map<Widget>((r) {
                final m = r as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('★${m['rating']}', style: const TextStyle(color: Color(0xFFC9A227), fontWeight: FontWeight.w700)),
                  title: Text(m['comment'] ?? '(tanpa catatan)', style: const TextStyle(fontSize: 13)),
                  subtitle: Text('oleh ${m['reviewer_first_name']}', style: const TextStyle(fontSize: 11)),
                );
              }),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _book(u, price),
              icon: const Icon(Icons.request_quote_outlined),
              label: Text('Pesan & Bayar Rp ${_rp(price)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingBadge(Map<String, dynamic> u) {
    final avg = u['rating_avg'];
    final count = (u['rating_count'] as num?)?.toInt() ?? 0;
    if (avg == null || count == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Baru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A227).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('★ ${(avg as num).toStringAsFixed(1)} ($count)',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8a6d1a))),
    );
  }

  Future<void> _book(Map<String, dynamic> u, int price) async {
    Navigator.pop(context); // tutup sheet
    setState(() => _booking = true);
    try {
      final d = await api.visitCreate(
        ustadzId: u['ustadz_id'] as int,
        serviceTypeId: widget.serviceTypeId,
        scheduledAt: _isoSchedule(),
        lat: widget.lat,
        lng: widget.lng,
        accuracyM: widget.accuracyM,
        addressLabel: widget.addressLabel,
        note: widget.note,
        idempotencyKey: const Uuid().v4(),
      );
      if (!mounted) return;
      final visitId = d?['visit']?['id'] as int?;
      final invoiceUrl = d?['invoice_url'] as String?;
      if (visitId == null) throw 'gagal';
      // langsung ke status screen (bayar di sana)
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => VisitStatusScreen(visitId: visitId, initialInvoiceUrl: invoiceUrl)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gagal membuat pesanan — coba lagi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustadz Terdekat')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: EmptyState(icon: Icons.wifi_off, message: _error!))
              : _ustadz.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 100),
                      EmptyState(
                        icon: Icons.search_off,
                        title: 'Tidak ada ustadz di sekitar',
                        subtitle: 'Ustadz aktif & lokasinya segar dalam radius\nlayanan belum tersedia. Coba lagi nanti.',
                      ),
                    ])
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ustadz.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final u = _ustadz[i] as Map<String, dynamic>;
                          final tarif = (u['services'] as List<dynamic>? ?? [])
                              .cast<Map<String, dynamic>>()
                              .where((s) => s['service_type_id'] == widget.serviceTypeId)
                              .toList();
                          final price = tarif.isEmpty ? 0 : (tarif.first['price_amount'] as num?)?.toInt() ?? 0;
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              onTap: () => _showDetail(u),
                              leading: CircleAvatar(
                                child: Text((u['full_name'] as String? ?? 'U')[0].toUpperCase()),
                              ),
                              title: Text(u['full_name'] as String? ?? 'Ustadz',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${(u['distance_km'] as num?)?.toStringAsFixed(1)} km • Rp ${_rp(price)}'),
                              trailing: _ratingBadge(u),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _row(IconData i, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
