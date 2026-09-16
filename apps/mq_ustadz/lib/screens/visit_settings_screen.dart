import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Pengaturan Panggil Ustadz v2 (W3): status menerima, kapasitas, INFAQ PER JAM,
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
  final _infaqCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _infaqCtrl.dispose();
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
        _infaqCtrl.text = '$_pricePerHour';
        _slots = (a?['slots'] as List? ?? []);
        _blackouts = (a?['blackouts'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Gagal memuat pengaturan'))));
    }
  }

  Future<void> _save() async {
    final infaq = int.tryParse(_infaqCtrl.text.trim());
    if (infaq == null || infaq < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Infaq minimal Rp 10.000 / jam')));
      return;
    }
    setState(() => _saving = true);
    try {
      await api.ustadzPutVisitSettings(
          isAccepting: _accepting, maxActiveVisits: _maxActive, pricePerHour: infaq);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _accepting ? 'Tersimpan — Anda menerima pesanan' : 'Tersimpan — tidak menerima pesanan')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Gagal menyimpan'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Toggle langsung tersimpan (auto-save) — anti-pattern: toggle tanpa auto-save.
  /// Nilai lain dikirim dari state ter-load, bukan field yang mungkin belum disimpan.
  Future<void> _toggleAccepting(bool v) async {
    setState(() => _accepting = v);
    try {
      await api.ustadzPutVisitSettings(
          isAccepting: v, maxActiveVisits: _maxActive, pricePerHour: _pricePerHour);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(v
              ? 'Tersimpan — Anda menerima pesanan baru'
              : 'Tersimpan — santri tidak bisa memesan saat ini')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _accepting = !v);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Gagal menyimpan'))));
    }
  }

  // ---------- ketersediaan mingguan ----------

  List<Map<String, dynamic>> _slotsOf(int weekday) => _slots
      .where((s) => (s as Map<String, dynamic>)['weekday'] == weekday)
      .cast<Map<String, dynamic>>()
      .toList();

  String _mm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  /// API mengirim "HH:MM" (string); toleran juga terhadap menit (num).
  String _fmtJam(dynamic v) {
    if (v is String) return v;
    final m = (v as num?)?.toInt() ?? 0;
    return _mm(m);
  }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiErrorMessage(e, 'Gagal menambah (rentang tumpang tindih?)'))));
      }
    }
  }

  Future<void> _deleteSlot(int id) async {
    try {
      await api.ustadzDeleteAvailabilitySlot(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Gagal menghapus'))));
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Gagal menambah libur'))));
      }
    }
  }

  Future<void> _deleteBlackout(String date) async {
    try {
      await api.ustadzDeleteBlackout(date);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Gagal menghapus'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Ketersediaan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------- umum ----------
                if (!_accepting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Santri tidak bisa memesan Anda saat ini',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: _accepting ? 1.0 : 0.55,
                  duration: const Duration(milliseconds: 200),
                  child: Card(
                    margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Terima pesanan baru',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Santri terdekat bisa menemukan & memesan Anda',
                              style: TextStyle(fontSize: 12)),
                          value: _accepting,
                          onChanged: _toggleAccepting,
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
                          controller: _infaqCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Infaq per jam (Rp, min 10.000)',
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
              ),
                const SizedBox(height: 20),

                // ---------- ketersediaan mingguan ----------
                Row(
                  children: const [
                    Expanded(
                        child: Text('Jam Buka Mingguan',
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
                  label: const Text('Tambah'),
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
                final start = _fmtJam(s['start']);
                final end = _fmtJam(s['end']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$start – $end',
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
