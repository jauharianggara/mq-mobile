import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import '../main.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'data_saya_screen.dart';
import 'wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await api.me();
      setState(() => _user = me);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await api.logout(); // server mencabut sesi + token lokal dibersihkan
    await MqSessionStore.clear(); // deterministik: hanya sesi, preferensi lain aman
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // avatar + tombol edit foto (upload presign → PATCH /me)
                Semantics(
                  label: 'Foto profil — ketuk untuk ganti',
                  button: true,
                  excludeSemantics: true,
                  child: Center(
                  child: GestureDetector(
                    onTap: () => showAvatarPicker(
                      context, api,
                      hasPhoto: ((_user?['photo_url'] ?? '') as String).isNotEmpty,
                      onChanged: () { _load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil diperbarui'))); },
                    ),
                    child: Stack(
                    children: [
                      MqAvatar(
                        photoUrl: _user?['photo_url'],
                        name: _user?['full_name'] ?? _user?['email'],
                        radius: 48,
                      ),
                      Positioned(
                          right: 0, bottom: 0,
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  ),
                ),
                ),
                const SizedBox(height: 12),
                Text(
                  _user?['full_name'] ?? 'Belum diisi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _user?['email'] ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                // status akun — konteks akun, bukan campaign: ACTIVE → Aktif
                Center(child: StatusBadge(
                  status: _user?['status'] ?? 'ACTIVE',
                  label: {
                    'ACTIVE': 'Aktif',
                    'PENDING_VERIFICATION': 'Belum Verifikasi Email',
                    'SUSPENDED': 'Ditangguhkan',
                    'DELETED': 'Terhapus',
                  }[_user?['status'] as String?],
                )),
                const SizedBox(height: 24),
                _tile(Icons.badge_outlined, 'Data Saya', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DataSayaScreen()));
                }),
                _tile(Icons.account_balance_wallet_outlined, 'Deposit', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                }),
                _tile(Icons.notifications_outlined, 'Notifikasi', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                }),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
