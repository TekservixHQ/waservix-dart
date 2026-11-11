# waservix

[![pub package](https://img.shields.io/pub/v/waservix.svg)](https://pub.dev/packages/waservix)
[![tests](https://github.com/TekservixHQ/waservix-dart/actions/workflows/tests.yml/badge.svg)](https://github.com/TekservixHQ/waservix-dart/actions/workflows/tests.yml)

**WAservix WhatsApp API Gateway** - official Dart and Flutter client: send WhatsApp messages from your own number. By Tekservix.

Dart and Flutter client for the [WAservix WhatsApp API Gateway](https://tekservix.com/waservix/).

WAservix links your own WhatsApp number by QR code (the same way WhatsApp Web does) and gives you a REST API to send text, images, video, audio, documents, locations, polls and more, with webhooks for incoming messages and status updates.

- Dart backends (Dart Frog, Shelf, Serverpod, Cloud Functions) and Dart CLI tools
- Only depends on `http`
- Webhook check built in

## Install

```bash
dart pub add waservix
```

## Quick start

Copy your device's API key from the WAservix dashboard (Devices -> API key) and keep it on your server.

```dart
import 'dart:io';

import 'package:waservix/waservix.dart';

Future<void> main() async {
  final wa = WAservix(Platform.environment['WASERVIX_KEY']!);

  final res = await wa.sendText('+15551234567', 'Hello Aline, your order is ready');
  print('${res['msgId']} ${res['status']}'); // 58213 in_progress

  wa.close();
}
```

### Flutter apps

**Don't put the API key inside a Flutter app.** Anyone can pull it out of the APK or IPA and send messages from your number. Have the app call your own backend (Dart Frog, Firebase Cloud Functions, any server), and let the backend use this package.

## Sending

Messages are queued and sent one at a time per number, so each call returns right away with `status: "in_progress"` and a `msgId`.

```dart
// Image with caption
await wa.sendImage('+15551234567', 'https://example.com/product.jpg', caption: 'Back in stock');

// Document
await wa.sendDocument('+15551234567', 'https://example.com/inv-1042.pdf',
    fileName: 'Invoice-1042.pdf', caption: 'Your invoice');

// Location
await wa.sendLocation('+15551234567', -1.9441, 30.0619, name: 'Our shop');

// Anything the API supports, including groups (JID ending in @g.us)
await wa.sendMessage('120363040000000000@g.us', {'text': 'Team meeting at 3pm'});
await wa.sendMessage('+15551234567', {
  'poll': {'name': 'Lunch?', 'options': ['Pizza', 'Sushi']}
});
```

## Status, contacts and groups

```dart
final info = await wa.getMessageInfo(58213);      // queued, sent, delivered, read, played or failed
final check = await wa.onWhatsApp('+15551234567'); // {exists: true, jid: ...}
final conn = await wa.getStatus();                // {status: connected}

await wa.editMessage(58213, 'Corrected text');    // own text messages, about 15 minutes
final groups = await wa.listGroups();
```

Anything else in the [API reference](https://tekservix.com/waservix/docs/) is one call away:

```dart
await wa.request('POST', '/messages/read', body: {'msgId': '3EB0X123456789'});
```

## Webhooks

Set a webhook URL and events for the number in the dashboard. Each request carries `X-Webhook-Signature`, which equals the device's webhook secret. Shelf example:

```dart
Future<Response> waWebhook(Request request) async {
  if (!WAservix.verifyWebhook(request.headers['x-webhook-signature'],
      Platform.environment['WASERVIX_WEBHOOK_SECRET']!)) {
    return Response.unauthorized('bad signature');
  }
  final payload = jsonDecode(await request.readAsString());
  if (payload['event'] == 'messages.received') {
    final m = payload['data']['messages'];
    // m['key']['cleanedSenderPn'], m['messageBody']: queue slow work
  }
  return Response.ok('ok');
}
```

## Errors

Failed calls throw `WAservixException` with `status`, `message`, field `errors` and, on 429, `retryAfter` in seconds. A 503 means the device is reconnecting: retry shortly.

## Migrating from WaSender

WAservix accepts the same `/send-message` body and webhook fields as WaSender, so most integrations switch by changing the base URL and key. See the [compatibility notes](https://tekservix.com/waservix/docs/).

## Use it responsibly

WAservix is not Meta's official WhatsApp Business Platform. There's no business verification and no per-conversation fee, but WhatsApp's spam rules apply to your number directly. Message people who expect to hear from you, warm up new numbers slowly and keep the built-in account protection on.

## More from Tekservix

- [SMS Gora SMS Gateway](https://tekservix.com/smsgora/): send SMS through your own Android phones (`dart pub add smsgora`)
- [AI Sales Agent](https://tekservix.com/ai-sales-agent): answers customers on WhatsApp and SMS using your website's content
- [Website to App](https://tekservix.com/mobile-apps): turn your website into Android and iOS apps
- WAservix is also available for Node.js, Python, PHP, Go, Java/Kotlin, .NET, Ruby, Swift and Rust: see [github.com/TekservixHQ](https://github.com/TekservixHQ)

## License

MIT
