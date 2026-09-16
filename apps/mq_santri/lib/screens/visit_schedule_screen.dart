import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import 'visit_status_screen.dart';

/// Buat jadwal kunjungan (W2): langkah bernomor dengan progressive disclosure —
/// 1) tanggal (hanya yang dibuka ustadz) → 2) jam mulai → 3) durasi 1-8 jam.
/// Server-authoritative via /visits/slots; nominal live (infaq × N);
/// buat pesanan + hold slot → lanjut bayar di layar status.
class VisitScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> u;
  final double lat;
  final double lng;
  final int accuracyM;
  final String addressLabel;
  final String? note;

  const VisitScheduleScreen({
    super.key,
    required this.u,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.addressLabel,
    this.note,
  });

  @override
  State<VisitScheduleScreen> createState() => _VisitScheduleScreenState();
}

class _VisitScheduleScreenState extends State<VisitScheduleScreen> {
  static const _hariPendek = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

  int _duration = 1;
  int _selectedDay = 0; // index ke daftar tanggal (0 = hari ini)
  String? _startTime;
  List<String> _slots = [];
  bool _loadingSlots = false;
  final Set<int> _openDays = {}; // tanggal yang punya slot (probe durasi terpilih)
  bool _probing = true;
  bool _creating = false;

  int get _infaq => (widget.u['price_per_hour'] as num?)?.toInt() ?? 0;
  int get _total => _infaq * _duration;

  List<DateTime> get _dates =>
      List.generate(14, (i) => DateTime.now().add(Duration(days: i)));

