import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

final MqApi api = MqApi();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MqUstadzApp());
}

class MqUstadzApp extends StatelessWidget {
  const MqUstadzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQ Ustadz',
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
    final version = await api.appVersion('USTADZ_APP').catchError((_) => null);
    if (version != null && version['update_required'] == true) {
      if (!mounted) return;
      // force update (belum ada APK hosting — tampilkan pesan)
      _showForceUpdate();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getString('mq_at');
    final rt = prefs.getString('mq_rt');
    if (at != null && rt != null) {
      api.setTokens(at, rt);
      final me = await api.me().catchError((_) => null);
      if (me != null && me['status'] == 'ACTIVE' && me['roles']?.contains('USTADZ') == true) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShellScreen()));
        return;
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
