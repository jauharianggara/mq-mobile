import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Pengaturan Panggil Ustadz v2 (W3): status menerima, kapasitas, TARIF PER JAM,
/// dan KETERSEDIAAN — jadwal mingguan berulang (7 hari, maks 3 rentang/hari,
/// min 1 jam) + tanggal libur per tanggal. Perubahan ketersediaan auto-save
/// per aksi & berlaku segera; booking yang sudah terjadwal tidak terpengaruh.
class VisitSettingsScreen extends StatefulWidget {
  const VisitSettingsScreen({super.key});

  @override
  State<VisitSettingsScreen> createState() => _VisitSettingsScreenState();
}

class _VisitSettingsScreenState extends State<VisitSettingsScreen> {
  static const _hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  bool _accepting = false;
  int _maxActive = 2;
  int _pricePerHour = 10000;
  List<dynamic> _slots = [];
  List<dynamic> _blackouts = [];
  bool _loading = true;
  bool _saving = false;
  final _tarifCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tarifCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await api.ustadzVisitSettings();
      final a = await api.ustadzVisitAvailability();
      if (!mounted) return;
      setState(() {
        _accepting = s?['is_accepting'] == true;
        _maxActive = (s?['max_active_visits'] as num?)?.toInt() ?? 2;
        _pricePerHour = (s?['price_per_hour'] as num?)?.toInt() ?? 10000;
        _tarifCtrl.text = '$_pricePerHour';
        _slots = (a?['slots'] as List? ?? []);
        _blackouts = (a?['blackouts'] as List? ?? []);
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
    final tarif = int.tryParse(_tarifCtrl.text.trim());
    if (tarif == null || tarif < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarif minimal Rp 10.000 / jam')));
      return;
    }
    setState(() => _saving = true);
    try {
      await api.ustadzPutVisitSettings(
          isAccepting: _accepting, maxActiveVisits: _maxActive, pricePerHour: tarif);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _accepting ? 'Tersimpan — Anda menerima pesanan' : 'Tersimpan — tidak menerima pesanan')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- ketersediaan mingguan ----------

  List<Map<String, dynamic>> _slotsOf(int weekday) => _slots
      .where((s) => (s as Map<String, dynamic>)['weekday'] == weekday)
      .cast<Map<String, dynamic>>()
      .toList();

  String _mm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  Future<void> _addSlot(int weekday) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
      helpText: 'Jam mulai — ${_hari[weekday]}',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 1) % 24, minute: 0),
      helpText: 'Jam selesai — ${_hari[weekday]}',
    );
    if (end == null) return;
    final sm = start.hour * 60 + start.minute;
    final em = end.hour * 60 + end.minute;
    if (em - sm < 60) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rentang minimal 1 jam')));
      }
      return;
    }
    if (_slotsOf(weekday).length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Maksimal 3 rentang per hari')));
      }
      return;
    }
    try {
      await api.ustadzAddAvailabilitySlot(weekday: weekday, startMinute: sm, endMinute: em);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menambah (rentang tumpang tindih?)')));
      }
    }
  }

  Future<void> _deleteSlot(int id) async {
    try {
      await api.ustadzDeleteAvailabilitySlot(id);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus')));
      }
    }
  }

  // ---------- tanggal libur ----------

  Future<void> _addBlackout() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Pilih tanggal libur',
    );
    if (d == null || !mounted) return;
    final ymd =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await api.ustadzAddBlackout(ymd);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tanggal libur ditambahkan')));
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menambah libur')));
      }
    }
  }

  Future<void> _deleteBlackout(String date) async {
    try {
      await api.ustadzDeleteBlackout(date);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus')));
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
                // ---------- umum ----------
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
                        const SizedBox(height: 8),
                        TextField(
                          controller: _tarifCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tarif per jam (Rp, min 10.000)',
                            prefixText: 'Rp ',
                            isDense: true,
                          ),
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

                // ---------- ketersediaan mingguan ----------
                Row(
                  children: const [
                    Expanded(
                        child: Text('Ketersediaan Mingguan',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                    'Santri hanya bisa memesan di rentang jam ini. Min 1 jam per rentang, maks 3 per hari. '
                    'Perubahan berlaku segera untuk pesanan baru.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                ...List.generate(7, (w) => _dayCard(w)),
                const SizedBox(height: 20),

                // ---------- tanggal libur ----------
                Row(
                  children: [
                    const Expanded(
                        child: Text('Tanggal Libur',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    TextButton.icon(
                      onPressed: _addBlackout,
                      icon: const Icon(Icons.event_busy, size: 18),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Menimpa jadwal mingguan pada tanggal tersebut — santri tidak bisa memesan.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (_blackouts.isEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('Belum ada tanggal libur.',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _blackouts.map<Widget>((b) {
                      final m = b as Map<String, dynamic>;
                      final date = m['off_date'] as String;
                      return InputChip(
                        avatar: const Icon(Icons.event_busy, size: 16),
                        label: Text(date + (m['note'] != null ? ' • ${m['note']}' : '')),
                        onDeleted: () => _deleteBlackout(date),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _dayCard(int weekday) {
    final rows = _slotsOf(weekday);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_hari[weekday],
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                TextButton.icon(
                  onPressed: () => _addSlot(weekday),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Rentang'),
                ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tidak menerima di hari ini',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ),
              )
            else
              ...rows.map((s) {
                final start = (s['start_minute'] as num?)?.toInt() ?? 0;
                final end = (s['end_minute'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${_mm(start)} – ${_mm(end)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus rentang',
                        onPressed: () => _deleteSlot(s['id'] as int),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
