import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_use_cases.dart';
import '../domain/authentication_failure.dart';
import '../domain/technician.dart';

class AuthState {
  const AuthState(
      {this.technician,
      this.loading = false,
      this.error,
      this.isLocalDemo = false});
  final Technician? technician;
  final bool loading;
  final String? error;
  final bool isLocalDemo;
  bool get isAuthenticated => technician != null;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.useCases) : super(const AuthState());
  final AuthUseCases useCases;

  Future<void> restore() async {
    try {
      final technician = await useCases.restoreSession();
      emit(AuthState(
          technician: technician,
          isLocalDemo: technician?.isLocalDemo ?? false));
    } catch (_) {
      emit(const AuthState(
          error: 'Session impossible à restaurer. Connectez-vous à nouveau.'));
    }
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => useCases.signIn(email, password));
  Future<bool> startLocalDemo() => _run(useCases.startLocalDemo, local: true);

  Future<bool> _run(Future<Technician> Function() action,
      {bool local = false}) async {
    if (state.loading) return false;
    emit(const AuthState(loading: true));
    try {
      final technician = await action();
      emit(AuthState(technician: technician, isLocalDemo: local));
      return true;
    } catch (error) {
      emit(AuthState(error: _message(error)));
      return false;
    }
  }

  String _message(Object error) {
    if (error is AuthenticationFailure) return error.message;
    return 'Connexion impossible. Réessayez ou utilisez la démo hors ligne.';
  }

  Future<bool> signOut() async {
    if (state.loading) return false;
    final technician = state.technician;
    final localDemo = state.isLocalDemo;
    emit(AuthState(
        technician: technician, loading: true, isLocalDemo: localDemo));
    try {
      await useCases.signOut();
      emit(const AuthState());
      return true;
    } catch (_) {
      emit(AuthState(
          technician: technician,
          isLocalDemo: localDemo,
          error: 'Déconnexion impossible. Réessayez.'));
      return false;
    }
  }
}
