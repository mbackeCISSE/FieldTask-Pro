import 'auth_repository.dart';
import 'technician.dart';

class AuthUseCases {
  const AuthUseCases(this.repository);
  final AuthRepository repository;
  Future<Technician> signIn(String email, String password) =>
      repository.signIn(email, password);
  Future<Technician> startLocalDemo() => repository.startLocalDemo();
  Future<Technician?> restoreSession() => repository.restoreSession();
  Future<void> signOut() => repository.signOut();
}
