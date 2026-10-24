import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('${Platform.environment['PARITY_OUT']!}/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return true;
  },
  responseDataCallback: (data) async {
    data?.remove('screenshots'); // PNG files already saved; avoid duplicate payload.
    File('${Platform.environment['PARITY_OUT']!}/capture.json')
        .writeAsStringSync(jsonEncode(data));
  },
);
