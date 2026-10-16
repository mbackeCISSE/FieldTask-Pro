import 'package:fieldtask_pro/features/auth/domain/auth_repository.dart';
import 'package:fieldtask_pro/features/auth/domain/auth_use_cases.dart';
import 'package:fieldtask_pro/features/auth/domain/technician.dart';
import 'package:fieldtask_pro/features/auth/presentation/auth_cubit.dart';
import 'package:fieldtask_pro/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthRepository implements AuthRepository {
  @override
  Future<Technician> signIn(String email, String password) async =>
      const Technician(name: 'Amadou Ndiaye', company: 'TechFix');
  @override
  Future<Technician> startLocalDemo() async => const Technician(
      name: 'Amadou Ndiaye', company: 'TechFix', isLocalDemo: true);
  @override
  Future<Technician?> restoreSession() async => null;
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('la connexion signale un email invalide sans appeler le serveur',
      (tester) async {
    final cubit = AuthCubit(AuthUseCases(_AuthRepository()));
    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: LoginPage()),
    ));

    await tester.enterText(
        find.byKey(const ValueKey('login-email')), 'invalide');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(cubit.state.technician, isNull);
    await cubit.close();
  });

  testWidgets('le mot de passe est masqué puis affiché à la demande',
      (tester) async {
    final cubit = AuthCubit(AuthUseCases(_AuthRepository()));
    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: LoginPage()),
    ));

    final field = find.descendant(
        of: find.byKey(const ValueKey('login-password')),
        matching: find.byType(TextField));
    final password = tester.widget<TextField>(field);
    expect(password.obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(tester.widget<TextField>(field).obscureText, isFalse);
    await cubit.close();
  });
}
