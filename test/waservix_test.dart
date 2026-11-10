import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:waservix/waservix.dart';

void main() {
  late http.Request last;
  var status = 200;
  var reply = '{"success":true,"data":{"msgId":58213,"status":"in_progress"}}';

  WAservix client() => WAservix('wpk_test', baseUrl: 'https://example.test/api',
          httpClient: MockClient((req) async {
        last = req;
        return http.Response(reply, status,
            headers: {'content-type': 'application/json'});
      }));

  Map<String, dynamic> body() => jsonDecode(last.body) as Map<String, dynamic>;

  setUp(() {
    status = 200;
    reply = '{"success":true,"data":{"msgId":58213,"status":"in_progress"}}';
  });

  test('sendText', () async {
    final res = await client().sendText('+1555', 'hi');
    expect(res['msgId'], 58213);
    expect(last.method, 'POST');
    expect(last.url.toString(), 'https://example.test/api/send-message');
    expect(last.headers['Authorization'], 'Bearer wpk_test');
    expect(body(), {'to': '+1555', 'text': 'hi'});
  });

  test('media and paths', () async {
    final c = client();
    await c.sendImage('+1', 'https://x/y.jpg');
    expect(body(), {'to': '+1', 'imageUrl': 'https://x/y.jpg'});
    await c.sendDocument('+1', 'https://x/a.pdf',
        fileName: 'a.pdf', caption: 'c');
    expect(body()['fileName'], 'a.pdf');
    expect(body()['text'], 'c');
    await c.sendLocation('+1', -1.9441, 30.0619, name: 'Shop');
    expect(body()['location']['name'], 'Shop');
    await c.getMessageInfo(5);
    expect(last.url.path, '/api/messages/5/info');
    await c.editMessage(5, 't');
    expect(last.method, 'PUT');
    await c.onWhatsApp('+1555');
    expect(last.url.toString(), 'https://example.test/api/on-whatsapp/%2B1555');
    await c.getGroupMetadata('1203@g.us');
    expect(last.url.toString(),
        'https://example.test/api/groups/1203%40g.us/metadata');
    await c.connectSession(3);
    expect(body(), {'method': 'qr'});
    await c.connectSession(3, phone: '+1555');
    expect(body(), {'method': 'code', 'phone': '+1555'});
    expect(() => c.sendText('', 'x'), throwsArgumentError);
  });

  test('API errors', () async {
    status = 503;
    reply = '{"success":false,"message":"Device reconnecting"}';
    try {
      await client().getStatus();
      fail('expected error');
    } on WAservixException catch (e) {
      expect(e.status, 503);
      expect(e.message, 'Device reconnecting');
    }

    status = 200;
    reply = '{"success":false,"message":"Invalid number"}';
    try {
      await client().sendText('+1', 'x');
      fail('expected error');
    } on WAservixException catch (e) {
      expect(e.message, 'Invalid number');
    }
  });

  test('verifyWebhook', () {
    expect(WAservix.verifyWebhook('abc', 'abc'), isTrue);
    expect(WAservix.verifyWebhook('abd', 'abc'), isFalse);
    expect(WAservix.verifyWebhook('abcd', 'abc'), isFalse);
    expect(WAservix.verifyWebhook(null, 'abc'), isFalse);
  });
}
