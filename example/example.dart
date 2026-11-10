import 'dart:io';

import 'package:waservix/waservix.dart';

Future<void> main() async {
  // Copy the device API key from WAservix -> Devices. Keep it on your server.
  final wa = WAservix(Platform.environment['WASERVIX_KEY']!);

  try {
    final status = await wa.getStatus();
    print('Number status: ${status['status']}');

    final res =
        await wa.sendText('+15551234567', 'Hello Aline, your order is ready');
    print('Queued message ${res['msgId']}');
  } on WAservixException catch (e) {
    print('WAservix error ${e.status}: ${e.message}');
  } finally {
    wa.close();
  }
}
