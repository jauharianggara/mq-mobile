import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import 'visit_status_screen.dart';

/// Daftar ustadz terdekat (radius global admin) — santri pilih sendiri (keputusan user #3).
/// Tap kartu = halaman profil penuh (bukan popup). Response TIDAK berisi koordinat ustadz.
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

  int _tarifOf(Map<String, dynamic> u) {
    final tarif = (u['services'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['service_type_id'] == widget.serviceTypeId)
        .toList();
    return tarif.isEmpty ? 0 : (tarif.first['price_amount'] as num?)?.toInt() ?? 0;
  }

  Future<void> _book(Map<String, dynamic> u) async {
    setState(() => _loading = true);
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
      // tutup halaman profil + daftar ustadz, langsung ke status screen (bayar di sana)
      Navigator.of(context).pop(); // profil ustadz
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => VisitStatusScreen(visitId: visitId, initialInvoiceUrl: invoiceUrl)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
                        subtitle:
                            'Ustadz aktif & lokasinya segar dalam radius layanan belum tersedia — coba lagi nanti.',
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
                          final price = _tarifOf(u);
                          final count = (u['rating_count'] as num?)?.toInt() ?? 0;
                          final avg = u['rating_avg'];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UstadzProfilePage(
                                      u: u,
                                      serviceTypeId: widget.serviceTypeId,
                                      onBook: () => _book(u),
                                    ),
                                  ),
                                );
                                if (mounted) setState(() {}); // refresh list state
                              },
                              leading: CircleAvatar(
                                child: Text(
                                    (u['full_name'] as String? ?? 'U')[0].toUpperCase()),
                              ),
                              title: Text(u['full_name'] as String? ?? 'Ustadz',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${(u['distance_km'] as num?)?.toStringAsFixed(1)} km • Rp ${_rp(price)}'),
                              trailing: avg == null || count == 0
                                  ? const Text('Baru',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey))
                                  : Text('★${(avg as num).toStringAsFixed(1)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF8a6d1a))),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

/// Halaman profil ustadz — pengganti bottom-sheet (konten padat butuh ruang penuh).
class UstadzProfilePage extends StatefulWidget {
  final Map<String, dynamic> u;
  final int serviceTypeId;
  final VoidCallback onBook;

  const UstadzProfilePage({
    super.key,
    required this.u,
    required this.serviceTypeId,
    required this.onBook,
  });

  @override
  State<UstadzProfilePage> createState() => _UstadzProfilePageState();
}

class _UstadzProfilePageState extends State<UstadzProfilePage> {
  List<dynamic> _reviews = [];
  bool _loadingReviews = true;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final r = await api.visitUstadzReviews(widget.u['ustadz_id'] as int);
      if (!mounted) return;
      setState(() {
        _reviews = r;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  int get _price {
    final tarif = (widget.u['services'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['service_type_id'] == widget.serviceTypeId)
        .toList();
    return tarif.isEmpty ? 0 : (tarif.first['price_amount'] as num?)?.toInt() ?? 0;
  }

  int get _dur {
    final tarif = (widget.u['services'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['service_type_id'] == widget.serviceTypeId)
        .toList();
    return tarif.isEmpty ? 60 : (tarif.first['duration_minutes'] as num?)?.toInt() ?? 60;
  }

  Future<void> _book() async {
    setState(() => _booking = true);
    widget.onBook();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final count = (u['rating_count'] as num?)?.toInt() ?? 0;
    final avg = u['rating_avg'];
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Ustadz')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _booking ? null : _book,
            icon: _booking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.request_quote_outlined),
            label: Text(_booking ? 'Memproses…' : 'Pesan & Bayar Rp ${_rp(_price)}'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text((u['full_name'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['full_name'] as String? ?? 'Ustadz',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('${(u['distance_km'] as num?)?.toStringAsFixed(1)} km dari lokasi Anda',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(avg == null ? '—' : '★${(avg as num).toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF8a6d1a))),
                  Text('$count ulasan', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Tarif layanan yang dipilih',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text('Rp ${_rp(_price)} • $_dur menit',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Penilaian santri lain',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          if (_loadingReviews)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else if (_reviews.isEmpty)
            const Text('Belum ada penilaian.', style: TextStyle(fontSize: 13))
          else
            ..._reviews.map<Widget>((r) {
              final m = r as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('★${m['rating']}',
                              style: const TextStyle(
                                  color: Color(0xFFC9A227),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const SizedBox(width: 8),
                          Text('oleh ${m['reviewer_first_name']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(m['comment'] ?? '(tanpa catatan)', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
