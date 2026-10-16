import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../features/auth/data/secure_rest_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/auth_use_cases.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/interventions/data/sqlite_intervention_repository.dart';
import '../features/interventions/data/image_picker_photo_capture_repository.dart';
import '../features/interventions/domain/photo_capture_repository.dart';
import '../features/interventions/domain/intervention_repository.dart';
import '../features/interventions/domain/intervention_use_cases.dart';
import '../features/interventions/domain/get_interventions.dart';
import '../features/interventions/domain/capture_intervention_photo.dart';
import '../features/interventions/presentation/interventions_cubit.dart';
import '../features/map/data/geolocator_location_repository.dart';
import '../features/map/domain/location_repository.dart';
import '../features/map/domain/get_current_location.dart';
import '../features/map/presentation/map_cubit.dart';
import '../features/synchronization/data/sync_service.dart';
import '../features/synchronization/domain/sync_gateway.dart';
import '../features/synchronization/domain/sync_use_cases.dart';
import '../features/notifications/data/local_reminder_service.dart';
import '../features/notifications/domain/reminder_gateway.dart';
import '../features/notifications/domain/reminder_use_cases.dart';

final di = GetIt.instance;

Future<void> configureDependencies() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (di.isRegistered<Database>()) return;

  var startupStage = Stopwatch()..start();
  final directory = await getApplicationDocumentsDirectory();
  _logStartupDuration('documentsDirectory', startupStage);
  startupStage = Stopwatch()..start();
  final database = await openDatabase(
    p.join(directory.path, 'fieldtask.sqlite'),
    version: 3,
    onCreate: (db, _) => SqliteInterventionRepository.createSchema(db),
    onUpgrade: SqliteInterventionRepository.upgradeSchema,
  );
  _logStartupDuration('openDatabase', startupStage);
  final repository = SqliteInterventionRepository(database);
  startupStage = Stopwatch()..start();
  await repository.seedIfEmpty();
  _logStartupDuration('seedIfEmpty', startupStage);

  final apiUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  final baseUrl =
      apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
  final restApiUrl = '$baseUrl/api/';
  final syncService = SyncService(database, apiUrl: restApiUrl);
  final authRepository = SecureRestAuthRepository(apiUrl: restApiUrl);
  authRepository.attachSessionToken();
  final reminders = LocalReminderService();

  di
    ..registerSingleton<Database>(database)
    ..registerSingleton<SqliteInterventionRepository>(repository)
    ..registerSingleton<InterventionRepository>(repository)
    ..registerSingleton<InterventionUseCases>(InterventionUseCases(repository))
    ..registerSingleton<PhotoCaptureRepository>(
        ImagePickerPhotoCaptureRepository())
    ..registerSingleton<CaptureInterventionPhoto>(
        CaptureInterventionPhoto(di<PhotoCaptureRepository>()))
    ..registerSingleton<SyncService>(syncService)
    ..registerSingleton<SyncGateway>(syncService)
    ..registerSingleton<SynchronizationUseCases>(
        SynchronizationUseCases(di<SyncGateway>()))
    ..registerSingleton<AuthRepository>(authRepository)
    ..registerSingleton<AuthUseCases>(AuthUseCases(authRepository))
    ..registerSingleton<AuthCubit>(AuthCubit(di<AuthUseCases>()))
    ..registerSingleton<ReminderGateway>(reminders)
    ..registerSingleton<RefreshInterventionReminders>(
        RefreshInterventionReminders(di<ReminderGateway>()))
    ..registerFactory(() => GetScheduledReminders(
        di<InterventionRepository>(), di<ReminderGateway>()))
    ..registerSingleton<LocationRepository>(GeolocatorLocationRepository())
    ..registerSingleton<GetCurrentLocation>(
        GetCurrentLocation(di<LocationRepository>()))
    ..registerFactory(() => MapCubit(
        GetInterventions(di<InterventionRepository>()),
        di<GetCurrentLocation>(),
        technicianId: di<AuthCubit>().state.technician?.id ?? 'techfix-demo-1'))
    ..registerFactory(() => InterventionsCubit(
        di<InterventionUseCases>(),
        di<SynchronizationUseCases>(),
        di<CaptureInterventionPhoto>(),
        di<RefreshInterventionReminders>(),
        technicianId:
            di<AuthCubit>().state.technician?.id ?? 'techfix-demo-1'));

  unawaited(syncService.start());
}

/// Initialize reminders after the first frame so Android permission prompts
/// and plugin setup do not delay the initial application screen.
Future<void> initializePostFrameServices() async {
  final reminders = di<ReminderGateway>();
  var startupStage = Stopwatch()..start();
  await reminders.initialize();
  _logStartupDuration('reminders.initialize', startupStage);
  startupStage = Stopwatch()..start();
  final technicianId = di<AuthCubit>().state.technician?.id ?? 'techfix-demo-1';
  final interventions =
      await di<SqliteInterventionRepository>().watchSnapshot();
  await reminders.refresh(interventions
      .where((item) => item.assignedTechnicianId == technicianId)
      .toList(growable: false));
  _logStartupDuration('reminders.refresh', startupStage);
}

void _logStartupDuration(String stage, Stopwatch stopwatch) {
  if (kDebugMode) {
    debugPrint('[startup-timing] $stage=${stopwatch.elapsedMilliseconds}ms');
  }
}
