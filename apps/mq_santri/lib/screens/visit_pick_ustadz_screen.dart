import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'visit_schedule_screen.dart';

/// Daftar ustadz terdekat (radius global admin) — santri pilih sendiri.
/// Tap kartu = halaman profil penuh (bukan popup). Response TANPA koordinat ustadz.
class VisitPickUstadzScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final int accuracyM;
  final String addressLabel;
  final String? note;

  const VisitPickUstadzScreen({
    super.key,
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
      final r = await api.visitNearby(widget.lat, widget.lng);
      if (!mounted) return;
      setState(() {
        _ustadz = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tidak bisa mencari ustadz sekarang.';
        _loading = false;
      });
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
                            'Ustadz yang menerima pesanan & lokasinya segar dalam radius layanan belum tersedia — coba lagi nanti.',
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
                          final price = (u['price_per_hour'] as num?)?.toInt() ?? 0;
                          final count = (u['rating_count'] as num?)?.toInt() ?? 0;
                          final avg = u['rating_avg'];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UstadzProfilePage(
                                    u: u,
                                    lat: widget.lat,
                                    lng: widget.lng,
                                    accuracyM: widget.accuracyM,
                                    addressLabel: widget.addressLabel,
                                    note: widget.note,
                                  ),
                                ),
                              ),
                              leading: CircleAvatar(
                                child: Text((u['full_name'] as String? ?? 'U')[0].toUpperCase()),
                              ),
                              title: Text(u['full_name'] as String? ?? 'Ustadz',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${(u['distance_km'] as num?)?.toStringAsFixed(1)} km • Rp ${_rp(price)}/jam'),
                              trailing: avg == null || count == 0
                                  ? const Text('Baru',
                                      style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))
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

/// Halaman profil ustadz — foto, rating, tarif/jam, review santri lain, tombol Buat Jadwal.
class UstadzProfilePage extends StatefulWidget {
  final Map<String, dynamic> u;
  final double lat;
  final double lng;
  final int accuracyM;
  final String addressLabel;
  final String? note;

  const UstadzProfilePage({
    super.key,
    required this.u,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.addressLabel,
    this.note,
  });

  @override
  State<UstadzProfilePage> createState() => _UstadzProfilePageState();
}

class _UstadzProfilePageState extends State<UstadzProfilePage> {
  List<dynamic> _reviews = [];
  bool _loadingReviews = true;

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

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final count = (u['rating_count'] as num?)?.toInt() ?? 0;
    final avg = u['rating_avg'];
    final price = (u['price_per_hour'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Ustadz')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisitScheduleScreen(
                  u: u,
                  lat: widget.lat,
                  lng: widget.lng,
                  accuracyM: widget.accuracyM,
                  addressLabel: widget.addressLabel,
                  note: widget.note,
                ),
              ),
            ),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Buat Jadwal'),
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
              title: const Text('Tarif per jam', style: TextStyle(fontSize: 13, color: Colors.grey)),
              subtitle: Text('Rp ${_rp(price)} / jam',
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
