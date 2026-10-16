import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_repository.dart';
import '../domain/authentication_failure.dart';
import '../domain/technician.dart';

class SecureRestAuthRepository implements AuthRepository {
  SecureRestAuthRepository(
      {required String apiUrl, Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ??
            Dio(BaseOptions(
                baseUrl: apiUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8))),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'fieldtask.access_token';
  static const _technicianKey = 'fieldtask.technician';

  void attachSessionToken() {
    _dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token != 'local-demo-session') {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  @override
  Future<Technician> signIn(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('auth/demo',
          data: {'email': email.trim(), 'password': password});
      final body = response.data;
      final token = body?['accessToken'] as String?;
      final technician = body?['technician'];
      if (token == null || token.trim().isEmpty || technician is! Map) {
        throw const AuthenticationFailure(
          AuthenticationFailureKind.unexpected,
          'La réponse du serveur ne contient pas une session valide.',
        );
      }
      final name = technician['name'] as String?;
      if (name == null || name.trim().isEmpty) {
        throw const AuthenticationFailure(
          AuthenticationFailureKind.unexpected,
          'Le profil technicien reçu est incomplet.',
        );
      }
      final company = technician['company'] as String?;
      final role = technician['role'] as String?;
      final user = Technician(
        name: name.trim(),
        id: technician['id'] as String? ?? 'techfix-demo-1',
        company:
            company?.trim().isNotEmpty == true ? company!.trim() : 'TechFix',
        role: role?.trim().isNotEmpty == true ? role!.trim() : 'Technicien',
      );
      await _save(token, user);
      return user;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const AuthenticationFailure(
          AuthenticationFailureKind.invalidCredentials,
          'Adresse e-mail ou mot de passe incorrect.',
        );
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const AuthenticationFailure(
          AuthenticationFailureKind.serviceUnavailable,
          'Le serveur est inaccessible. Vérifiez la connexion ou utilisez la démo hors ligne.',
        );
      }
      throw const AuthenticationFailure(
        AuthenticationFailureKind.unexpected,
        'La connexion a échoué. Réessayez.',
      );
    }
  }

  @override
  Future<Technician> startLocalDemo() async {
    const user = Technician(
        name: 'Amadou Ndiaye', company: 'TechFix', isLocalDemo: true);
    await _save('local-demo-session', user);
    return user;
  }

  Future<void> _save(String token, Technician user) async {
    await _storage.write(
        key: _technicianKey,
        value: jsonEncode({
          'name': user.name,
          'company': user.company,
          'id': user.id,
          'role': user.role,
          'isLocalDemo': user.isLocalDemo
        }));
    // The token marks a complete saved session; write it last.
    await _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<Technician?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    final json = await _storage.read(key: _technicianKey);
    if (token == null || token.isEmpty || json == null) {
      await _clearSession();
      return null;
    }
    try {
      final user = jsonDecode(json) as Map<String, dynamic>;
      final name = user['name'] as String?;
      if (name == null || name.trim().isEmpty) {
        await _clearSession();
        return null;
      }
      return Technician(
          name: name,
          id: user['id'] as String? ?? 'techfix-demo-1',
          company: user['company'] as String? ?? 'TechFix',
          role: user['role'] as String? ?? 'Technicien',
          isLocalDemo:
              user['isLocalDemo'] as bool? ?? token == 'local-demo-session');
    } on Object {
      await _clearSession();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty && token != 'local-demo-session') {
      try {
        await _dio.post<void>('auth/logout');
      } on DioException {
        // Local logout must still work while offline; server tokens also expire.
      }
    }
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _technicianKey);
  }
}
