import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart';

import 'app/field_task_app.dart';
import 'app/injection_container.dart';
import 'features/auth/presentation/auth_cubit.dart';

Future<void> main() async {
  final startup = Stopwatch()..start();
  var stage = Stopwatch()..start();
  await configureDependencies();
  _logStartupDuration('configureDependencies', stage);
  stage = Stopwatch()..start();
  await di<AuthCubit>().restore();
  _logStartupDuration('restoreSession', stage);
  final firstFrame = Stopwatch()..start();
  runApp(const FieldTaskApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (kDebugMode) {
      debugPrint(
          '[startup-timing] firstFrameAfterRunApp=${firstFrame.elapsedMilliseconds}ms total=${startup.elapsedMilliseconds}ms');
    }
    unawaited(_initializePostFrameServices());
  });
}

Future<void> _initializePostFrameServices() async {
  try {
    await initializePostFrameServices();
  } catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'startup',
      context: ErrorDescription('while initializing post-frame services'),
    ));
  }
}

void _logStartupDuration(String stage, Stopwatch stopwatch) {
  if (kDebugMode) {
    debugPrint('[startup-timing] $stage=${stopwatch.elapsedMilliseconds}ms');
  }
}
