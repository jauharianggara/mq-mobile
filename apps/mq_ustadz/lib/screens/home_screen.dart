import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'khatmil_ustadz_screen.dart';
import 'visit_incoming_screen.dart';

/// Home ustadz — kartu navigasi ke Kunjungan & Khatmil (monitoring + penugasan).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _assignPending = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await api.ustadzHome();
      final k = await api.ustadzKhatmilPendingCount().catchError((_) => 0);
      if (!mounted) return;
      setState(() {
        _data = d;
        _assignPending = k;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _data?['notification_unread'] ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_data?['greeting'] ?? 'MQ Ustadz',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${_data?['greeting'] ?? ''}, ${_data?['full_name'] ?? 'Ustadz'}!',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _navCard(
                    context,
                    icon: Icons.people,
                    title: 'Khatmil',
                    subtitle: _assignPending > 0
                        ? '$_assignPending penugasan menunggu ACC'
                        : 'Pantau progres khatmil & kelompok binaan',
                    badge: _assignPending > 0 ? '$_assignPending' : null,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const KhatmilUstadzScreen())),
                  ),
                  const SizedBox(height: 12),
                  _navCard(
                    context,
                    icon: Icons.two_wheeler,
                    title: 'Pesan',
                    subtitle: 'Permintaan kunjungan & jadwal terjadwal',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const VisitIncomingScreen())),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        unread > 0
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: unread > 0
                            ? AppColors.warning
                            : Colors.grey,
                      ),
                      title: const Text('Notifikasi', style: TextStyle(fontSize: 14)),
                      trailing: Text('${_data?['notification_unread'] ?? 0}'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _navCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: badge != null
            ? Badge(label: Text(badge))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