  @override
  void initState() {
    super.initState();
    _probeOpenDays();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _tglLabel(DateTime d) => '${_hariPendek[d.weekday % 7]} ${d.day} ${_bulan[d.month - 1]}';

  /// Index tanggal yang terbuka (urut) — hanya ini yang tampil sebagai chip.
  List<int> get _openIdx => _openDays.toList()..sort();

  /// Kalender: hanya tanggal yang terbuka yang bisa dipilih.
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dates[_selectedDay.clamp(0, _dates.length - 1)],
      firstDate: first,
      lastDate: first.add(const Duration(days: 13)),
      selectableDayPredicate: (d) {
        final idx = d.difference(first).inDays;
        return idx >= 0 && idx < _dates.length && _openDays.contains(idx);
      },
      helpText: 'Tanggal terbuka ustadz',
    );
    if (picked == null || !mounted) return;
    final idx = DateTime(picked.year, picked.month, picked.day).difference(first).inDays;
    if (idx < 0 || idx >= _dates.length || !_openDays.contains(idx)) return;
    setState(() => _selectedDay = idx);
    _loadSlots();
  }

  /// Probe slot 14 hari ke depan (paralel, hours = durasi terpilih) untuk menandai
  /// tanggal yang bisa dibooking — tanggal libur/tanpa jam terbuka tidak bisa dipilih.
  Future<void> _probeOpenDays() async {
    setState(() => _probing = true);
    final dates = _dates;
    final results = await Future.wait(
      dates.map((d) => api
          .visitSlots(ustadzId: widget.u['ustadz_id'] as int, date: _ymd(d), hours: _duration)
          .catchError((_) => const <String>[])),
    );
    if (!mounted) return;
    final open = <int>{};
    for (var i = 0; i < results.length; i++) {
      if (results[i].isNotEmpty) open.add(i);
    }
    setState(() {
      _openDays
        ..clear()
        ..addAll(open);
      _probing = false;
      // jika tanggal terpilih tak lagi tersedia setelah durasi berubah → geser
      if (!_openDays.contains(_selectedDay) && _openDays.isNotEmpty) {
        _selectedDay = _openDays.first;
        _startTime = null;
        _loadSlots();
      } else if (!_openDays.contains(_selectedDay)) {
        _selectedDay = 0;
        _startTime = null;
        _slots = [];
      }
    });
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _startTime = null;
    });
    try {
      final s = await api.visitSlots(
          ustadzId: widget.u['ustadz_id'] as int, date: _ymd(_dates[_selectedDay]), hours: _duration);
      if (!mounted) return;
      setState(() => _slots = s);
    } catch (_) {
      if (!mounted) return;
      setState(() => _slots = []);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _setDuration(int h) {
    if (h == _duration) return;
    setState(() => _duration = h);
    // ketersediaan bergantung durasi (harus muat dalam rentang) → probe ulang
    _probeOpenDays();
  }

  Future<void> _create() async {
    if (_startTime == null) return;

    // TODO: pakai timestamp server saat backend menyediakannya
    final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
    final schedWib = DateTime(_dates[_selectedDay].year, _dates[_selectedDay].month,
        _dates[_selectedDay].day, int.parse(_startTime!.split(':')[0]));
    final minWib = nowWib.add(const Duration(hours: 2));
    if (schedWib.isBefore(minWib)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Jadwal minimal 2 jam dari sekarang — pilih jam yang lebih siang.')));
      return;
    }

    setState(() => _creating = true);
    try {
      final idem = const Uuid().v4();
      final d = await api.visitCreate(
        ustadzId: widget.u['ustadz_id'] as int,
        date: _ymd(_dates[_selectedDay]),
        startTime: _startTime!,
        durationHours: _duration,
        lat: widget.lat,
        lng: widget.lng,
        accuracyM: widget.accuracyM,
        addressLabel: widget.addressLabel,
        note: widget.note,
        idempotencyKey: idem,
      );
      if (!mounted) return;
      if (d == null) throw Exception();
      final visitId = d['id'] as int;
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VisitStatusScreen(
            visitId: visitId,
            initialInvoiceUrl: (d['invoice_url'] as String?) ?? '',
          ),
        ),
      );
      if (done == true && mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat pesanan. Coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    final cs = Theme.of(context).colorScheme;
    final ringkas = <String>[
      if (!_probing && _openDays.contains(_selectedDay)) _tglLabel(_dates[_selectedDay]),
      if (_startTime != null) _startTime!,
      '${_duration} jam',
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Buat Jadwal — ${u['full_name'] ?? 'Ustadz'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==== Kartu ustadz + ringkasan pilihan ====
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                      child: Text((u['full_name'] as String? ?? 'U')[0].toUpperCase())),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['full_name'] as String? ?? 'Ustadz',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Rp ${_rp(_infaq)} / jam',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        if (ringkas.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(ringkas.join('  •  '),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ================= LANGKAH 1 — TANGGAL =================
          _stepHeader(context, 1, 'Pilih tanggal',
              trailing: IconButton(
                tooltip: 'Buka kalender',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: _probing || _openIdx.isEmpty ? null : _pickDate,
              )),
          const SizedBox(height: 10),
          if (_probing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_openIdx.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(Icons.event_busy, color: Colors.grey),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('Ustadz ini belum membuka jadwal dalam 14 hari ke depan.',
                            style: TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _openIdx.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, k) => _dateChip(context, _openIdx[k]),
              ),
            ),
          if (_openIdx.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Hanya tanggal yang dibuka ustadz.',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),

          // ================= LANGKAH 2 — JAM MULAI =================
          if (!_probing && _openDays.contains(_selectedDay)) ...[
            const SizedBox(height: 20),
            _stepHeader(context, 2, 'Pilih jam mulai'),
            const SizedBox(height: 10),
            if (_loadingSlots)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_slots.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: const [
                      Icon(Icons.event_busy, color: Colors.grey),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text('Tidak ada jam tersedia — pilih tanggal atau durasi lain.',
                              style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map<Widget>((t) {
                  final sel = _startTime == t;
                  return ChoiceChip(
                    label: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                    selected: sel,
                    onSelected: (_) => setState(() => _startTime = t),
                  );
                }).toList(),
              ),
          ],

          // ================= LANGKAH 3 — DURASI =================
          if (_startTime != null) ...[
            const SizedBox(height: 20),
            _stepHeader(context, 3, 'Pilih durasi kunjungan'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(8, (i) {
                final h = i + 1;
                return ChoiceChip(
                  label: Text('$h jam'),
                  selected: _duration == h,
                  onSelected: (_) => _setDuration(h),
                );
              }),
            ),
          ],

          // ================= RINCIAN + BAYAR =================
          if (_startTime != null) ...[
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Tanggal', _tglLabel(_dates[_selectedDay])),
                    _row('Jam mulai', _startTime!),
                    _row('Durasi', '$_duration jam'),
                    const Divider(height: 20),
                    _row('Total', 'Rp ${_rp(_total)}', bold: true),
                    _row('Patokan rumah', widget.addressLabel),
                    if (widget.note != null && widget.note!.isNotEmpty) _row('Catatan', widget.note!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.request_quote_outlined),
              label: Text(_creating ? 'Membuat pesanan…' : 'Lanjut Pembayaran — Rp ${_rp(_total)}'),
            ),
            const SizedBox(height: 8),
            Text(
                'Slot ditahan setelah pesanan dibuat. Belum dibayar saat invoice kedaluarsa → slot lepas otomatis.',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  /// Header langkah: badge nomor + judul tebal.
  Widget _stepHeader(BuildContext context, int no, String title, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
          child: Text('$no',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        if (trailing != null) trailing,
      ],
    );
  }

  /// Chip tanggal kontras-tinggi: hari (kecil) / tanggal (besar) / bulan (kecil).
  Widget _dateChip(BuildContext context, int i) {
    final cs = Theme.of(context).colorScheme;
    final sel = _selectedDay == i;
    final d = _dates[i];
    final labelBawah = i == 0 ? 'Hari ini' : (i == 1 ? 'Besok' : _hariPendek[d.weekday % 7]);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _selectedDay = i);
        _loadSlots();
      },
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? cs.primary.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(labelBawah,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sel ? cs.primary : cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: sel ? cs.primary : cs.onSurface)),
            Text(_bulan[d.month - 1],
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sel ? cs.primary : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
            Expanded(
              child: Text(value,
                  style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
            ),
          ],
        ),
      );

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
