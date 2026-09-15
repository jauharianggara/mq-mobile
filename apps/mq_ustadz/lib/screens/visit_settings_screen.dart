import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Pengaturan kunjungan ustadz: status menerima, kapasitas, dan tarif per layanan
/// (tarif WAJIB > 0 — tidak ada booking gratis; radius = global admin).
class VisitSettingsScreen extends StatefulWidget {
  const VisitSettingsScreen({super.key});

  @override
  State<VisitSettingsScreen> createState() => _VisitSettingsScreenState();
}

class _VisitSettingsScreenState extends State<VisitSettingsScreen> {
  bool _accepting = false;
  int _maxActive = 2;
  List<dynamic> _tarif = [];
  List<dynamic> _services = [];
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
      final s = await api.ustadzVisitSettings();
      final t = await api.ustadzVisitServices();
      final master = await api.visitServices();
      if (!mounted) return;
      setState(() {
        _accepting = s?['is_accepting'] == true;
        _maxActive = (s?['max_active_visits'] as num?)?.toInt() ?? 2;
        _tarif = t;
        _services = master;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gagal memuat pengaturan')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await api.ustadzPutVisitSettings(isAccepting: _accepting, maxActiveVisits: _maxActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_accepting ? 'Anda kini menerima pesanan kunjungan' : 'Status: tidak menerima')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? _tarifOf(int serviceTypeId) {
    for (final t in _tarif) {
      if ((t as Map<String, dynamic>)['service_type_id'] == serviceTypeId) return t;
    }
    return null;
  }

  Future<void> _editTarif(Map<String, dynamic> svc) async {
    final existing = _tarifOf(svc['id'] as int);
    final price = TextEditingController(
        text: existing != null ? '${(existing['price_amount'] as num?)?.toInt() ?? 0}' : '');
    final dur = TextEditingController(
        text: existing != null ? '${(existing['duration_minutes'] as num?)?.toInt() ?? 60}' : '60');
    final note = TextEditingController(text: existing?['note'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tarif — ${svc['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Tarif (Rp, min 10.000)', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dur,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Durasi (menit 15-600)', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)', isDense: true),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              child: const Text('Hapus'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == 'delete') {
      try {
        await api.ustadzDeleteVisitService(svc['id'] as int);
        _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus')));
        }
      }
      return;
    }
    if (ok != true) return;
    try {
      await api.ustadzUpsertVisitService(
        serviceTypeId: svc['id'] as int,
        priceAmount: int.tryParse(price.text.trim()) ?? 0,
        durationMinutes: int.tryParse(dur.text.trim()) ?? 60,
        note: note.text,
      );
      _load();
    } catch (e) {
      if (mounted) {
        final es = e.toString();
        String msg = 'Gagal menyimpan tarif';
        if (es.contains('422')) msg = 'Tarif min Rp 10.000 (semua layanan berbayar)';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Kunjungan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Menerima pesanan kunjungan',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Santri terdekat bisa menemukan & memesan Anda',
                              style: TextStyle(fontSize: 12)),
                          value: _accepting,
                          onChanged: (v) => setState(() => _accepting = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Kapasitas aktif'),
                            Expanded(
                              child: Slider(
                                value: _maxActive.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                label: '$_maxActive',
                                onChanged: (v) => setState(() => _maxActive = v.round()),
                              ),
                            ),
                            Text('$_maxActive'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Radius pencarian diatur oleh admin pondok (berlaku semua ustadz).',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Menyimpan…' : 'Simpan Pengaturan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Tarif per layanan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Semua layanan berbayar (min Rp 10.000). Santri melihat tarif saat memilih.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                ..._services.map<Widget>((s) {
                  final m = s as Map<String, dynamic>;
                  final t = _tarifOf(m['id'] as int);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _editTarif(m),
                      title: Text(m['name'] as String? ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: t == null
                          ? const Text('Belum disetel — tidak muncul di pencarian',
                              style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)))
                          : Text(
                              'Rp ${_rp(t['price_amount'])} • ${t['duration_minutes']} menit',
                              style: const TextStyle(fontSize: 12)),
                      trailing: t == null
                          ? const Chip(label: Text('Setel', style: TextStyle(fontSize: 11)))
                          : const Icon(Icons.edit_outlined, size: 20),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  String _rp(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
