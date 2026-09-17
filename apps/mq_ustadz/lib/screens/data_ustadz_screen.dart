import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Data Ustadz Saya — data pribadi + keustadzan (pendidikan, pengalaman)
/// + rekening penarikan tersimpan. Halaman penuh, satu tombol simpan.
class DataUstadzScreen extends StatefulWidget {
  const DataUstadzScreen({super.key});

  @override
  State<DataUstadzScreen> createState() => _DataUstadzScreenState();
}

class _DataUstadzScreenState extends State<DataUstadzScreen> {
  final _nama = TextEditingController();
  final _hp = TextEditingController();
  final _alamat = TextEditingController();
  final _kota = TextEditingController();
  final _pendidikan = TextEditingController();
  final _pengalaman = TextEditingController();
  final _bank = TextEditingController();
  final _noRek = TextEditingController();
  final _anRek = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  double? _pointLat, _pointLng;
  final _pointLabel = TextEditingController();
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
      final results = await Future.wait([
        api.myProfile(),
        api.ustadzDetail(),
        api.ustadzBank(),
        api.ustadzPoint(),
      ]);
      if (!mounted) return;
      final p = results[0];
      final d = results[1];
      final b = results[2];
      final bd = p?['birth_date'] as String?;
      setState(() {
        _nama.text = (p?['full_name'] as String?) ?? '';
        _hp.text = (p?['phone'] as String?) ?? '';
        _alamat.text = (p?['address_text'] as String?) ?? '';
        _kota.text = (p?['city'] as String?) ?? '';
        _gender = p?['gender'] as String?;
        _birthDate = bd != null && bd.isNotEmpty ? DateTime.tryParse(bd) : null;
        _pendidikan.text = (d?['pendidikan_terakhir'] as String?) ?? '';
        _pengalaman.text = (d?['pengalaman_mengajar'] as String?) ?? '';
        _bank.text = (b?['bank_name'] as String?) ?? '';
        _noRek.text = (b?['bank_account_no'] as String?) ?? '';
        _anRek.text = (b?['bank_account_name'] as String?) ?? '';
        final pt = results[3];
        _pointLat = (pt?['lat'] as num?)?.toDouble();
        _pointLng = (pt?['lng'] as num?)?.toDouble();
        _pointLabel.text = (pt?['label'] as String?) ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, 'Gagal memuat data'))));
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
      helpText: 'Tanggal lahir',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await api.patchMe({
        'full_name': _nama.text.trim(),
        'phone': _hp.text.trim(),
        'gender': _gender,
        if (_birthDate != null) 'birth_date': _ymd(_birthDate!),
        'address_text': _alamat.text.trim(),
        'city': _kota.text.trim(),
      });
      await api.ustadzSaveDetail({
        'pendidikan_terakhir': _pendidikan.text.trim(),
        'pengalaman_mengajar': _pengalaman.text.trim(),
      });
      if (_bank.text.trim().isNotEmpty ||
          _noRek.text.trim().isNotEmpty ||
          _anRek.text.trim().isNotEmpty) {
        await api.ustadzSaveBank({
          'bank_name': _bank.text.trim(),
          'bank_account_no': _noRek.text.trim(),
          'bank_account_name': _anRek.text.trim(),
        });
      }
      if (_pointLat != null && _pointLng != null) {
        await api.ustadzSavePoint(
            lat: _pointLat!, lng: _pointLng!, label: _pointLabel.text.trim());
      }
      if (!mounted) return;
      _showSnack('Data tersimpan', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(apiErrorMessage(e, 'Gagal menyimpan data'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Ambil titik lokasi dari GPS saat ini — ustadz menekan saat berada di titik itu.
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
        _showSnack('Izin lokasi diperlukan.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _pointLat = pos.latitude;
        _pointLng = pos.longitude;
      });
      _showSnack('Titik lokasi diambil dari posisi sekarang', success: true);
    } catch (_) {
      if (mounted) _showSnack('Tidak bisa mengambil lokasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _gettingFix = false);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    for (final c in [_nama, _hp, _alamat, _kota, _pendidikan, _pengalaman, _bank, _noRek, _anRek, _pointLabel]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Ustadz Saya')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field('Nama Lengkap', _nama),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                      labelText: 'Jenis Kelamin', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Perempuan')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Tanggal Lahir', border: OutlineInputBorder()),
                    child: Text(_birthDate == null
                        ? '—'
                        : '${_birthDate!.day.toString().padLeft(2, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.year}'),
                  ),
                ),
                const SizedBox(height: 14),
                _field('No. HP/WA', _hp, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _field('Alamat/Kota', _alamat),
                const SizedBox(height: 14),
                _field('Kota', _kota),
                const SizedBox(height: 22),
                Text('Keustadzan',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 10),
                _field('Pendidikan Terakhir', _pendidikan),
                const SizedBox(height: 14),
                _field('Pengalaman Mengajar', _pengalaman, maxLines: 3),
                const SizedBox(height: 22),
                Text('Titik Lokasi Saya',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text(
                  'Santri mencari ustadz dari titik ini — bukan dari posisi HP Anda saat itu.',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (_pointLat != null) ? Icons.location_on : Icons.location_off,
                              color: (_pointLat != null) ? AppColors.success : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                (_pointLat != null && _pointLng != null)
                                    ? 'Titik terpasang: ${_pointLat!.toStringAsFixed(5)}, ${_pointLng!.toStringAsFixed(5)}'
                                    : 'Belum ada titik — Anda belum muncul di pencarian santri',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pointLabel,
                          decoration: const InputDecoration(
                            labelText: 'Nama titik (opsional)',
                            hintText: 'mis. Kampus mengaji',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
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
                            label: const Text('Ambil dari GPS sekarang'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Rekening Penarikan',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Dipakai otomatis saat menarik dana.',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                const SizedBox(height: 10),
                _field('Nama Bank', _bank),
                const SizedBox(height: 14),
                _field('Nomor Rekening', _noRek, keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _field('Atas Nama', _anRek),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Menyimpan…' : 'Simpan Perubahan'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
