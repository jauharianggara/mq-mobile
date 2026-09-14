import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// MQ API Client — dio-based dengan auth interceptor, refresh, force-update headers.
/// Semua request relatif ke /api/v1 (proxy mq-admin atau langsung mq-api).
class MqApi {
  static const prodBase = 'https://mq-api.jagodigital.online/api/v1';
  static const devBase = 'http://10.0.2.2:8290/api/v1'; // Android emulator

  late final Dio dio;
  String? _accessToken;
  String? _refreshToken;

  String get baseUrl => kReleaseMode ? prodBase : devBase;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  setTokens(String? access, String? refresh) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  clearTokens() {
    _accessToken = null;
    _refreshToken = null;
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
          // 401 → coba refresh → retry
          if (e.response?.statusCode == 401 && _refreshToken != null) {
            try {
              final refreshed = await _doRefresh();
              if (refreshed) {
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $_accessToken';
                final resp = await dio.fetch(opts);
                handler.resolve(resp);
                return;
              }
            } catch (_) {}
            clearTokens();
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
        _accessToken = res.data['data']['access_token'];
        _refreshToken = res.data['data']['refresh_token'];
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ============ helpers ============

  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    final res = await dio.get(path, queryParameters: query);
    return res.data['data'];
  }

  Future<Map<String, dynamic>?> post(String path, {dynamic data, String? idempotencyKey}) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    final res = await dio.post(path, data: data, options: Options(headers: headers));
    return res.data['data'];
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

  Future<Map<String, dynamic>?> me() => get('/me');
  Future<Map<String, dynamic>?> santriHome() => get('/me/home');
  Future<Map<String, dynamic>?> ustadzHome() => get('/ustadz/me/home');
  Future<Map<String, dynamic>?> appVersion(String appId) => get('/app/version', query: {'app_id': appId});
}
