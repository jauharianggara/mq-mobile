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
    // TIDAK auto-logout: tidak memaksa pindah layar. Sesi lokal dibersihkan,
    // user diberi tahu via snackbar + tombol "Masuk" manual. Login hanya
    // muncul natural saat app dibuka dari awal tanpa sesi valid.
    MqSessionStore.clear();
    final ctx = navKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.maybeOf(ctx)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Sesi Anda berakhir. Silakan masuk kembali.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Masuk',
            onPressed: () {
              navKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ));
    }
  };
  runApp(const MqUstadzApp());
}

class MqUstadzApp extends StatelessWidget {
  const MqUstadzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQ Ustadz',
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
    final version = await api.appVersion('USTADZ_APP').catchError((_) => null);
    if (version != null && version['update_required'] == true) {
      // force update (belum ada APK hosting — tampilkan pesan)
      if (mounted) _showForceUpdate();
      return;
    }

    final at = MqSessionStore.access;
    final rt = MqSessionStore.refresh;
    if (at == null || rt == null) {
      _go(const LoginScreen());
      return;
    }
    api.setTokens(at, rt); // persist idempotent via callback
    try {
      final me = await api.me();
      final roles = (me is Map ? me['roles'] as List? : null) ?? [];
      if (me is Map && me['status'] == 'ACTIVE' && roles.contains('USTADZ')) {
        _go(const ShellScreen());
        return;
      }
      // ada sesi tapi bukan akun ustadz aktif → sesi tidak dipakai
      await MqSessionStore.clear();
      _go(const LoginScreen());
    } on DioException catch (e) {
      if (isUnreachableError(e)) {
        _go(ConnectionErrorScreen(onRetry: _checkSession));
      } else {
        await MqSessionStore.clear();
        _go(const LoginScreen());
      }
    } catch (_) {
      _go(ConnectionErrorScreen(onRetry: _checkSession));
    }
  }

  /// Navigasi via navigatorKey global — aman dari callback retry.
  void _go(Widget screen) {
    navKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showForceUpdate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Tersedia'),
        content: const Text('Silakan perbarui aplikasi untuk melanjutkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('MQ', style: TextStyle(color: AppColors.primaryDark, fontSize: 28, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('MQ Ustadz', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Mujayarotul Faqih', style: TextStyle(color: AppColors.goldLight, fontSize: 13)),
            const SizedBox(height: 32),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
