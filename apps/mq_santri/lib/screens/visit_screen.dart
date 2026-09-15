import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'visit_create_screen.dart';
import 'visit_status_screen.dart';

/// Tab "Pesan" — daftar pesanan kunjungan ustadz + entry point pesan baru.
class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await api.visitList();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat pesanan. Tarik ke bawah untuk coba lagi.';
        _loading = false;
      });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Ustadz'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final done = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const VisitCreateScreen()));
          if (done == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Pesan Ustadz'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    EmptyState(icon: Icons.error_outline, message: _error!),
                  ])
                : _items.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 100),
                        EmptyState(
                          icon: Icons.two_wheeler_outlined,
                          title: 'Belum ada pesanan',
                          subtitle: 'Pesan ustadz terdekat untuk tahsin,\nmurajaah, tahlil, atau konsultasi.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final v = _items[i] as Map<String, dynamic>;
                          final active = ['REQUESTED', 'WAITING_CONFIRM', 'CONFIRMED'].contains(v['status']);
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => VisitStatusScreen(visitId: v['id'] as int)));
                                _load();
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${v['service_name'] ?? 'Kunjungan'} — ${v['ustadz']?['full_name'] ?? 'Ustadz'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: v['status'] as String? ?? ''),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${_fmtDate(v['scheduled_at'] as String?)}  •  Rp ${_fmtRp(v['price_amount'])}'
                                  '${active ? '  •  ketuk utk detail' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: active
                                  ? const Icon(Icons.chevron_right)
                                  : v['status'] == 'COMPLETED'
                                      ? const Icon(Icons.star_outline, color: Color(0xFFC9A227))
                                      : null,
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  String _fmtRp(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
