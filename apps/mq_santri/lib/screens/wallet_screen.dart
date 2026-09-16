import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

/// Halaman Deposit (W2): saldo, top-up via invoice Xendit, kartu persetujuan
/// penyesuaian saldo dari admin (dua langkah), dan riwayat mutasi.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _balance = 0;
  List<dynamic> _adjustments = [];
  List<dynamic> _tx = [];
  bool _loading = true;
  bool _toppingUp = false;
  final _amountCtrl = TextEditingController();

  static const _quickAmounts = [20000, 50000, 100000, 250000, 500000];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        api.walletBalance().catchError((_) => 0),
        api.myWalletAdjustments().catchError((_) => const <dynamic>[]),
        api.walletTransactions().then((p) => p.items).catchError((_) => const <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as int;
        _adjustments = results[1] as List<dynamic>;
        _tx = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _topup(int amount) async {
    setState(() => _toppingUp = true);
    try {
      final d = await api.walletTopup(amount);
      final url = d?['invoice_url'] as String?;
      if (!mounted) return;
      if (url != null && url.isNotEmpty && !url.startsWith('mock://')) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Selesaikan pembayaran di halaman invoice — saldo masuk otomatis setelah lunas')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MODE DEV: invoice mock — top-up disimulasikan dari server dev')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal membuat invoice top-up')));
      }
    } finally {
      if (mounted) setState(() => _toppingUp = false);
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
      appBar: AppBar(title: const Text('Deposit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Saldo
                  Card(
                    margin: EdgeInsets.zero,
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saldo Deposit',
                              style: TextStyle(fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 6),
                          Text('Rp ${_rp(_balance)}',
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          const Text(
                              'Dipakai membayar pesanan panggil ustadz. Semua pengembalian dana masuk ke sini.',
                              style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),

                  // Kartu persetujuan penyesuaian (dua langkah)
                  ...pending.map<Widget>((p) {
                    final a = p as Map<String, dynamic>;
                    final amount = (a['amount'] as num?)?.toInt() ?? 0;
                    final plus = amount > 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFFC9A227).withValues(alpha: 0.10),
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

                  // Top-up
                  const Text('Top-Up Deposit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Via QRIS / VA / e-wallet (Xendit) — min Rp 10.000.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts
                        .map((n) => ActionChip(
                              label: Text('Rp ${_rp(n)}'),
                              onPressed: _toppingUp ? null : () => _topup(n),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Nominal lain (Rp)', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _toppingUp ? null : _submitCustom,
                        icon: _toppingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_card),
                        label: const Text('Top-Up'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Riwayat mutasi
                  const Text('Riwayat Mutasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_tx.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('Belum ada transaksi.',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                      ),
                    )
                  else
                    ..._tx.map<Widget>((t) {
                      final m = t as Map<String, dynamic>;
                      return _txTile(m);
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _submitCustom() {
    final n = int.tryParse(_amountCtrl.text.trim());
    if (n == null || n < 10000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Minimal top-up Rp 10.000')));
      return;
    }
    _topup(n);
  }

  Widget _txTile(Map<String, dynamic> m) {
    final type = m['tx_type'] as String? ?? '';
    final amount = (m['amount'] as num?)?.toInt() ?? 0;
    final after = (m['balance_after'] as num?)?.toInt() ?? 0;

    const label = {
      'TOPUP': 'Top-up deposit',
      'PAYMENT': 'Bayar pesanan ustadz',
      'REFUND': 'Pengembalian dana',
      'EARNING': 'Penghasilan kunjungan',
      'PAYOUT': 'Penarikan dana',
      'ADJUST': 'Penyesuaian saldo',
    };
    const credit = {'TOPUP', 'REFUND', 'EARNING'};
    final isCredit = credit.contains(type);
    final sub = m['subject_type'] != null ? ' • ${m['subject_type']}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          type == 'TOPUP'
              ? Icons.add_card
              : type == 'PAYMENT'
                  ? Icons.request_quote_outlined
                  : type == 'REFUND'
                      ? Icons.replay
                      : type == 'EARNING'
                          ? Icons.work_outline
                          : type == 'PAYOUT'
                              ? Icons.outbox_outlined
                              : Icons.tune,
          color: isCredit ? const Color(0xFF16A34A) : Theme.of(context).hintColor,
        ),
        title: Text('${label[type] ?? type}$sub',
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
  }

  String _fmt(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month - 1]} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
