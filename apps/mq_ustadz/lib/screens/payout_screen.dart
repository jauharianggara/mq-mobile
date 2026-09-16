import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';

/// Tarik Dana (W3b) — form self-service ustadz: bank, no. rekening, a.n.,
/// jumlah (+ Tarik Semua), rincian live (saldo, fee, diterima, saldo setelah),
/// lalu riwayat pengajuan. Saldo didebit SEJAK pengajuan (anti tarik dua kali);
/// ditolak admin = dana kembali ke saldo.
class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  static const _banks = [
    'BCA', 'BRI', 'BNI', 'Mandiri', 'BSI', 'Bank Syariah Indonesia',
    'BTN', 'CIMB Niaga', 'Danamon', 'Permata', 'Panin', 'Maybank', 'Lainnya',
  ];

  int _balance = 0;
  int _fee = 6500;
  int _min = 50000;
  List<dynamic> _history = [];
  bool _loading = true;
  bool _submitting = false;

  String _bank = 'BCA';
  final _noCtrl = TextEditingController();
  final _anCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noCtrl.dispose();
    _anCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        api.walletBalance().catchError((_) => 0),
        api.ustadzPayouts().catchError((_) => null),
      ]);
      if (!mounted) return;
      final d = results[1] as Map<String, dynamic>?;
      setState(() {
        _balance = results[0] as int;
        _fee = (d?['fee'] as num?)?.toInt() ?? 6500;
        _min = (d?['min'] as num?)?.toInt() ?? 50000;
        _history = (d?['items'] as List? ?? []);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get _diterima => _amount - _fee;
  bool get _validAmount => _amount >= _min && _amount <= _balance;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_noCtrl.text.trim().isEmpty || _anCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lengkapi nomor rekening dan nama pemilik')));
      return;
    }
    if (!_validAmount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_amount < _min
              ? 'Minimal penarikan Rp ${_rp(_min)}'
              : 'Jumlah melebihi saldo Anda')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final d = await api.ustadzCreatePayout(
          bankName: _bank, accountNo: _noCtrl.text, accountName: _anCtrl.text, amount: _amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pengajuan terkirim — menunggu ACC admin. Dana dikunci dari saldo.')));
      _amountCtrl.clear();
      _load();
    } catch (e) {
      if (!mounted) return;
      final es = e.toString();
      String msg = 'Gagal mengajukan penarikan';
      if (es.contains('minimum')) msg = 'Minimal penarikan Rp ${_rp(_min)}';
      if (es.contains('saldo')) msg = 'Saldo tidak cukup';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarik Dana')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Form
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _bank,
                            items: _banks
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (v) => setState(() => _bank = v ?? 'BCA'),
                            decoration: const InputDecoration(
                                labelText: 'Nama bank', isDense: true),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Nomor rekening', isDense: true),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _anCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                                labelText: 'Rekening a.n. (sesuai buku tabungan)',
                                isDense: true),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Jumlah ditarik (min Rp ${_rp(_min)})',
                              prefixText: 'Rp ',
                              isDense: true,
                              suffixIcon: _amount >= _min && _amount < _balance
                                  ? TextButton(
                                      onPressed: () {
                                        _amountCtrl.text = '$_balance';
                                        setState(() {});
                                      },
                                      child: const Text('Tarik Semua', style: TextStyle(fontSize: 11)),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _summary(),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.outbox_outlined),
                              label: const Text('Ajukan Penarikan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                        'Setelah ACC admin, dana ditransfer ke rekening Anda dalam 1-2 hari kerja. '
                        'Penolakan mengembalikan dana ke saldo.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),

                  // Riwayat
                  const Text('Riwayat Penarikan',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('Belum ada pengajuan penarikan.',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                      ),
                    )
                  else
                    ..._history.map<Widget>((h) {
                      final m = h as Map<String, dynamic>;
                      final status = m['status'] as String? ?? '';
                      final amount = (m['amount'] as num?)?.toInt() ?? 0;
                      final fee = (m['fee'] as num?)?.toInt() ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.outbox_outlined),
                          title: Text('${m['bank_name']} • ${m['bank_account_no']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Diterima Rp ${_rp(amount)} (fee ${_rp(fee)}) • a.n. ${m['bank_account_name']}\n'
                              '${_fmt(m['created_at'])}${m['rejected_reason'] != null ? ' — ${m['rejected_reason']}' : ''}',
                              style: const TextStyle(fontSize: 11)),
                          isThreeLine: true,
                          trailing: StatusBadge(status: status),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _summary() {
    final over = _amount > _balance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _amount > 0
            ? (over ? const Color(0xFFEF4444).withValues(alpha: 0.08) : AppColors.primary.withValues(alpha: 0.08))
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _sumRow('Saldo', 'Rp ${_rp(_balance)}'),
          _sumRow('Fee penarikan', 'Rp ${_rp(_fee)}'),
          _sumRow('Diterima', _amount >= _min && !over ? 'Rp ${_rp(_diterima)}' : '-',
              bold: true),
          _sumRow('Saldo setelah', _amount > 0 && !over ? 'Rp ${_rp(_balance - _amount)}' : '-'),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  String _fmt(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month - 1]} ${d.year}';
  }

  String _rp(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}
