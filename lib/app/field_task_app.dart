import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/interventions/presentation/interventions_cubit.dart';
import '../features/interventions/presentation/pages/detail_page.dart';
import '../features/interventions/presentation/pages/home_page.dart';
import '../features/interventions/domain/intervention_repository.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/profile_page.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/map/presentation/map_cubit.dart';
import '../features/map/presentation/pages/map_page.dart';
import '../features/notifications/domain/reminder_gateway.dart';
import '../features/notifications/domain/reminder_use_cases.dart';
import '../features/notifications/presentation/notifications_cubit.dart';
import '../features/notifications/presentation/notifications_page.dart';
import 'injection_container.dart';

class FieldTaskApp extends StatefulWidget {
  const FieldTaskApp({super.key});

  @override
  State<FieldTaskApp> createState() => _FieldTaskAppState();
}

class _FieldTaskAppState extends State<FieldTaskApp> {
  late final GoRouter _router;
  StreamSubscription<String>? _notificationTaps;
  StreamSubscription<AuthState>? _authChanges;
  String? _pendingInterventionId;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation:
          di<AuthCubit>().state.isAuthenticated ? '/home' : '/login',
      redirect: (context, state) {
        final authenticated = di<AuthCubit>().state.isAuthenticated;
        final atLogin = state.matchedLocation == '/login';
        if (!authenticated && !atLogin) return '/login';
        if (authenticated && atLogin) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(
          path: '/home',
          builder: (_, __) => BlocProvider(
            create: (_) => di<InterventionsCubit>()
              ..refresh()
              ..synchronize(),
            child: const HomePage(),
          ),
        ),
        GoRoute(
          path: '/intervention/:id',
          builder: (_, state) => BlocProvider(
            create: (_) => di<InterventionsCubit>()..refresh(),
            child: DetailPage(id: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/map',
          builder: (_, __) => BlocProvider(
            create: (_) => di<MapCubit>(),
            child: const MapPage(),
          ),
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: '/notifications',
          builder: (_, __) {
            final auth = di<AuthCubit>().state;
            return BlocProvider<NotificationsCubit>(
              create: (_) => NotificationsCubit(
                GetScheduledReminders(
                  di<InterventionRepository>(),
                  di<ReminderGateway>(),
                ),
                technicianId: auth.technician?.id ?? 'techfix-demo-1',
              )..load(),
              child: const NotificationsPage(),
            );
          },
        ),
      ],
    );
    _notificationTaps = di<ReminderGateway>().notificationTaps.listen(
          _openInterventionFromNotification,
        );
    _authChanges = di<AuthCubit>().stream.listen((auth) {
      final id = _pendingInterventionId;
      if (auth.isAuthenticated && id != null) {
        _pendingInterventionId = null;
        _router.push('/intervention/$id');
      }
    });
  }

  void _openInterventionFromNotification(String id) {
    if (id.isEmpty) return;
    if (di<AuthCubit>().state.isAuthenticated) {
      _router.push('/intervention/$id');
    } else {
      _pendingInterventionId = id;
    }
  }

  @override
  void dispose() {
    unawaited(_notificationTaps?.cancel());
    unawaited(_authChanges?.cancel());
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: di<AuthCubit>(),
      child: MaterialApp.router(
        title: 'FieldTask Pro',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF123A52),
            secondary: const Color(0xFF0D9488),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        ),
      ),
    );
  }
}
