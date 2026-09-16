import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// true kalau error menandakan server TIDAK terjangkau (bukan sesi invalid).
/// Dipakai splash/app utk membedakan "layar Coba Lagi" vs "kembali ke Login".
bool isUnreachableError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        break;
    }
    final code = e.response?.statusCode ?? 0;
    if (code == 401 || code == 403) return false; // sesi invalid / ditolak
    return true; // 5xx / gateway / unknown -> server bermasalah
  }
  return true; // non-dio -> konservatif: jangan paksa logout
}

/// MQ API Client — dio-based dengan auth interceptor, refresh, force-update headers.
/// Semua request relatif ke /api/v1 (proxy mq-admin atau langsung mq-api).
class MqApi {
  /// Dipanggil SETIAP KALI token berubah (login, refresh rotasi, clear).
  /// App mendaftarkan handler yang menulis/menghapus penyimpanan permanen —
  /// satu jalur tunggal, tidak boleh ada penulisan prefs manual di screen.
  void Function(String? access, String? refresh)? onTokensChanged;

  /// Dipanggil SEKALI saat sesi benar-benar mati (refresh gagal final setelah login).
  /// App: hapus penyimpanan -> kembali ke layar Login + snackbar.
  void Function()? onSessionExpired;
  bool _expiredNotified = false;

  Future<bool>? _refreshing; // single-flight: request paralel berbagi 1 refresh

  static const prodBase = 'https://mq-api.jagodigital.online/api/v1';
  /// Hanya aktif jika di-explicit lewat --dart-define=MQ_DEV_BASE=http://10.0.2.2:8290/api/v1
  /// (utk developer uji lokal di EMULATOR). Perangkat fisik & rilis selalu prod.
  static const _devBaseOverride = String.fromEnvironment('MQ_DEV_BASE', defaultValue: '');
  static const devBase = 'http://10.0.2.2:8290/api/v1'; // Android emulator

  late final Dio dio;
  String? _accessToken;
  String? _refreshToken;

  String get baseUrl =>
      (!kReleaseMode && _devBaseOverride.isNotEmpty) ? _devBaseOverride : prodBase;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  setTokens(String? access, String? refresh) {
    _accessToken = access;
    _refreshToken = refresh;
    if (access != null && refresh != null) _expiredNotified = false;
    onTokensChanged?.call(access, refresh);
  }

  clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    onTokensChanged?.call(null, null);
  }

  MqApi() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Auth header
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          // Force-update headers (pola magnetkaya)
          options.headers['X-App-Platform'] = 'ANDROID';
          options.headers['X-App-Build'] = '1';
          handler.next(options);
        },
        onError: (e, handler) async {
          // 401 → coba refresh → retry (single-flight anti refresh dobel paralel)
          if (e.response?.statusCode == 401 && _refreshToken != null) {
            final refreshFuture = _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
            bool refreshed = false;
            try {
              refreshed = await refreshFuture;
            } catch (_) {}
            if (refreshed && _accessToken != null) {
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              final resp = await dio.fetch(opts);
              handler.resolve(resp);
              return;
            }
            // refresh gagal final → sesi mati (kecuali paralel lain sudah berhasil)
            if (_accessToken == null || _refreshToken == null) {
              clearTokens();
              if (!_expiredNotified) {
                _expiredNotified = true;
                onSessionExpired?.call();
              }
            }
          }
          handler.next(e);
        },
      ),
    ]);
  }

  Future<bool> _doRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: baseUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': _refreshToken},
      );
      if (res.statusCode == 200 && res.data['data'] != null) {
        // lewat setTokens agar callback persist ikut terpanggil (rotasi tersimpan)
        setTokens(res.data['data']['access_token'], res.data['data']['refresh_token']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ============ helpers ============

  /// GET generik — data bisa OBJECT atau ARRAY (endpoint list mengembalikan array;
  /// cast kaku ke Map bikin runtime-error diam-diam di screen list).
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await dio.get(path, queryParameters: query);
    return res.data['data'];
  }

  Future<Map<String, dynamic>?> post(String path, {dynamic data, String? idempotencyKey}) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    final res = await dio.post(path, data: data, options: Options(headers: headers));
    return res.data['data'];
  }

  /// GET yang mengembalikan array data (bukan object).
  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    final res = await dio.get(path, queryParameters: query);
    return (res.data['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>?> put(String path, {dynamic data}) async {
    final res = await dio.put(path, data: data);
    return res.data['data'];
  }

  Future<Map<String, dynamic>?> patch(String path, {dynamic data}) async {
    final res = await dio.patch(path, data: data);
    return res.data['data'];
  }

  Future<Map<String, dynamic>?> delete(String path) async {
    final res = await dio.delete(path);
    return res.data['data'];
  }

  /// Cursor pagination helper.
  Future<({List<dynamic> items, String? nextCursor, bool hasMore})> getPage(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await dio.get(path, queryParameters: query);
    return (
      items: (res.data['data'] ?? []) as List<dynamic>,
      nextCursor: res.data['meta']?['pagination']?['next_cursor'] as String?,
      hasMore: (res.data['meta']?['pagination']?['has_more'] as bool?) ?? false,
    );
  }

  // ============ domain methods ============

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final d = await post('/auth/login', data: {'email': email, 'password': password});
    if (d != null) {
      setTokens(d['access_token'], d['refresh_token']);
    }
    return d;
  }

  Future<Map<String, dynamic>?> register({
    String? email,
    String? phone,
    required String password,
    required String fullName,
  }) async {
    return post('/auth/register', data: {
      'email': email,
      'phone': phone,
      'password': password,
      'full_name': fullName,
      'consent': true,
    });
  }

  Future<void> logout() async {
    try { await post('/auth/logout'); } catch (_) {}
    clearTokens();
  }

  Future<dynamic> me() => get('/me');
  Future<dynamic> santriHome() => get('/me/home');
  Future<dynamic> ustadzHome() => get('/ustadz/me/home');
  Future<dynamic> appVersion(String appId) => get('/app/version', query: {'app_id': appId});

  // ============ visits (Pesan Ustadz — Bagian V) ============
  Future<List<dynamic>> visitServices() => getList('/visits/services');

  Future<List<dynamic>> visitNearby(double lat, double lng, {int? serviceTypeId}) =>
      getList('/visits/ustadz/nearby', query: {
        'lat': lat,
        'lng': lng,
        if (serviceTypeId != null) 'service_type_id': serviceTypeId,
      });

  Future<Map<String, dynamic>?> visitCreate({
    required int ustadzId,
    required int serviceTypeId,
    required String scheduledAt,
    required double lat,
    required double lng,
    int? accuracyM,
    required String addressLabel,
    String? note,
    required String idempotencyKey,
  }) =>
      post('/visits',
          idempotencyKey: idempotencyKey,
          data: {
            'ustadz_id': ustadzId,
            'service_type_id': serviceTypeId,
            'scheduled_at': scheduledAt,
            'lat': lat,
            'lng': lng,
            if (accuracyM != null) 'accuracy_m': accuracyM,
            'address_label': addressLabel,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          });

  Future<({List<dynamic> items, String? nextCursor, bool hasMore})> visitList({String? cursor}) =>
      getPage('/visits', query: {if (cursor != null) 'cursor': cursor});

  Future<dynamic> visitDetail(int id) => get('/visits/$id');
  Future<Map<String, dynamic>?> visitPay(int id) => post('/visits/$id/pay');
  Future<Map<String, dynamic>?> visitCancel(int id) => post('/visits/$id/cancel');

  Future<dynamic> visitReviewStatus(int id) => get('/visits/$id/review');
  Future<Map<String, dynamic>?> visitSubmitReview(int id, {required int rating, String? comment}) =>
      post('/visits/$id/review', data: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });

  Future<List<dynamic>> visitMessages(int id) async =>
      (await getPage('/visits/$id/messages', query: {'limit': 100})).items.reversed.toList();

  Future<Map<String, dynamic>?> visitSendMessage(int id, String body) =>
      post('/visits/$id/messages', data: {'body': body});

  Future<List<dynamic>> visitUstadzReviews(int ustadzId) async =>
      (await getPage('/visits/ustadz/$ustadzId/reviews', query: {'limit': 20})).items;

  Future<Map<String, dynamic>?> putMyLocation(double lat, double lng, {int? accuracyM}) =>
      put('/me/location', data: {
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      });

  // ---- ustadz khatmil monitoring & penugasan (v2) ----
  Future<dynamic> ustadzKhatmil() => get('/ustadz/khatmil');
  Future<int> ustadzKhatmilPendingCount() async {
    final d = await ustadzKhatmil().catchError((_) => null);
    return ((d?['pending'] ?? []) as List).length;
  }
  Future<dynamic> ustadzKhatmilGroupAccept(int groupId) =>
      post('/ustadz/khatmil-groups/$groupId/accept');
  Future<dynamic> ustadzKhatmilGroupReject(int groupId) =>
      post('/ustadz/khatmil-groups/$groupId/reject');

  // ---- ustadz side ----
  Future<dynamic> ustadzVisitSettings() => get('/ustadz/visits/settings');
  Future<Map<String, dynamic>?> ustadzPutVisitSettings({required bool isAccepting, required int maxActiveVisits}) =>
      put('/ustadz/visits/settings', data: {
        'is_accepting': isAccepting,
        'max_active_visits': maxActiveVisits,
      });

  Future<List<dynamic>> ustadzVisitServices() async =>
      (await getPage('/ustadz/visit/services', query: {'limit': 50})).items;

  Future<Map<String, dynamic>?> ustadzUpsertVisitService({
    required int serviceTypeId,
    required int priceAmount,
    required int durationMinutes,
    String? note,
  }) =>
      post('/ustadz/visit/services', data: {
        'service_type_id': serviceTypeId,
        'price_amount': priceAmount,
        'duration_minutes': durationMinutes,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<void> ustadzDeleteVisitService(int serviceTypeId) async =>
      dio.delete('/ustadz/visit/services/$serviceTypeId');

  Future<dynamic> ustadzMyVisits() => get('/ustadz/visits');
  Future<List<dynamic>> ustadzRequesterReviews(int visitId) async =>
      (await getPage('/ustadz/visits/$visitId/requester-reviews', query: {'limit': 20})).items;
  Future<Map<String, dynamic>?> ustadzVisitConfirm(int id) => post('/ustadz/visits/$id/confirm');
  Future<Map<String, dynamic>?> ustadzVisitDecline(int id, String reason) =>
      post('/ustadz/visits/$id/decline', data: {'reason': reason});
  Future<Map<String, dynamic>?> ustadzVisitComplete(int id) => post('/ustadz/visits/$id/complete');
  Future<Map<String, dynamic>?> ustadzVisitReview(int id, {required int rating, String? comment}) =>
      post('/ustadz/visits/$id/review', data: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
}
