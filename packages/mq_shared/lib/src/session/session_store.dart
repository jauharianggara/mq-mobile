import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/mq_api.dart';

/// Penyimpanan permanen sesi login (satu jalur tunggal).
///
/// main() tiap app WAJIB memanggil [init] lalu [attach] SEBELUM runApp —
/// setelah itu semua penulisan/penghapusan token lewat callback MqApi.
class MqSessionStore {
  static const accessKey = 'mq_at';
  static const refreshKey = 'mq_rt';

  static SharedPreferences? _prefs;

  /// Idempotent — aman dipanggil berkali-kali.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Pasang jalur persist: setiap token berubah (login/rotasi/clear) otomatis
  /// tersimpan. Ini menutup bug "token hasil refresh hanya di RAM".
  static void attach(MqApi api) {
    api.onTokensChanged = (access, refresh) {
      final p = _prefs;
      if (p == null) {
        debugPrint('MqSessionStore.attach: prefs belum init — token tidak dipersist');
        return;
      }
      if (access == null || refresh == null || access.isEmpty || refresh.isEmpty) {
        p.remove(accessKey);
        p.remove(refreshKey);
      } else {
        p.setString(accessKey, access);
        p.setString(refreshKey, refresh);
      }
    };
  }

  static String? get access => _prefs?.getString(accessKey);
  static String? get refresh => _prefs?.getString(refreshKey);
  static bool get hasSession => access != null && refresh != null;

  /// Hapus sesi tersimpan (dipakai: sesi invalid / logout / sesi berakhir).
  /// TIDAK menyentuh preferensi lain (terjemahan reader, consent lokasi, dll).
  static Future<void> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(accessKey);
    await _prefs!.remove(refreshKey);
  }
}
