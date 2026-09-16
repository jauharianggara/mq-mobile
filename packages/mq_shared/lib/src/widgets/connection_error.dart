import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Halaman "Tidak Dapat Terhubung" — server tak terjangkau (BUKAN sesi mati).
/// HALAMAN penuh ringan (bukan dialog): ikon + judul + penjelasan + Coba Lagi.
class ConnectionErrorScreen extends StatefulWidget {
  const ConnectionErrorScreen({super.key, this.onRetry});

  /// Dipanggil saat tombol "Coba Lagi" ditekan — biasanya fungsi cek sesi
  /// dari splash (navigasi hasil dilakukan via navigatorKey global).
  final VoidCallback? onRetry;

  @override
  State<ConnectionErrorScreen> createState() => _ConnectionErrorScreenState();
}

class _ConnectionErrorScreenState extends State<ConnectionErrorScreen> {
  bool _retrying = false;

  void _retry() {
    if (_retrying) return;
    setState(() => _retrying = true);
    // beri satu frame agar spinner tampil sebelum pekerjaan async dimulai
    Future.microtask(() => widget.onRetry?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tidak Dapat Terhubung',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Server sedang tidak bisa dihubungi. Periksa koneksi internet Anda, lalu coba lagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _retry,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Coba Lagi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
