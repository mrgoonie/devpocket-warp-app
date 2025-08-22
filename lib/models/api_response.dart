/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;
  final List<String>? errors;
  
  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.errors,
  });
  
  /// Create a successful response
  const ApiResponse.success({
    required this.data,
    this.message,
  }) : success = true,
       statusCode = null,
       errors = null;
  
  /// Create an error response
  const ApiResponse.error({
    required this.message,
    this.statusCode,
    this.errors,
  }) : success = false,
       data = null;
  
  /// Check if response indicates success
  bool get isSuccess => success;
  
  /// Check if response indicates error
  bool get isError => !success;
  
  /// Get error message with fallback
  String get errorMessage => message ?? 'An unknown error occurred';
  
  /// Get first error from errors list
  String? get firstError => errors?.isNotEmpty == true ? errors!.first : null;
  
  /// Get all error messages combined
  String get allErrors {
    if (errors?.isNotEmpty == true) {
      return errors!.join(', ');
    }
    return errorMessage;
  }
  
  /// Check if this is a specific HTTP status code
  bool hasStatusCode(int code) => statusCode == code;
  
  /// Check if this is an authentication error
  bool get isAuthError => statusCode == 401;
  
  /// Check if this is a forbidden error
  bool get isForbiddenError => statusCode == 403;
  
  /// Check if this is a not found error
  bool get isNotFoundError => statusCode == 404;
  
  /// Check if this is a validation error
  bool get isValidationError => statusCode == 400;
  
  /// Check if this is a server error
  bool get isServerError => statusCode != null && statusCode! >= 500;
  
  /// Check if this is a client error
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
  
  /// Transform the data if successful, otherwise return error response
  ApiResponse<R> transform<R>(R Function(T data) transformer) {
    if (isSuccess && data != null) {
      try {
        final transformedData = transformer(data!);
        return ApiResponse.success(
          data: transformedData,
          message: message,
        );
      } catch (e) {
        return ApiResponse.error(
          message: 'Data transformation failed: $e',
          statusCode: statusCode,
        );
      }
    }
    
    return ApiResponse.error(
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }
  
  /// Map the response data
  ApiResponse<R> map<R>(R Function(T) mapper) {
    if (isSuccess && data != null) {
      return ApiResponse.success(
        data: mapper(data!),
        message: message,
      );
    }
    
    return ApiResponse.error(
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }
  
  /// Execute a callback if successful
  ApiResponse<T> onSuccess(void Function(T data) callback) {
    if (isSuccess && data != null) {
      callback(data!);
    }
    return this;
  }
  
  /// Execute a callback if error
  ApiResponse<T> onError(void Function(String message, int? statusCode) callback) {
    if (isError) {
      callback(errorMessage, statusCode);
    }
    return this;
  }
  
  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success(data: $data, message: $message)';
    } else {
      return 'ApiResponse.error(message: $message, statusCode: $statusCode, errors: $errors)';
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ApiResponse<T> &&
        other.success == success &&
        other.data == data &&
        other.message == message &&
        other.statusCode == statusCode &&
        _listEquals(other.errors, errors);
  }
  
  @override
  int get hashCode {
    return success.hashCode ^
        data.hashCode ^
        message.hashCode ^
        statusCode.hashCode ^
        errors.hashCode;
  }
  
  bool _listEquals<E>(List<E>? a, List<E>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}