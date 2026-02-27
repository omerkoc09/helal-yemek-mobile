import 'package:dio/dio.dart';

import '../../../core/api/api_error.dart';

List<T> parseList<T>(
  dynamic data,
  T Function(Map<String, dynamic>) fromJson,
) {
  final List<dynamic> list;
  if (data is Map<String, dynamic>) {
    list = data['data'] as List? ?? [];
  } else if (data is List) {
    list = data;
  } else {
    list = [];
  }
  return list.map((json) => fromJson(json as Map<String, dynamic>)).toList();
}

String extractErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final apiError = error.error;
    if (apiError is ApiError) {
      return apiError.message;
    }
    // Bağlantı hatası
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Sunucuya bağlanılamadı.';
    }
    return error.message ?? fallback;
  }
  return fallback;
}
