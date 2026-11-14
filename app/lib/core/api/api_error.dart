import '../../l10n/l10n.dart';

/// Errors raised by the API layer. Mirrors the server error shape
/// `{"error": {"code": "<snake_case>", "message": "<human text>"}}`.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  /// Server error code (`not_found`, `bad_request`, ...) or a client-side
  /// code: `network` (no connection) or `unknown`.
  final String code;
  final String message;
  final int? statusCode;

  bool get isNetwork => code == 'network';
  bool get isNotFound => statusCode == 404 || code == 'not_found';

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// 401 with code `unauthorized`: the stored token is missing, invalid or
/// expired. The app returns to the login screen.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Session expired'])
      : super('unauthorized', message, statusCode: 401);
}

/// 401 with code `invalid_credentials`, returned by `POST /auth/login`.
class InvalidCredentialsException extends ApiException {
  const InvalidCredentialsException([String message = 'Invalid credentials'])
      : super('invalid_credentials', message, statusCode: 401);
}

/// 403 `forbidden`: the user is signed in but not allowed (e.g. a non-admin
/// calling `/admin/*`).
class ForbiddenException extends ApiException {
  const ForbiddenException([String message = 'Forbidden']) : super('forbidden', message, statusCode: 403);
}

/// A friendly, localized message for any error thrown by the API layer
/// (server messages without a known code are shown as sent).
String friendlyApiError(AppLocalizations l, Object error) {
  if (error is ForbiddenException) return l.errorForbidden;
  if (error is ApiException) {
    if (error.isNetwork) return l.errorNetwork;
    return error.message.isEmpty ? l.errorGeneric : error.message;
  }
  return l.errorGeneric;
}
