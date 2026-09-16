import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Saldo Penghasilan ustadz (W3): hasil kunjungan selesai masuk otomatis (EARNING).
/// Read-only — penarikan via pengajuan (menyusul); penyesuaian admin butuh ACC di sini.
class UstadzWalletScreen extends StatefulWidget {
  const UstadzWalletScreen({super.key});

  @override
  State<UstadzWalletScreen> createState() => _UstadzWalletScreenState();
}

class _UstadzWalletScreenState extends State<UstadzWalletScreen> {
  int _balance = 0;
  List<dynamic> _tx = [];
  List<dynamic> _adjustments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        api.walletBalance().catchError((_) => 0),
        api.walletTransactions().then((p) => p.items).catchError((_) => const <dynamic>[]),
        api.myWalletAdjustments().catchError((_) => const <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as int;
        _tx = results[1] as List<dynamic>;
        _adjustments = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _respondAdjustment(int id, bool accept) async {
    try {
      if (accept) {
        await api.acceptWalletAdjustment(id);
      } else {
        await api.rejectWalletAdjustment(id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept ? 'Penyesuaian disetujui — saldo diperbarui' : 'Penyesuaian ditolak')));
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal memproses penyesuaian')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _adjustments
        .where((a) => (a as Map<String, dynamic>)['status'] == 'PENDING')
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Saldo Penghasilan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saldo Penghasilan',
                              style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 6),
                          Text('Rp ${_rp(_balance)}',
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          const Text(
                              'Masuk otomatis setiap kunjungan ditandai selesai (setelah biaya platform).',
                              style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),

                  // kartu persetujuan penyesuaian admin
                  ...pending.map<Widget>((p) {
                    final a = p as Map<String, dynamic>;
                    final amount = (a['amount'] as num?)?.toInt() ?? 0;
                    final plus = amount > 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: AppColors.gold.withValues(alpha: 0.10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.admin_panel_settings_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Penyesuaian saldo dari admin',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  Text(
                                    '${plus ? '+' : ''}Rp ${_rp(amount)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: plus ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Alasan: ${a['reason'] ?? '-'}',
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              const Text('Saldo berubah hanya setelah Anda setuju.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _respondAdjustment(a['id'] as int, false),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _respondAdjustment(a['id'] as int, true),
                                      child: const Text('Setuju'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                  const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_tx.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('Belum ada penghasilan. Selesaikan kunjungan untuk mulai menghasil.',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                      ),
                    )
                  else
                    ..._tx.map<Widget>((t) {
                      final m = t as Map<String, dynamic>;
                      final type = m['tx_type'] as String? ?? '';
                      final amount = (m['amount'] as num?)?.toInt() ?? 0;
                      final after = (m['balance_after'] as num?)?.toInt() ?? 0;
                      const label = {
                        'EARNING': 'Penghasilan kunjungan',
                        'TOPUP': 'Top-up',
                        'PAYMENT': 'Pembayaran',
                        'REFUND': 'Pengembalian dana',
                        'PAYOUT': 'Penarikan dana',
                        'ADJUST': 'Penyesuaian saldo',
                      };
                      const credit = {'EARNING', 'REFUND', 'TOPUP'};
                      final isCredit = credit.contains(type);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            type == 'EARNING'
                                ? Icons.work_outline
                                : type == 'PAYOUT'
                                    ? Icons.outbox_outlined
                                    : Icons.receipt_long_outlined,
                            color: isCredit ? const Color(0xFF16A34A) : Theme.of(context).hintColor,
                          ),
                          title: Text(label[type] ?? type,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${_fmt(m['created_at'])} • saldo jadi Rp ${_rp(after)}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            '${isCredit ? '+' : '-'}Rp ${_rp(amount)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String _fmt(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month - 1]} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
