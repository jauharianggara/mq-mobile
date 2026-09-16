import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import 'visit_chat_screen.dart';

/// Status pesanan: timeline + bayar (invoice Xendit) + polling + cancel + chat + review.
class VisitStatusScreen extends StatefulWidget {
  final int visitId;
  final String? initialInvoiceUrl;

  const VisitStatusScreen({super.key, required this.visitId, this.initialInvoiceUrl});

  @override
  State<VisitStatusScreen> createState() => _VisitStatusScreenState();
}

class _VisitStatusScreenState extends State<VisitStatusScreen> {
  Map<String, dynamic>? _v;
  bool _loading = true;
  String? _error;
  Timer? _poll;
  int _saldo = -1; // -1 = belum termuat
  bool _payingDeposit = false;
  // form review inline (bukan popup)
  int _rating = 5;
  final _reviewCtrl = TextEditingController();
  bool _showReviewForm = false;
  bool _sendingReview = false;

  static const _flow = [
    'REQUESTED',
    'WAITING_CONFIRM',
    'CONFIRMED',
    'COMPLETED',
    'REVIEWED',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await api.visitDetail(widget.visitId);
      if (!mounted) return;
      setState(() {
        _v = d;
        _loading = false;
        _error = null;
      });
      _schedulePoll(d?['status'] as String?);
      // saldo utk tombol bayar deposit (hanya perlu saat REQUESTED)
      if (d?['status'] == 'REQUESTED' && _saldo < 0) {
        try {
          final b = await api.walletBalance();
          if (mounted) setState(() => _saldo = b);
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat pesanan.';
      });
    }
  }

  void _schedulePoll(String? status) {
    _poll?.cancel();
    if (status == 'REQUESTED' || status == 'WAITING_CONFIRM') {
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    }
  }

  Future<void> _pay() async {
    try {
      final d = await api.visitPay(widget.visitId);
      final url = d?['invoice_url'] as String?;
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invoice belum tersedia — coba beberapa saat lagi')));
        return;
      }
      if (url.startsWith('mock://')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('MODE DEV: invoice mock — pembayaran disimulasikan dari server dev')));
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka halaman bayar')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuat invoice')));
      }
    }
  }

  /// Bayar langsung dari deposit (saldo) — uang tidak keluar aplikasi.
  Future<void> _payDeposit() async {
    setState(() => _payingDeposit = true);
    try {
      final d = await api.visitPayDeposit(widget.visitId);
      if (!mounted) return;
      final sisa = (d?['balance'] as num?)?.toInt();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pembayaran berhasil${sisa != null ? ' — sisa deposit Rp ${_rp(sisa)}' : ''}')));
      _saldo = -1;
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pembayaran deposit gagal / saldo tidak cukup')));
      }
    } finally {
      if (mounted) setState(() => _payingDeposit = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text('Pembatalan ≥2 jam sebelum jadwal: dana kembali penuh ke deposit Anda.\n'
            '<2 jam: dana menjadi kompensasi ustadz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.visitCancel(widget.visitId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membatalkan')));
      }
    }
  }

  Future<void> _submitReview() async {
    setState(() => _sendingReview = true);
    try {
      await api.visitSubmitReview(widget.visitId, rating: _rating, comment: _reviewCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Terima kasih! Penilaian tampil setelah ustadz juga menilai (adil dua arah).')));
      }
      setState(() => _showReviewForm = false);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim penilaian')));
      }
    } finally {
      if (mounted) setState(() => _sendingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: EmptyState(icon: Icons.error_outline, title: _error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Kunjungan ${v?['duration_hours'] ?? '-'} jam',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                                    ),
                                  ),
                                  StatusBadge(status: v?['status'] ?? ''),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${v?['ustadz']?['full_name'] ?? 'Ustadz'} • Rp ${_rp(v?['price_total'])}'),
                              const SizedBox(height: 12),
                              _timeline(v?['status'] as String? ?? ''),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _infoCard(v),
                      const SizedBox(height: 16),
                      ..._actions(v),
                      if (_showReviewForm && v?['status'] == 'COMPLETED') ...[
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          color: const Color(0xFFC9A227).withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Penilaian Anda',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Privat hingga ustadz juga menilai (adil dua arah).',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (i) {
                                    return IconButton(
                                      onPressed: () => setState(() => _rating = i + 1),
                                      icon: Icon(
                                          i < _rating ? Icons.star : Icons.star_border,
                                          color: const Color(0xFFC9A227),
                                          size: 34),
                                    );
                                  }),
                                ),
                                TextField(
                                  controller: _reviewCtrl,
                                  decoration: const InputDecoration(
                                      hintText: 'Catatan (opsional)', isDense: true),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _sendingReview ? null : _submitReview,
                                    child: Text(_sendingReview ? 'Mengirim…' : 'Kirim Penilaian'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _timeline(String status) {
    final idx = _flow.indexOf(status);
    final failed = ['DECLINED', 'CANCELED', 'PAYMENT_EXPIRED'].contains(status);
    if (failed) {
      final label = status == 'CANCELED'
          ? 'Dibatalkan'
          : status == 'DECLINED'
              ? 'Ditolak ustadz — dana kembali'
              : 'Pembayaran kedaluwarsa';
      return Row(children: [
        const Icon(Icons.cancel, color: Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
      ]);
    }
    return Column(
      children: [
        for (var i = 0; i < _flow.length; i++)
          Row(
            children: [
              Column(children: [
                Icon(
                  i < idx
                      ? Icons.check_circle
                      : i == idx
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                  color: i <= idx ? const Color(0xFF16A34A) : Colors.grey,
                  size: 20,
                ),
                if (i < _flow.length - 1)
                  Container(width: 2, height: 16, color: i < idx ? const Color(0xFF16A34A) : Colors.grey.shade300),
              ]),
              const SizedBox(width: 10),
              Text(_flowLabel(_flow[i]),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == idx ? FontWeight.w700 : FontWeight.normal,
                      color: i <= idx ? null : Colors.grey)),
            ],
          ),
      ],
    );
  }

  String _flowLabel(String s) => {
        'REQUESTED': 'Menunggu pembayaran',
        'WAITING_CONFIRM': 'Menunggu konfirmasi ustadz',
        'CONFIRMED': 'Dikonfirmasi — kunjungan terjadwal',
        'COMPLETED': 'Kunjungan selesai',
        'REVIEWED': 'Selesai & saling dinilai',
      }[s] ??
      s;

  Widget _infoCard(Map<String, dynamic>? v) {
    if (v == null) return const SizedBox.shrink();
    final pay = v['payment'] as Map<String, dynamic>?;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(Icons.event, 'Jadwal', _fmt(v['scheduled_at'])),
            _row(Icons.timelapse, 'Durasi', '${v['duration_hours'] ?? '-'} jam'),
            _row(Icons.payments_outlined, 'Infaq', 'Rp ${_rp(v['price_per_hour'])}/jam'),
            _row(Icons.place_outlined, 'Patokan', v['address_label'] ?? '-'),
            if ((v['note'] as String?)?.isNotEmpty == true) _row(Icons.notes, 'Catatan', v['note']),
            if (pay != null) _row(Icons.payment_outlined, 'Pembayaran', pay['status'] ?? '-'),
            if (v['status'] == 'CONFIRMED' && v['ustadz']?['phone'] != null)
              _row(Icons.call_outlined, 'WhatsApp/Telp ustadz', v['ustadz']['phone']),
            if (v['cancel_reason'] != null) _row(Icons.info_outline, 'Ket.', v['cancel_reason']),
            if (v['decline_reason'] != null) _row(Icons.info_outline, 'Alasan tolak', v['decline_reason']),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(Map<String, dynamic>? v) {
    if (v == null) return [];
    final s = v['status'] as String;
    switch (s) {
      case 'REQUESTED':
        final total = (v['price_total'] as num?)?.toInt() ?? 0;
        final saldoCukup = _saldo >= total;
        return [
          if (saldoCukup) ...[
            FilledButton.icon(
              onPressed: _payingDeposit ? null : _payDeposit,
              icon: _payingDeposit
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.account_balance_wallet),
              label: Text('Bayar pakai Deposit — Rp ${_rp(total)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pay,
              icon: const Icon(Icons.qr_code),
              label: const Text('Bayar QRIS / VA / e-wallet'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _pay,
              icon: const Icon(Icons.request_quote),
              label: Text('Bayar Rp ${_rp(total)} (QRIS/VA/e-wallet)'),
            ),
            if (_saldo >= 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Deposit Anda Rp ${_rp(_saldo)} — kurang dari tagihan. Top-up di halaman Deposit (Profil) agar bisa bayar langsung.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _cancel, child: const Text('Batalkan pesanan')),
        ];
      case 'WAITING_CONFIRM':
        return [
          const Center(child: Text('Menunggu ustadz mengonfirmasi…', style: TextStyle(fontSize: 13))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _cancel, child: const Text('Batalkan pesanan')),
        ];
      case 'CONFIRMED':
        return [
          FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VisitChatScreen(visitId: widget.visitId))),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat dengan Ustadz'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _cancel, child: const Text('Batalkan pesanan')),
        ];
      case 'COMPLETED':
        return [
          FilledButton.icon(
            onPressed: () => setState(() => _showReviewForm = !_showReviewForm),
            icon: const Icon(Icons.star),
            label: const Text('Beri Penilaian untuk Ustadz'),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _row(IconData i, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  String _fmt(String? iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.year} • '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _rp(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }
}
