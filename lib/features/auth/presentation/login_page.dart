import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController(text: 'techfix@demo.sn');
  final password = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final success =
        await context.read<AuthCubit>().signIn(email.text, password.text);
    if (success && mounted) {
      TextInput.finishAutofillContext();
      context.go('/home');
    }
  }

  Future<void> localDemo() async {
    final success = await context.read<AuthCubit>().startLocalDemo();
    if (success && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) => AutofillGroup(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          const Icon(Icons.handyman_outlined,
                              size: 52, color: Color(0xFF123A52)),
                          const SizedBox(height: 18),
                          const Text('FieldTask Pro',
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('TechFix · interventions terrain'),
                          const SizedBox(height: 24),
                          TextFormField(
                            key: const ValueKey('login-email'),
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email
                            ],
                            decoration: const InputDecoration(
                                labelText: 'Adresse e-mail',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder()),
                            validator: (value) {
                              final candidate = value?.trim() ?? '';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(candidate)) {
                                return 'Saisissez une adresse e-mail valide.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('login-password'),
                            controller: password,
                            obscureText: obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  icon: Icon(obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => setState(() =>
                                      obscurePassword = !obscurePassword)),
                            ),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'Saisissez votre mot de passe.'
                                : null,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => signIn(),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: 12),
                            Text(state.error!,
                                style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              key: const ValueKey('login-submit'),
                              onPressed: state.loading ? null : signIn,
                              icon: state.loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.login),
                              label: const Text('Se connecter'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: state.loading ? null : localDemo,
                            icon: const Icon(Icons.offline_bolt_outlined),
                            label: const Text('Démarrer la démo hors ligne'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'Compte de démonstration API : techfix@demo.sn · mot de passe : TechFix2026!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          const Text(
                              'Les sessions, y compris la démo locale, sont conservées dans le stockage sécurisé Android.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
