import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Titik Rumah Saya (santri) — titik default kunjungan ustadz.
/// Di-set sekali: pakai GPS saat benar-benar di rumah, lalu isi alamat.
class HomePointScreen extends StatefulWidget {
  const HomePointScreen({super.key, this.selectMode = false});
  final bool selectMode;

  @override
  State<HomePointScreen> createState() => _HomePointScreenState();
}

class _HomePointScreenState extends State<HomePointScreen> {
  final _alamat = TextEditingController();
  double? _lat, _lng;
  bool _loading = true;
  bool _saving = false;
  bool _gettingFix = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await api.homePoint();
      if (!mounted) return;
      setState(() {
        if (p != null) {
          _lat = (p['lat'] as num?)?.toDouble();
          _lng = (p['lng'] as num?)?.toDouble();
          _alamat.text = (p['address_label'] as String?) ?? '';
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useGps() async {
    if (_gettingFix) return;
    setState(() => _gettingFix = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showSnack('Izin lokasi diperlukan untuk mengambil titik.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _showSnack('Titik diambil dari posisi sekarang', success: true);
    } catch (_) {
      if (mounted) _showSnack('Tidak bisa mengambil lokasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _gettingFix = false);
    }
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      _showSnack('Ambil titik dulu (GPS saat Anda di rumah).');
      return;
    }
    final titik = {
      'lat': _lat,
      'lng': _lng,
      'address_label': _alamat.text.trim(),
    };
    // Mode pilih (saat booking "tempat lain"): kembalikan titik TANPA menyimpan
    // sebagai titik rumah. Mode biasa: simpan sebagai titik rumah.
    if (widget.selectMode) {
      Navigator.pop(context, titik);
      return;
    }
    setState(() => _saving = true);
    try {
      await api.saveHomePoint(lat: _lat!, lng: _lng!, addressLabel: _alamat.text.trim());
      if (!mounted) return;
      _showSnack('Titik rumah tersimpan', success: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(apiErrorMessage(e, 'Gagal menyimpan titik rumah'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  @override
  void dispose() {
    _alamat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.selectMode ? 'Pilih Titik Kunjungan' : 'Titik Rumah Saya')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.selectMode)
                  const Text(
                      'Titik ini dipakai ustadz untuk datang ke tempat Anda.',
                      style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.home_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                (_lat != null && _lng != null)
                                    ? 'Titik terpasang: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                                    : 'Belum ada titik',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: (_lat != null)
                                        ? AppColors.success
                                        : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _gettingFix ? null : _useGps,
                            icon: _gettingFix
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 18),
                            label: const Text(
                                'Pakai GPS Saya — tekan saat Anda di rumah'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _alamat,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat (keterangan untuk ustadz)',
                    hintText: 'Jl. Melati 12, Cibinong',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving
                      ? 'Menyimpan…'
                      : widget.selectMode
                          ? 'Gunakan Titik Ini'
                          : 'Simpan Titik Rumah'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Titik ini dipakai sebagai tempat kunjungan setiap kali Anda memesan ustadz — tidak perlu izin GPS berulang.',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
              ],
            ),
    );
  }
}
