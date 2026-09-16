import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:dio/dio.dart';

import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

final MqApi api = MqApi();
final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MqSessionStore.init();
  MqSessionStore.attach(api);
  api.onSessionExpired = () {
    MqSessionStore.clear();
    navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    final ctx = navKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        const SnackBar(content: Text('Sesi Anda berakhir. Silakan masuk kembali.')),
      );
    }
  };
  runApp(const MqSantriApp());
}

class MqSantriApp extends StatelessWidget {
  const MqSantriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQ Santri',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
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
      _go(const ForceUpdateScreen(url: null));
      return;
    }

    // cek sesi tersimpan
    final at = MqSessionStore.access;
    final rt = MqSessionStore.refresh;
    if (at == null || rt == null) {
      _go(const LoginScreen());
      return;
    }
    api.setTokens(at, rt); // persist idempotent via callback
    try {
      final me = await api.me();
      if (me is Map && me['status'] == 'ACTIVE') {
        _go(const ShellScreen());
        return;
      }
      // akun ada tapi status bukan ACTIVE (suspend/dll) → sesi tidak dipakai
      await MqSessionStore.clear();
      _go(const LoginScreen());
    } on DioException catch (e) {
      if (isUnreachableError(e)) {
        // server tak terjangkau ≠ sesi mati — JANGAN paksa login
        _go(ConnectionErrorScreen(onRetry: _checkSession));
      } else {
        // 401/403 final (refresh sudah dicoba interceptor) → sesi invalid
        await MqSessionStore.clear();
        _go(const LoginScreen());
      }
    } catch (_) {
      // error tak dikenal — konservatif: jangan paksa login
      _go(ConnectionErrorScreen(onRetry: _checkSession));
    }
  }

  /// Navigasi via navigatorKey global — aman dipanggil dari callback retry
  /// meski state splash sudah di-dispose.
  void _go(Widget screen) {
    navKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
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
