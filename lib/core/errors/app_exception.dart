class AppException implements Exception {
  const AppException(this.message, {this.codigo});

  final String message;
  final String? codigo;

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.codigo});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.codigo});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.codigo});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.codigo});
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.codigo});
}
