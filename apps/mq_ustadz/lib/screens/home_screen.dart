import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import 'setoran_screen.dart';
import 'tanya_screen.dart';

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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await api.ustadzHome();
      setState(() { _data = d; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Gagal memuat'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _data?['memorization_queue']?['pending'] ?? 0;
    final inReview = _data?['memorization_queue']?['in_review_mine'] ?? 0;
    final qOpen = _data?['questions']?['open'] ?? 0;
    final oldest = _data?['questions']?['oldest'] as Map<String, dynamic>?;
    final slaLevel = oldest?['sla_level'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_data?['greeting'] ?? 'MQ Ustadz', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
                      Text(
                        '${_data?['greeting']}, ${_data?['full_name'] ?? 'Ustadz'}!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Setoran queue card (tap → Setoran tab)
                      _bigCard(
                        icon: Icons.fact_check,
                        iconColor: pending > 0 ? AppColors.warning : AppColors.success,
                        title: 'Setoran Menunggu Review',
                        subtitle: pending > 0
                            ? '$pending setoran menunggu'
                            : inReview > 0 ? '$inReview sedang direview' : 'Antrean kosong ✓',
                        count: pending + inReview,
                        onTap: () => _navigateTo(1),
                      ),
                      const SizedBox(height: 12),

                      // Questions card (tap → Tanya tab)
                      _bigCard(
                        icon: Icons.question_answer,
                        iconColor: qOpen > 0 ? _slaColor(slaLevel) : AppColors.success,
                        title: 'Pertanyaan Belum Dijawab',
                        subtitle: qOpen > 0
                            ? (oldest != null
                                ? '${oldest['title']} · ${oldest['oldest_hours']} jam lalu'
                                : '$qOpen pertanyaan')
                            : 'Semua terjawab ✓',
                        count: qOpen,
                        onTap: () => _navigateTo(2),
                      ),
                      const SizedBox(height: 12),

                      // Availability
                      Card(
                        child: SwitchListTile(
                          value: _data?['availability']?['is_accepting_questions'] ?? false,
                          onChanged: null, // read-only di Home (edit di Profil)
                          title: const Text('Menerima Pertanyaan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Maks. ${_data?['availability']?['max_active_questions'] ?? 0} pertanyaan aktif',
                            style: const TextStyle(fontSize: 11),
                          ),
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notif
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _data?['notification_unread'] > 0 ? Icons.notifications_active : Icons.notifications_none,
                            color: _data?['notification_unread'] > 0 ? AppColors.warning : Colors.grey,
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

  void _navigateTo(int index) {
    // Navigate via shell — use DefaultTabController or callback
    // For simplicity, navigate directly
    Navigator.push(context, MaterialPageRoute(builder: (_) => index == 1 ? const SetoranScreen() : const TanyaScreen()));
  }

  Color _slaColor(String? level) {
    switch (level) {
      case 'critical': return AppColors.error;
      case 'warning': return AppColors.warning;
      default: return AppColors.info;
    }
  }

  Widget _bigCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int count,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
