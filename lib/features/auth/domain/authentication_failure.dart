enum AuthenticationFailureKind {
  invalidCredentials,
  serviceUnavailable,
  unexpected,
}

class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.kind, this.message);

  final AuthenticationFailureKind kind;
  final String message;

  @override
  String toString() => message;
}
