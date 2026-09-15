import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _availability;
  Map<String, dynamic>? _stats;
  List<dynamic>? _specializations;
  List<dynamic>? _categories;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.me(),
        api.get('/me/ustadz/availability'),
        api.get('/ustadz/me/stats'),
        api.get('/me/ustadz/specializations'),
        api.get('/question-categories').catchError((_) => null),
      ]);
      setState(() {
        _me = results[0];
        _availability = results[1];
        _stats = results[2];
        _specializations = results[3] as List? ?? [];
        _categories = results[4] as List? ?? [];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _toggleAccepting(bool value) async {
    try {
      await api.put('/me/ustadz/availability', data: {
        'is_accepting_questions': value,
        'max_active_questions': _availability?['max_active_questions'] ?? 10,
      });
      setState(() => _availability?['is_accepting_questions'] = value);
    } catch (_) {}
  }

  Future<void> _editMaxQuestions() async {
    final ctrl = TextEditingController(text: _availability?['max_active_questions']?.toString() ?? '10');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maksimal Pertanyaan Aktif'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Jumlah (1-100)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == null || result < 1 || result > 100) return;
    try {
      await api.put('/me/ustadz/availability', data: {
        'is_accepting_questions': _availability?['is_accepting_questions'] ?? true,
        'max_active_questions': result,
      });
      setState(() => _availability?['max_active_questions'] = result);
    } catch (_) {}
  }

  Future<void> _editSpecializations() async {
    final selected = (_specializations ?? []).map((s) => s['category_id'] as int).toSet();

    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Spesialisasi'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: (_categories ?? []).map((c) {
                final id = c['id'] as int;
                return CheckboxListTile(
                  value: selected.contains(id),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) { selected.add(id); } else { selected.remove(id); }
                    });
                  },
                  title: Text(c['name'], style: const TextStyle(fontSize: 14)),
                  dense: true,
                  activeColor: AppColors.primary,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    try {
      await api.put('/me/ustadz/specializations', data: {'category_ids': result.toList()});
      _load();
    } catch (_) {}
  }

  Future<void> _logout() async {
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
                if (_availability?['verified'] == true)
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

                // Availability
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _availability?['is_accepting_questions'] ?? false,
                        onChanged: _toggleAccepting,
                        title: const Text('Menerima Pertanyaan Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _availability?['is_accepting_questions'] == true
                              ? 'Pertanyaan baru akan ditugaskan ke saya'
                              : 'Tidak menerima pertanyaan baru',
                          style: const TextStyle(fontSize: 11),
                        ),
                        activeColor: AppColors.primary,
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      ListTile(
                        title: const Text('Maksimal Pertanyaan Aktif', style: TextStyle(fontSize: 14)),
                        trailing: Text(
                          '${_availability?['max_active_questions'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        onTap: _editMaxQuestions,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Specializations
                Card(
                  child: ListTile(
                    title: const Text('Spesialisasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: (_specializations ?? []).isEmpty
                        ? const Text('Belum diatur — pertanyaan tidak akan diarahkan ke Anda', style: TextStyle(fontSize: 11))
                        : Text(
                            (_specializations!).map((s) => s['name']).join(', '),
                            style: const TextStyle(fontSize: 12),
                          ),
                    trailing: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                    onTap: _editSpecializations,
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
