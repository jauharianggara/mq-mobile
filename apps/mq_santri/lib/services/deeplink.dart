import 'package:flutter/material.dart';
import 'package:mq_shared/mq_shared.dart';

import '../main.dart';
import '../screens/khatmil_detail_screen.dart';
import '../screens/khatmil_screen.dart';
import '../screens/khatmil_reader_screen.dart';
import '../screens/wallet_screen.dart';

/// Deeplink router (plan F6).
/// Format: `khatmil:assignment:{id}` → langsung buka Reader (auto-resume);
///         `khatmil:campaign:{id}` → buka detail campaign.
/// Dipakai dari: tap notifikasi IN_APP (NotificationScreen) — nanti juga dari push FCM (F5).
Future<void> handleDeeplink(BuildContext context, String? deeplink) async {
  if (deeplink == null || deeplink.isEmpty) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  // khatmil:assignment:{id} → Reader langsung di posisi terakhir
  final m = RegExp(r'^khatmil:assignment:(\d+)$').firstMatch(deeplink);
  if (m != null) {
    final id = int.parse(m.group(1)!);
    try {
      final list = (await api.get('/me/khatmil/assignments') as List?) ?? [];
      final found = list.cast<Map<dynamic, dynamic>?>().firstWhere((a) => a!['id'] == id, orElse: () => null);
      if (!context.mounted) return;
      if (found != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => KhatmilReaderScreen(assignment: found)),
        );
        return;
      }
      // assignment tidak aktif (mis. juz sudah COMPLETED) → arahkan ke tab Khatmil
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Juz tersebut sudah selesai / tidak aktif'), backgroundColor: AppColors.primary),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KhatmilScreen()),
      );
      return;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, 'Gagal membuka juz — coba lagi')), backgroundColor: AppColors.error),
        );
      }
      return;
    }
  }

  // khatmil:campaign:{id} → detail campaign
  final c = RegExp(r'^khatmil:campaign:(\d+)$').firstMatch(deeplink);
  if (c != null) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => KhatmilDetailScreen(campaignId: int.parse(c.group(1)!))),
    );
    return;
  }

  // wallet (penyesuaian saldo dari admin) → halaman Deposit
  if (deeplink == 'wallet') {
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
    return;
  }

  // deeplink lain (setoran, visit, dst.) — backlog F5+; abaikan diam-diam
}
