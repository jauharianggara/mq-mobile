import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import '../main.dart';
import 'login_screen.dart';
import 'ustadz_wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _stats;
  bool _verified = false;
  int _walletBalance = -1; // -1 = belum termuat
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.me(),
        api.get('/ustadz/me/stats'),
        // hanya untuk badge Terverifikasi (flag verified_at ustadz_profiles)
        api.get('/me/ustadz/availability').catchError((_) => null),
        api.walletBalance().catchError((_) => -1),
      ]);
      setState(() {
        _me = results[0];
        _stats = results[1];
        _verified = (results[2] as Map?)?['verified'] == true;
        _walletBalance = results[3] as int;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _logout() async {
    await api.logout(); // server mencabut sesi + token lokal dibersihkan
    await MqSessionStore.clear(); // deterministik: hanya sesi, preferensi lain aman
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Ustadz')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar + name
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  child: Text(
                    (_me?['full_name'] ?? _me?['email'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32, color: AppColors.gold, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _me?['full_name'] ?? 'Ustadz',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _me?['email'] ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                if (_verified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Terverifikasi', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Saldo penghasilan kunjungan
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                    ),
                    title: const Text('Saldo Penghasilan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: _walletBalance < 0
                        ? null
                        : Text('Rp ${_walletBalance.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const UstadzWalletScreen()));
                      _load();
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Stats
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Statistik', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem('Review', '${_stats?['total_reviewed'] ?? 0}'),
                            _statItem('Menunggu', '${_stats?['queue_pending_global'] ?? 0}'),
                            _statItem('Rata² (mnt)', _stats?['avg_review_minutes'] != null ? '${_stats!['avg_review_minutes'].round()}' : '—'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}
