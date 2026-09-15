import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'visit_pick_ustadz_screen.dart';

/// Flow pesan: (1) pilih layanan → (2) jadwal → (3) lokasi GPS + patokan rumah → cari ustadz.
/// Consent lokasi PDP: dialog penjelasan saat pertama kali, tersimpan preferensi.
class VisitCreateScreen extends StatefulWidget {
  const VisitCreateScreen({super.key});

  @override
  State<VisitCreateScreen> createState() => _VisitCreateScreenState();
}

class _VisitCreateScreenState extends State<VisitCreateScreen> {
  List<dynamic> _services = [];
  int? _serviceId;
  DateTime? _schedule;
  Position? _position;
  String _positionInfo = 'Belum diambil';
  final _labelCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final s = await api.visitServices();
      if (!mounted) return;
      setState(() {
        _services = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat jenis layanan (modul mungkin nonaktif)')));
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'Pilih tanggal kunjungan',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 3))),
      helpText: 'Pilih jam kunjungan',
    );
    if (t == null) return;
    final picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (picked.isBefore(now.add(const Duration(hours: 2)))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Jadwal minimal 2 jam dari sekarang')));
      return;
    }
    setState(() => _schedule = picked);
  }

  Future<void> _getLocation() async {
    // consent PDP sekali
    final prefs = await SharedPreferences.getInstance();
    final consented = prefs.getBool('visit_location_consent');
    if (consented != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bagikan lokasi Anda?'),
          content: const Text(
            'Lokasi GPS Anda dipakai untuk mencari ustadz terdekat dan menunjukkan titik kunjungan '
            'kepada ustadz SETELAH pesanan dikonfirmasi.\n\n'
            'Koordinat Anda tidak pernah dibagikan ke santri lain dan dapat dihapus kapan saja '
            'dengan menghapus akun.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Setuju')),
          ],
        ),
      );
      if (ok != true) return;
      await prefs.setBool('visit_location_consent', true);
    }

    setState(() => _gettingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak — tidak bisa mencari ustadz terdekat')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
      // upload lokasi (biar ustadz-side juga fresh saat kita jadi pihak pencari)
      await api.putMyLocation(pos.latitude, pos.longitude, accuracyM: pos.accuracy.round());
      if (!mounted) return;
      setState(() {
        _position = pos;
        _positionInfo =
            'Tersedia (akurasi ±${pos.accuracy.round()} m)\n${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _positionInfo = 'Gagal mengambil GPS — coba lagi di luar ruangan');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gagal mengambil lokasi GPS')));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  String get _scheduleText {
    if (_schedule == null) return 'Belum dipilih';
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final d = _schedule!;
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.year} • '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  bool get _canProceed =>
      _serviceId != null && _schedule != null && _position != null && _labelCtrl.text.trim().length >= 5;

  void _next() {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitPickUstadzScreen(
          serviceTypeId: _serviceId!,
          schedule: _schedule!,
          lat: _position!.latitude,
          lng: _position!.longitude,
          accuracyM: _position!.accuracy.round(),
          addressLabel: _labelCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pesan Ustadz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Ustadz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('1. Pilih jenis layanan'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _services.map<Widget>((s) {
              final selected = s['id'] == _serviceId;
              return ChoiceChip(
                label: Text(s['name'] as String? ?? '-'),
                selected: selected,
                onSelected: (_) => setState(() => _serviceId = s['id'] as int),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _section('2. Jadwal kunjungan'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(_scheduleText, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Minimal 2 jam dari sekarang • maks 14 hari'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickSchedule,
            ),
          ),
          const SizedBox(height: 20),
          _section('3. Lokasi & patokan rumah'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _positionInfo,
                          style: TextStyle(
                            fontSize: 13,
                            color: _position != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _gettingLocation ? null : _getLocation,
                        icon: _gettingLocation
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 18),
                        label: const Text('GPS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Patokan rumah (wajib)',
                      hintText: 'cth: Gang masjid, rumah pagar hijau',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan untuk ustadz (opsional)',
                      hintText: 'cth: fokus perbaikan makhraj',
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _canProceed ? _next : null,
            icon: const Icon(Icons.search),
            label: const Text('Cari Ustadz Terdekat'),
          ),
          if (!_canProceed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Lengkapi layanan, jadwal, GPS, dan patokan rumah dulu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
}
