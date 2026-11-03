class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  AppException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'Network connection failed. Please check your internet.'])
      : super(message);
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Session expired. Please log in again.'])
      : super(message, statusCode: 401);
}

class NotFoundException extends AppException {
  NotFoundException([String message = 'Requested resource not found.'])
      : super(message, statusCode: 404);
}

class ValidationException extends AppException {
  ValidationException(String message, {dynamic details})
      : super(message, statusCode: 422, details: details);
}

class ServerException extends AppException {
  ServerException([String message = 'Internal server error. Please try again later.'])
      : super(message, statusCode: 500);
}
