import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../main.dart';
import 'visit_status_screen.dart';

/// Buat jadwal kunjungan (W2): tanggal & jam HANYA dari ketersediaan ustadz
/// (server-authoritative via /visits/slots) → durasi 1-8 jam → nominal live
/// (tarif × N) → buat pesanan + hold slot → lanjut bayar di layar status.
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

  int _duration = 2;
  int _selectedDay = 0; // index ke daftar tanggal (0 = hari ini)
  String? _startTime;
  List<String> _slots = [];
  bool _loadingSlots = false;
  final Set<int> _openDays = {}; // tanggal yang punya slot (probe durasi terpilih)
  bool _probing = true;
  bool _creating = false;

  int get _tarif => (widget.u['price_per_hour'] as num?)?.toInt() ?? 0;
  int get _total => _tarif * _duration;

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
    _loadSlots();
  }

  Future<void> _create() async {
    if (_startTime == null) return;
    setState(() => _creating = true);
    try {
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
        idempotencyKey: const Uuid().v4(),
      );
      if (!mounted) return;
      final visitId = (d?['visit']?['id'] as num?)?.toInt();
      final invoiceUrl = d?['invoice_url'] as String?;
      if (visitId == null) throw 'gagal';
      // tutup seluruh alur (jadwal ← profil ← daftar ustadz) → langsung layar status
      Navigator.of(context)
        ..pop()
        ..pop()
        ..pop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => VisitStatusScreen(visitId: visitId, initialInvoiceUrl: invoiceUrl)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      final es = e.toString();
      String msg = 'Gagal membuat pesanan — coba lagi';
      if (es.contains('409')) msg = 'Slot baru saja diambil orang lain — pilih jam lain';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _probeOpenDays();
      _loadSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    return Scaffold(
      appBar: AppBar(title: Text('Buat Jadwal — ${u['full_name'] ?? 'Ustadz'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(child: Text((u['full_name'] as String? ?? 'U')[0].toUpperCase())),
              title: Text(u['full_name'] as String? ?? 'Ustadz',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Tarif Rp ${_rp(_tarif)} / jam • ${_tglLabel(_dates[_selectedDay])}'
                  '${_startTime != null ? ' • $_startTime' : ''}'),
            ),
          ),
          const SizedBox(height: 20),

          // Durasi
          const Text('Durasi kunjungan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
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
          const SizedBox(height: 20),

          // Tanggal (hanya yang terbuka)
          Row(
            children: [
              const Expanded(
                  child: Text('Pilih tanggal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              if (_probing)
                const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Hanya tanggal yang dibuka ustadz yang tampil (tanggal libur dikecualikan).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          if (_probing)
            const Padding(
              padding: EdgeInsets.all(12),
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
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _openIdx.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, k) {
                  final i = _openIdx[k];
                  final sel = _selectedDay == i;
                  final d = _dates[i];
                  return ChoiceChip(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_tglLabel(d),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(i == 0 ? 'Hari ini' : (i == 1 ? 'Besok' : '${_hariPendek[d.weekday % 7]}'),
                          style: TextStyle(fontSize: 10, color: sel ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                  selected: sel,
                  onSelected: (_) {
                    setState(() => _selectedDay = i);
                    _loadSlots();
                  },
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Jam mulai
          const Text('Pilih jam mulai', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Slot yang sedang di-booking orang lain otomatis hilang (ditahan server).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_openDays.contains(_selectedDay))
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(Icons.event_busy, color: Colors.grey),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('Tidak ada jadwal terbuka di tanggal ini.',
                            style: TextStyle(fontSize: 13))),
                  ],
                ),
              ),
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
                        child: Text(
                            'Semua jam terbuka sudah habis untuk durasi ini — coba durasi lebih pendek atau tanggal lain.',
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
          const SizedBox(height: 20),

          // Rincian tagihan
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Tarif', 'Rp ${_rp(_tarif)} / jam'),
                  _row('Durasi', '$_duration jam ${_startTime ?? "-"}'),
                  const Divider(height: 20),
                  _row('Total', 'Rp ${_rp(_total)}', bold: true),
                  _row('Patokan rumah', widget.addressLabel),
                  if (widget.note != null && widget.note!.isNotEmpty) _row('Catatan', widget.note!),
                  const SizedBox(height: 4),
                  const Text(
                      'Slot ditahan setelah pesanan dibuat. Belum dibayar saat invoice kedaluarsa → slot lepas otomatis.',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _creating || _startTime == null ? null : _create,
            icon: _creating
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.request_quote_outlined),
            label: Text(_creating ? 'Membuat pesanan…' : 'Lanjut Pembayaran — Rp ${_rp(_total)}'),
          ),
          const SizedBox(height: 24),
        ],
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
