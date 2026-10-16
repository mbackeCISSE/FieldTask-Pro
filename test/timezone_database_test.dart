import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('la base chargée contient le fuseau Africa/Dakar', () {
    tzdata.initializeTimeZones();

    expect(tz.getLocation('Africa/Dakar').name, 'Africa/Dakar');
  });
}
