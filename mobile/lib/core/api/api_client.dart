import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_endpoints.dart';
import 'api_error.dart';
import '../auth/token_storage.dart';

class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;

  ApiClient({required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      _AuthInterceptor(tokenStorage: _tokenStorage, dio: _dio),
    );
    // Log yalnızca debug'da: üretimde istek/yanıt gövdelerini yazdırmak hem
    // gereksiz maliyet hem de token/kişisel veri sızdırma riski.
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          // Binary yanıtlar (ResponseType.bytes — ör. fotoğraf proxy'si)
          // ASLA gövde olarak loglanmamalı: LogInterceptor gövdeyi metne
          // çevirmeye çalışır ve yüz KB'lık JPEG'de istek transport
          // seviyesinde "DioException [unknown]" ile düşer.
          responseBody: false,
        ),
      );
      _dio.interceptors.add(_JsonResponseLogInterceptor());
    }
  }

  Dio get dio => _dio;

  // GET
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  // POST
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) =>
      _dio.post<T>(path, data: data);

  // PUT
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) =>
      _dio.put<T>(path, data: data);

  // DELETE
  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);

  // Multipart (fotoğraf yükleme)
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
  }) =>
      _dio.post<T>(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
}

/// Yanıt gövdesini yalnızca metin/JSON olduğunda loglar.
///
/// LogInterceptor'ın `responseBody` seçeneği ayrım yapmaz ve binary indirmelerde
/// (fotoğraf proxy'si) isteği düşürür. Debug görünürlüğünü kaybetmemek için
/// gövde logu bu interceptor'a taşındı.
class _JsonResponseLogInterceptor extends Interceptor {
  /// Log'u okunur tutmak için üst sınır.
  static const _maxChars = 1000;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.responseType == ResponseType.json) {
      final body = response.data.toString();
      debugPrint(
        '[API] ${response.statusCode} ${response.requestOptions.path} '
        '${body.length > _maxChars ? '${body.substring(0, _maxChars)}…' : body}',
      );
    }
    handler.next(response);
  }
}

class _AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio dio,
  })  : _tokenStorage = tokenStorage,
        _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          // Yeni token ile isteği tekrarla
          final token = await _tokenStorage.getAccessToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await _dio.fetch(err.requestOptions);
          _isRefreshing = false;
          return handler.resolve(response);
        }
        // Refresh başarısız — token'ları temizle
        _isRefreshing = false;
        await _tokenStorage.clearTokens();
      } catch (_) {
        // Refresh veya retry başarısız
        _isRefreshing = false;
      }
    }

    final apiError = ApiError(
      statusCode: err.response?.statusCode,
      message: _extractErrorMessage(err),
      data: err.response?.data,
    );
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: apiError,
        response: err.response,
        type: err.type,
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Dio(
        BaseOptions(baseUrl: ApiEndpoints.baseUrl),
      ).post(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _extractErrorMessage(DioException err) {
    final data = err.response?.data;
    if (data is Map<String, dynamic> && data.containsKey('error')) {
      return data['error'] as String;
    }
    return err.message ?? 'Bir hata oluştu';
  }
}
