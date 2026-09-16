import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'visit_request_screen.dart';
import 'visit_settings_screen.dart';

/// Tab Kunjungan ustadz: permintaan masuk + jadwal berjalan + lokasi sharing.
class VisitIncomingScreen extends StatefulWidget {
  const VisitIncomingScreen({super.key});

  @override
  State<VisitIncomingScreen> createState() => _VisitIncomingScreenState();
}

class _VisitIncomingScreenState extends State<VisitIncomingScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _locating = false;
  bool _locBanner = false;

  @override
  void initState() {
    super.initState();
    _load();
    _maybeUpdateLocation();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await api.ustadzMyVisits();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat kunjungan.';
      });
    }
  }

  /// Lokasi ustadz = kunci nearby. Silent-update tiap buka tab bila sudah consent.
  Future<void> _maybeUpdateLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('visit_location_consent') != true) {
      if (mounted) setState(() => _locBanner = true);
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locBanner = true);
        return;
      }
      if (mounted) setState(() => _locating = true);
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
      await api.putMyLocation(pos.latitude, pos.longitude, accuracyM: pos.accuracy.round());
    } catch (_) {
      // silent — lokasi lama masih dipakai server sampai 6 jam
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _askLocation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bagikan lokasi Anda?'),
        content: const Text(
          'Lokasi GPS Anda dipakai santri untuk menemukan ustadz terdekat (hanya jarak — '
          'koordinat Anda TIDAK pernah diperlihatkan ke santri).\n\n'
          'Lokasi diperbarui saat aplikasi dibuka; tanpa pelacakan latar belakang.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Setuju')),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('visit_location_consent', true);
    if (mounted) setState(() => _locBanner = false);
    _maybeUpdateLocation();
  }

  String _fmt(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final incoming = (_data?['incoming'] as List<dynamic>? ?? []);
    final upcoming = (_data?['upcoming'] as List<dynamic>? ?? []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kunjungan'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan kunjungan',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const VisitSettingsScreen()));
              _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    EmptyState(icon: Icons.error_outline, message: _error!),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (_locBanner)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.amber.withValues(alpha: 0.15),
                          child: ListTile(
                            leading: const Icon(Icons.location_off_outlined),
                            title: const Text('Aktifkan lokasi agar santri menemukan Anda',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: FilledButton(
                              onPressed: _askLocation,
                              child: const Text('Aktifkan'),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(_locating ? Icons.sync : Icons.my_location,
                                  size: 14, color: Theme.of(context).hintColor),
                              const SizedBox(width: 6),
                              Text(
                                _locating ? 'Memperbarui lokasi…' : 'Lokasi terkini terbagikan (jarak saja)',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                        ),
                      if (incoming.isNotEmpty) ...[
                        Text('Permintaan Masuk (${incoming.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 8),
                        ...incoming.map((v) => _incomingCard(v as Map<String, dynamic>)),
                        const SizedBox(height: 16),
                      ],
                      Text('Jadwal Berjalan', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (upcoming.isEmpty)
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              incoming.isEmpty
                                  ? 'Belum ada permintaan kunjungan. Atur tarif & status menerima di pengaturan (ikon roda gigi).'
                                  : 'Belum ada kunjungan terkonfirmasi.',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                            ),
                          ),
                        )
                      else
                        ...upcoming.map((v) => _upcomingCard(v as Map<String, dynamic>)),
                    ],
                  ),
      ),
    );
  }

  Widget _incomingCard(Map<String, dynamic> v) {
    final r = v['requester'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => VisitRequestScreen(visitId: v['id'] as int)));
          _load();
        },
        leading: CircleAvatar(child: Text((r['full_name'] as String? ?? 'S')[0].toUpperCase())),
        title: Text('${r['full_name'] ?? 'Santri'} • ${v['duration_hours'] ?? '-'} jam',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${_fmt(v['scheduled_at'] as String?)} • Rp ${_rp(v['price_total'])}'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusBadge(status: v['status'] as String? ?? ''),
            const SizedBox(height: 4),
            Text(
              r['rating_avg'] == null ? 'Santri baru' : '★ ${(r['rating_avg'] as num).toStringAsFixed(1)}',
              style: TextStyle(
                  fontSize: 11,
                  color: r['rating_avg'] == null ? Colors.grey : const Color(0xFF8a6d1a),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingCard(Map<String, dynamic> v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => VisitRequestScreen(visitId: v['id'] as int)));
          _load();
        },
        leading: const Icon(Icons.event_available, color: Color(0xFF16A34A)),
        title: Text('Kunjungan ${v['duration_hours'] ?? '-'} jam — ${v['requester']?['full_name'] ?? 'Santri'}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${_fmt(v['scheduled_at'] as String?)} • chat tersedia'),
        ),
        trailing: const StatusBadge(status: 'CONFIRMED'),
      ),
    );
  }

  String _rp(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
