import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import '../main.dart';
import 'login_screen.dart';
import 'ustadz_wallet_screen.dart';
import 'visit_settings_screen.dart';

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
  List<dynamic> _availSlots = []; // jadwal ketersediaan (subtitle kartu)
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
        // jadwal ketersediaan kunjungan — subtitle kartu Profil
        api.ustadzVisitAvailability().catchError((_) => null),
      ]);
      setState(() {
        _me = results[0];
        _stats = results[1];
        _verified = (results[2] as Map?)?['verified'] == true;
        _walletBalance = results[3] as int;
        _availSlots = (results[4] as Map?)?['slots'] as List? ?? [];
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

                // Jadwal ketersediaan — pintu utama (paling atas, mudah ditemukan)
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event_available, color: AppColors.goldDark),
                    ),
                    title: const Text('Jadwal Ketersediaan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _jadwalRingkas,
                      style: TextStyle(
                        fontSize: 12,
                        color: _availSlots.isEmpty ? AppColors.warning : AppColors.onSurfaceVariant,
                        fontWeight: _availSlots.isEmpty ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const VisitSettingsScreen()));
                      _load();
                    },
                  ),
                ),
                const SizedBox(height: 8),

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

  static const _hariPendek = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _hariPanjang = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  String _jm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}.${(m % 60).toString().padLeft(2, '0')}';

  /// Ringkasan jadwal aktif untuk subtitle kartu Profil.
  /// 0 slot = peringatan; 1 hari = nama panjang; 2–3 = singkatan;
  /// ≥4 hari seragam & penuh 7 hari = "Setiap hari", selain itu "N hari terbuka".
  String get _jadwalRingkas {
    if (_availSlots.isEmpty) return 'Belum diatur — santri belum bisa memesan';
    final byDay = <int, List<String>>{};
    for (final s in _availSlots) {
      final m = s as Map<String, dynamic>;
      final d = (m['weekday'] as num?)?.toInt() ?? -1;
      if (d < 0 || d > 6) continue;
      final sm = (m['start_minute'] as num?)?.toInt() ?? 0;
      final em = (m['end_minute'] as num?)?.toInt() ?? 0;
      byDay.putIfAbsent(d, () => []).add('${_jm(sm)}–${_jm(em)}');
    }
    if (byDay.isEmpty) return 'Belum diatur — santri belum bisa memesan';
    final days = byDay.keys.toList()..sort();
    for (final r in byDay.values) {
      r.sort();
    }
    final rentangSeragam = byDay.values.map((r) => r.join(' & ')).toSet().length == 1;
    final rentang = byDay.values.first.join(' & ');
    if (days.length == 7 && rentangSeragam) return 'Setiap hari $rentang';
    if (days.length >= 4) return '${days.length} hari terbuka';
    if (rentangSeragam) {
      final label = days.length == 1
          ? _hariPanjang[days.first]
          : days.map((d) => _hariPendek[d]).join(' & ');
      return '$label $rentang';
    }
    return days.map((d) => '${_hariPendek[d]} ${byDay[d]!.join(' & ')}').join(', ');
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
