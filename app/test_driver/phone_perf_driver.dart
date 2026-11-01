import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final dir = Directory(Platform.environment['PERF_OUT']!)
      ..createSync(recursive: true);
    for (final entry in data!.entries) {
      File('${dir.path}/${entry.key}.json')
          .writeAsStringSync(jsonEncode(entry.value));
    }
  },
);
