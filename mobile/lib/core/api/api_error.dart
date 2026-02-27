class ApiError implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiError({
    this.statusCode,
    required this.message,
    this.data,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 422;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiError($statusCode): $message';
}
