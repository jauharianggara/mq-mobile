import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

final MqApi api = MqApi();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MqSantriApp());
}

class MqSantriApp extends StatelessWidget {
  const MqSantriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQ Santri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // cek force-update dulu (splash — tanpa auth)
    final version = await api.appVersion('SANTRI_APP').catchError((_) => null);
    if (version != null && version['update_required'] == true) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ForceUpdateScreen(url: null)),
      );
      return;
    }

    // cek sesi tersimpan
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getString('mq_at');
    final rt = prefs.getString('mq_rt');
    if (at != null && rt != null) {
      api.setTokens(at, rt);
      final me = await api.me().catchError((_) => null);
      if (me != null && me['status'] == 'ACTIVE') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ShellScreen()),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.onPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'MQ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'MQ Santri',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mujayarotul Faqih',
              style: TextStyle(color: AppColors.gold, fontSize: 13),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppColors.onPrimary,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  final String? url;
  const ForceUpdateScreen({super.key, this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 64, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text(
                'Update Tersedia',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan perbarui aplikasi untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // TODO: buka URL download APK
                },
                child: const Text('Perbarui Sekarang'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
