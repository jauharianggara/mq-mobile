import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mq_shared/mq_shared.dart';
import 'home_point_screen.dart';

import '../main.dart';
import 'visit_pick_ustadz_screen.dart';
import 'visit_status_screen.dart';

/// Tab "Pesan" — daftar pesanan kunjungan ustadz + entry point pesan baru.
class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Titik kunjungan: titik rumah tersimpan (default) atau titik lain via GPS.
  /// TIDAK meminta izin GPS saat memakai titik rumah.
  Future<String?> _openPanggil() async {
    Map<String, dynamic>? hp;
    try {
      hp = await api.homePoint();
    } catch (_) {}
    if (hp == null || mounted == false) {
      // belum pernah set titik rumah -> wajib set dulu
      if (!mounted) return 'Set titik rumah dulu untuk memesan.';
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const HomePointScreen()),
      );
      if (ok != true) return null;
      try {
        hp = await api.homePoint();
      } catch (_) {}
      if (hp == null || !mounted) return null;
    }
    final homeLat = (hp['lat'] as num).toDouble();
    final homeLng = (hp['lng'] as num).toDouble();
    final homeLabel = (hp['address_label'] as String?) ?? 'Titik rumah saya';

    // pilihan tempat kunjungan utk pesanan ini
    String? choice;
    if (mounted) {
      choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Kunjungan dilakukan di mana?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Titik Rumah Saya'),
                  subtitle: Text(homeLabel, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, 'home'),
                ),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Tempat lain'),
                  subtitle: const Text('Pakai posisi saya sekarang',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, 'other'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (choice == null || !mounted) return null;

    double lat = homeLat, lng = homeLng;
    String label = homeLabel;
    if (choice == 'other') {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return 'Izin lokasi diperlukan untuk memakai posisi sekarang.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      label = 'Tempat lain (posisi saat memesan)';
    }

    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitPickUstadzScreen(
          lat: lat,
          lng: lng,
          accuracyM: 20,
          addressLabel: label,
        ),
      ),
    );
    if (done == true) _load();
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await api.visitList();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat pesanan. Tarik ke bawah untuk coba lagi.';
        _loading = false;
      });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panggil Ustadz'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final err = await _openPanggil();
          if (err != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Panggil Ustadz'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    EmptyState(icon: Icons.error_outline, message: _error!),
                  ])
                : _items.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 100),
                        EmptyState(
                          icon: Icons.auto_stories_outlined,
                          title: 'Belum ada pesanan',
                          subtitle: 'Panggil ustadz terdekat untuk ngaji di rumah —\npilih jadwal dari jam ketersediaannya.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final v = _items[i] as Map<String, dynamic>;
                          final active = ['REQUESTED', 'WAITING_CONFIRM', 'CONFIRMED'].contains(v['status']);
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => VisitStatusScreen(visitId: v['id'] as int)));
                                _load();
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Kunjungan ${v['duration_hours'] ?? '-'} jam — ${v['ustadz']?['full_name'] ?? 'Ustadz'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: v['status'] as String? ?? ''),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${_fmtDate(v['scheduled_at'] as String?)}  •  Rp ${_fmtRp(v['price_total'])}'
                                  '${active ? '  •  ketuk utk detail' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: active
                                  ? const Icon(Icons.chevron_right)
                                  : v['status'] == 'COMPLETED'
                                      ? const Icon(Icons.star_outline, color: Color(0xFFC9A227))
                                      : null,
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  String _fmtRp(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
