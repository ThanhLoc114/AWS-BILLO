class AuthSession {
  final String idToken;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  const AuthSession({
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class AuthSessionStore {
  AuthSession? _session;

  AuthSession? get current => _session;
  void save(AuthSession session) => _session = session;
  void clear() => _session = null;
}
