import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../interventions/domain/intervention.dart';
import '../domain/reminder_gateway.dart';
import '../domain/reminder_schedule.dart';

class LocalReminderService implements ReminderGateway {
  LocalReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();
  bool _initialized = false;
  bool _permissionDenied = false;
  Future<void>? _initializing;

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    var startupStage = Stopwatch()..start();
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Dakar'));
    _logStartupDuration('timezoneDatabase', startupStage);
    startupStage = Stopwatch()..start();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _notificationTapController.add(payload);
        }
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _notificationTapController.add(launchPayload);
    }
    _logStartupDuration('notificationPlugin', startupStage);
    _initialized = true;
  }

  @override
  Stream<String> get notificationTaps => _notificationTapController.stream;

  @override
  Future<Set<String>> scheduledInterventionIds() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests
        .map((request) => request.payload)
        .whereType<String>()
        .where((payload) => payload.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> refresh(List<Intervention> interventions) async {
    if (!_initialized) await initialize();
    final now = DateTime.now();
    final dueItems = <(Intervention, DateTime)>[];
    for (final item in interventions) {
      final scheduledAt = ReminderSchedule.scheduledAt(item, now);
      if (scheduledAt != null) dueItems.add((item, scheduledAt));
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (dueItems.isNotEmpty && android != null) {
      var permissionGranted = await android.areNotificationsEnabled();
      if (permissionGranted == true) {
        // The user may have enabled notifications in Android settings since
        // the last refresh; allow normal scheduling again.
        _permissionDenied = false;
      } else if (!_permissionDenied) {
        permissionGranted = await android.requestNotificationsPermission();
        permissionGranted ??= await android.areNotificationsEnabled();
        _permissionDenied = permissionGranted != true;
      }
      // Preserve already scheduled alarms when permission is denied or disabled.
      if (permissionGranted != true || _permissionDenied) return;
    }

    // Stable IDs make each scheduled reminder replace its previous version.
    // Cancel only after permission has been checked, so a denial cannot erase
    // reminders that were already scheduled in an earlier app session.
    var startupStage = Stopwatch()..start();
    await _plugin.cancelAll();
    _logStartupDuration('notifications.cancelAll', startupStage);
    startupStage = Stopwatch()..start();
    for (final (item, scheduledAt) in dueItems) {
      await _plugin.zonedSchedule(
        id: _stableId(item.id),
        title: 'Intervention imminente',
        body: '${item.title} · ${item.client}',
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'fieldtask_due_dates',
            'Échéances des interventions',
            channelDescription: 'Rappels locaux avant les rendez-vous terrain.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.id,
      );
    }
    _logStartupDuration(
        'notifications.schedule count=${dueItems.length}', startupStage);
  }

  void _logStartupDuration(String stage, Stopwatch stopwatch) {
    if (kDebugMode) {
      debugPrint('[startup-timing] $stage=${stopwatch.elapsedMilliseconds}ms');
    }
  }

  int _stableId(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
