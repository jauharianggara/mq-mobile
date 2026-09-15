import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Offline detection — tampilkan banner merah saat koneksi hilang.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _offline = false;
  Timer? _checker;

  @override
  void initState() {
    super.initState();
    _startChecking();
  }

  @override
  void dispose() {
    _checker?.cancel();
    super.dispose();
  }

  void _startChecking() {
    _checker = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final result = await InternetAddress.lookup('mq-api.jagodigital.online');
        final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        if (mounted && _offline == online) {
          setState(() => _offline = !online);
        }
      } catch (_) {
        if (mounted && !_offline) setState(() => _offline = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_offline)
          Material(
            color: Colors.red.shade600,
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Tidak ada koneksi — periksa internet Anda',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Force-update screen non-dismissible.
class ForceUpdateScreen extends StatelessWidget {
  final String? url;
  const ForceUpdateScreen({super.key, this.url});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update, size: 40, color: Colors.orange),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pembaruan Tersedia',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aplikasi perlu diperbarui untuk melanjutkan.\nVersi terbaru berisi perbaikan penting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (url != null) {
                        // TODO: launch URL
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Perbarui Sekarang', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Versi minimum diperlukan',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
