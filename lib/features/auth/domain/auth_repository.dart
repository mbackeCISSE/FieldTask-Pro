import 'technician.dart';

abstract interface class AuthRepository {
  Future<Technician> signIn(String email, String password);
  Future<Technician> startLocalDemo();
  Future<Technician?> restoreSession();
  Future<void> signOut();
}
