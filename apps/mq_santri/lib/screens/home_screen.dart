import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await api.santriHome();
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _data?['greeting'] ?? 'MQ Santri',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
              _load(); // refresh badge setelah balik
            },
            icon: ((_data?['notification_unread'] ?? 0) > 0)
                ? Badge(
                    label: Text('${_data!['notification_unread']}'),
                    child: const Icon(Icons.notifications_outlined, color: AppColors.onPrimary),
                  )
                : const Icon(Icons.notifications_outlined, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.wifi_off, message: _error!, actionLabel: 'Coba Lagi', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Sapaan + nama
                      Text(
                        '${_data?['greeting']}, ${_data?['full_name'] ?? 'Santri'}!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // KPI Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.6,
                        children: [
                          KpiCard(
                            label: 'Notifikasi',
                            value: '${_data?['notification_unread'] ?? 0}',
                            icon: Icons.notifications_active_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Last Read
                      if (_data?['last_read'] != null) ...[
                        _sectionTitle('Terakhir Dibaca'),
                        Card(
                          child: ListTile(
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.bookmark, color: AppColors.primary),
                            ),
                            title: Text(
                              '${_data!['last_read']!['surah_name']} : ${_data!['last_read']!['ayah_number']}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('Juz ${_data!['last_read']!['juz']} · Hal. ${_data!['last_read']!['page']}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: navigate ke Quran reader di ayat ini
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Khatmil aktif
                      if ((_data?['khatmil'] as List?)?.isNotEmpty == true) ...[
                        _sectionTitle('Khatmil Aktif'),
                        ...(_data!['khatmil'] as List).map<Widget>((k) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                              child: Text('J${k['juz']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                            ),
                            title: Text(k['campaign_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('Juz ${k['juz']} · ${k['pages_read']} hal · ${k['minutes_read']} mnt'),
                            trailing: StatusBadge(status: k['status']),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
