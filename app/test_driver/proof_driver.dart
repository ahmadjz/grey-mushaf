import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final file = File(Platform.environment['PROOF_OUT']!);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(data));
  },
);
