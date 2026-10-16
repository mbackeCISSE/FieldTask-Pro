import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fieldtask_pro/features/auth/domain/auth_repository.dart';
import 'package:fieldtask_pro/features/auth/domain/auth_use_cases.dart';
import 'package:fieldtask_pro/features/auth/domain/technician.dart';
import 'package:fieldtask_pro/features/auth/presentation/auth_cubit.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_attachment.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_repository.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_use_cases.dart';
import 'package:fieldtask_pro/features/interventions/domain/capture_intervention_photo.dart';
import 'package:fieldtask_pro/features/interventions/domain/photo_capture_repository.dart';
import 'package:fieldtask_pro/features/interventions/presentation/interventions_cubit.dart';
import 'package:fieldtask_pro/features/interventions/presentation/pages/home_page.dart';
import 'package:fieldtask_pro/features/notifications/domain/reminder_gateway.dart';
import 'package:fieldtask_pro/features/notifications/domain/reminder_use_cases.dart';
import 'package:fieldtask_pro/features/synchronization/domain/sync_gateway.dart';
import 'package:fieldtask_pro/features/synchronization/domain/sync_use_cases.dart';

class _Repository implements InterventionRepository {
  final items = <Intervention>[
    Intervention(
        id: 'TF-1',
        title: 'Panne routeur',
        client: 'TechFix',
        address: 'Dakar',
        description: '',
        equipment: '',
        priority: WorkPriority.urgent,
        status: WorkStatus.pending,
        dueAt: DateTime(2026, 10, 14),
        latitude: 14,
        longitude: -17),
    Intervention(
        id: 'TF-2',
        title: 'Contrôle pompe',
        client: 'Client B',
        address: 'Thiès',
        description: '',
        equipment: '',
        priority: WorkPriority.low,
        status: WorkStatus.inProgress,
        dueAt: DateTime(2026, 10, 15),
        latitude: 14,
        longitude: -16),
  ];

  @override
  Future<List<Intervention>> watchSnapshot() async => List.of(items);
  @override
  Future<int> pendingOperations() async => 0;
  @override
  Future<List<InterventionAttachment>> attachments(String id) async => [];
  @override
  Future<void> addNote(String id, String note) async {}
  @override
  Future<void> saveAttachment(String id, String kind, List<int> bytes,
      {required String extension}) async {}
  @override
  Future<void> updateStatus(String id, WorkStatus status) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(status: status, syncPending: true);
  }
}

class _Sync implements SyncGateway {
  @override
  Stream<SyncSnapshot> get snapshots => const Stream.empty();
  @override
  Future<SyncSnapshot> currentSnapshot() async => const SyncSnapshot();
  @override
  Future<void> syncNow() async {}
  @override
  Future<void> retryFailed() async {}
  @override
  Future<void> acceptServerVersionForConflicts() async {}
}

class _Capture implements PhotoCaptureRepository {
  @override
  Future<List<int>?> capturePhoto() async => null;
}

class _Reminders implements ReminderGateway {
  @override
  Stream<String> get notificationTaps => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh(List<Intervention> interventions) async {}
  @override
  Future<Set<String>> scheduledInterventionIds() async => {};
}

class _Auth implements AuthRepository {
  static const technician =
      Technician(name: 'Amadou Ndiaye', company: 'TechFix', isLocalDemo: true);
  @override
  Future<Technician> startLocalDemo() async => technician;
  @override
  Future<Technician> signIn(String email, String password) async => technician;
  @override
  Future<Technician?> restoreSession() async => technician;
  @override
  Future<void> signOut() async {}
}

void main() {
  late _Repository repository;
  late InterventionsCubit interventions;
  late AuthCubit auth;
  late GoRouter router;

  Future<void> mount(WidgetTester tester) async {
    await auth.startLocalDemo();
    await interventions.refresh();
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
            path: '/map',
            builder: (_, __) => const Scaffold(body: Text('Carte'))),
        GoRoute(
            path: '/profile',
            builder: (_, __) => const Scaffold(body: Text('Profil'))),
        GoRoute(
            path: '/intervention/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Fiche ${state.pathParameters['id']}'))),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: BlocProvider<InterventionsCubit>.value(
          value: interventions,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _Repository();
    interventions = InterventionsCubit(
      InterventionUseCases(repository),
      SynchronizationUseCases(_Sync()),
      CaptureInterventionPhoto(_Capture()),
      RefreshInterventionReminders(_Reminders()),
    );
    auth = AuthCubit(AuthUseCases(_Auth()));
  });

  tearDown(() async {
    router.dispose();
    await interventions.close();
    await auth.close();
  });

  testWidgets('la recherche et le filtre se combinent sans muter la liste',
      (tester) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField).first, 'Contrôle');
    await tester.pumpAndSettle();
    expect(find.text('Contrôle pompe'), findsOneWidget);
    expect(find.text('Panne routeur'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'En cours'));
    await tester.pumpAndSettle();
    expect(find.text('Contrôle pompe'), findsOneWidget);
    expect(find.text('Panne routeur'), findsNothing);
    expect(repository.items, hasLength(2));
  });

  testWidgets('affiche clairement le mode hors ligne et aucun résultat',
      (tester) async {
    await mount(tester);
    expect(find.text('Démo hors ligne · serveur non utilisé'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'inconnu');
    await tester.pumpAndSettle();
    expect(find.text('Aucune intervention correspondante.'), findsOneWidget);
  });
}
