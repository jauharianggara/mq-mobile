import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Data Saya (master data santri) — satu halaman penuh, semua field dari
/// PATCH /me + GET /me/profile. Tidak ada popup form.
class DataSayaScreen extends StatefulWidget {
  const DataSayaScreen({super.key});

  @override
  State<DataSayaScreen> createState() => _DataSayaScreenState();
}

class _DataSayaScreenState extends State<DataSayaScreen> {
  final _nama = TextEditingController();
  final _hp = TextEditingController();
  final _alamat = TextEditingController();
  final _kota = TextEditingController();
  final _provinsi = TextEditingController();
  String? _gender; // MALE / FEMALE
  DateTime? _birthDate;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await api.myProfile();
      if (!mounted) return;
      final bd = p?['birth_date'] as String?;
      setState(() {
        _nama.text = (p?['full_name'] as String?) ?? '';
        _hp.text = (p?['phone'] as String?) ?? '';
        _alamat.text = (p?['address_text'] as String?) ?? '';
        _kota.text = (p?['city'] as String?) ?? '';
        _provinsi.text = (p?['province'] as String?) ?? '';
        _gender = p?['gender'] as String?;
        _birthDate = bd != null && bd.isNotEmpty ? DateTime.tryParse(bd) : null;
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
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
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
        'province': _provinsi.text.trim(),
      });
      if (!mounted) return;
      _showSnack('Data tersimpan', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(apiErrorMessage(e, 'Gagal menyimpan data'));
    } finally {
      if (mounted) setState(() => _saving = false);
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
    _nama.dispose(); _hp.dispose(); _alamat.dispose();
    _kota.dispose(); _provinsi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Saya')),
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
                _field('Alamat', _alamat, maxLines: 3),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _field('Kota', _kota)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Provinsi', _provinsi)),
                ]),
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
