import 'package:flutter_test/flutter_test.dart';
import 'package:fieldtask_pro/features/auth/domain/auth_repository.dart';
import 'package:fieldtask_pro/features/auth/domain/auth_use_cases.dart';
import 'package:fieldtask_pro/features/auth/domain/authentication_failure.dart';
import 'package:fieldtask_pro/features/auth/domain/technician.dart';
import 'package:fieldtask_pro/features/auth/presentation/auth_cubit.dart';

class _AuthRepository implements AuthRepository {
  _AuthRepository({this.failure, this.restored});
  final Object? failure;
  final Technician? restored;
  bool signedOut = false;

  @override
  Future<Technician> signIn(String email, String password) async {
    if (failure != null) throw failure!;
    return const Technician(name: 'Awa Diop', company: 'TechFix');
  }

  @override
  Future<Technician> startLocalDemo() async =>
      const Technician(name: 'Awa Diop', company: 'TechFix', isLocalDemo: true);

  @override
  Future<Technician?> restoreSession() async => restored;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  test('affiche le motif précis d’un refus d’identifiants du serveur',
      () async {
    final cubit = AuthCubit(AuthUseCases(_AuthRepository(
      failure: const AuthenticationFailure(
        AuthenticationFailureKind.invalidCredentials,
        'Adresse e-mail ou mot de passe incorrect.',
      ),
    )));

    expect(await cubit.signIn('a@b.sn', 'bad'), isFalse);
    expect(cubit.state.error, 'Adresse e-mail ou mot de passe incorrect.');
    expect(cubit.state.isAuthenticated, isFalse);
    await cubit.close();
  });

  test('restaure le profil et efface la session après déconnexion', () async {
    const technician = Technician(name: 'Awa Diop', company: 'TechFix');
    final repository = _AuthRepository(restored: technician);
    final cubit = AuthCubit(AuthUseCases(repository));

    await cubit.restore();
    expect(cubit.state.technician?.name, 'Awa Diop');
    expect(cubit.state.isAuthenticated, isTrue);
    expect(await cubit.signOut(), isTrue);
    expect(repository.signedOut, isTrue);
    expect(cubit.state.isAuthenticated, isFalse);
    await cubit.close();
  });
}
