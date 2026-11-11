/// Dart and Flutter client for the WAservix WhatsApp API Gateway.
///
/// WAservix links your own WhatsApp number by QR code (the same way WhatsApp
/// Web does) and gives you a REST API to send text, images, documents,
/// locations, polls and more.
///
/// ```dart
/// final wa = WAservix(Platform.environment['WASERVIX_KEY']!);
/// final res = await wa.sendText('+15551234567', 'Hello Aline, your order is ready');
/// print(res['msgId']); // 58213
/// ```
///
/// Keep the API key on your server. API reference: https://tekservix.com/waservix/docs/
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Package version, sent in the User-Agent header.
const String waservixVersion = '1.0.1';

/// Thrown when the API answers with an error. A 503 means the device is reconnecting.
class WAservixException implements Exception {
  /// HTTP status.
  final int status;

  /// Message from the API, or `HTTP <status>`.
  final String message;

  /// Field errors, when the API sends them.
  final Object? errors;

  /// Parsed JSON body, or the raw text when it was not JSON.
  final Object? body;

  /// Seconds to wait before retrying (sent with 429).
  final double? retryAfter;

  /// Creates an API error.
  WAservixException(this.status, this.message,
      {this.errors, this.body, this.retryAfter});

  @override
  String toString() => 'WAservixException: $message (HTTP $status)';
}

/// WAservix API client. Reuse one instance; call [close] when done.
class WAservix {
  /// Production API base URL.
  static const String defaultBaseUrl = 'https://tekservix.com/waservix/api';

  /// Base URL in use.
  final String baseUrl;

  final String _apiKey;
  final Duration _timeout;
  final http.Client _http;
  final bool _ownsClient;

  /// Client with a device API key (Devices -> API key), or a personal access
  /// token for session management.
  ///
  /// Pass [httpClient] to reuse your own client (proxy, retries, tests).
  WAservix(String apiKey,
      {String baseUrl = defaultBaseUrl,
      Duration timeout = const Duration(seconds: 30),
      http.Client? httpClient})
      : _apiKey = apiKey,
        baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _timeout = timeout,
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null {
    if (apiKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey',
          'WAservix: apiKey is required (Devices -> API key in the WAservix dashboard)');
    }
  }

  /// Call any documented endpoint, e.g. `request('GET', '/groups')`.
  /// Returns the decoded `data` field.
  Future<dynamic> request(String method, String path, {Object? body}) async {
    final req = http.Request(method.toUpperCase(), Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..headers['Accept'] = 'application/json'
      ..headers['User-Agent'] = 'waservix-dart/$waservixVersion';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final res =
        await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    Object? json;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } on FormatException {
        json = null;
      }
    }

    final map = json is Map ? json : null;
    if (res.statusCode >= 400 || map?['success'] == false) {
      final retry = res.headers['retry-after'];
      throw WAservixException(
        res.statusCode,
        map?['message'] is String
            ? map!['message'] as String
            : 'HTTP ${res.statusCode}',
        errors: map?['errors'],
        body: json ?? text,
        retryAfter: retry == null ? null : double.tryParse(retry.trim()),
      );
    }
    if (map != null && map.containsKey('data')) return map['data'];
    return json;
  }

  /// Send any message type to a number or group JID (`...@g.us`). [fields]
  /// uses the API names: text, imageUrl, videoUrl, audioUrl, documentUrl,
  /// fileName, stickerUrl, contact, location, poll, replyTo, mentions, viewOnce.
  /// Returns `{"msgId": ..., "jid": ..., "status": "in_progress"}`.
  Future<dynamic> sendMessage(String to, Map<String, Object?> fields) {
    if (to.isEmpty) {
      throw ArgumentError.value(to, 'to',
          'sendMessage: "to" is required (international number or group JID)');
    }
    final body = <String, Object?>{
      for (final e in fields.entries)
        if (e.value != null) e.key: e.value
    };
    body['to'] = to;
    return request('POST', '/send-message', body: body);
  }

  /// Send a text message.
  Future<dynamic> sendText(String to, String text) =>
      sendMessage(to, {'text': text});

  /// Send an image by URL, with an optional caption.
  Future<dynamic> sendImage(String to, String imageUrl, {String? caption}) =>
      sendMessage(to, {'imageUrl': imageUrl, 'text': caption});

  /// Send a document by URL.
  Future<dynamic> sendDocument(String to, String documentUrl,
          {String? fileName, String? caption}) =>
      sendMessage(to,
          {'documentUrl': documentUrl, 'fileName': fileName, 'text': caption});

  /// Send a location pin.
  Future<dynamic> sendLocation(String to, double latitude, double longitude,
          {String? name}) =>
      sendMessage(to, {
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          if (name != null) 'name': name,
        }
      });

  /// Status: queued, sent, delivered, read, played or failed.
  Future<dynamic> getMessageInfo(Object msgId) =>
      request('GET', '/messages/${_enc(msgId)}/info');

  /// Edit one of your own text messages (about 15 minutes after sending).
  Future<dynamic> editMessage(Object msgId, String text) =>
      request('PUT', '/messages/${_enc(msgId)}', body: {'text': text});

  /// Delete a message.
  Future<dynamic> deleteMessage(Object msgId) =>
      request('DELETE', '/messages/${_enc(msgId)}');

  /// Resend a failed message.
  Future<dynamic> resendMessage(Object msgId) =>
      request('POST', '/messages/${_enc(msgId)}/resend');

  /// Is this number on WhatsApp? Returns `{"exists": bool, "jid": ...}`.
  Future<dynamic> onWhatsApp(String phone) =>
      request('GET', '/on-whatsapp/${_enc(phone)}');

  /// connected, connecting, need_scan, disconnected, logged_out or expired.
  Future<dynamic> getStatus() => request('GET', '/status');

  /// The linked WhatsApp account.
  Future<dynamic> getUser() => request('GET', '/user');

  /// Your contacts.
  Future<dynamic> listContacts() => request('GET', '/contacts');

  /// One contact.
  Future<dynamic> getContact(String phone) =>
      request('GET', '/contacts/${_enc(phone)}');

  /// Save or rename a contact.
  Future<dynamic> saveContact(String phone, String name) =>
      request('PUT', '/contacts', body: {'phone': phone, 'name': name});

  /// Groups the number belongs to.
  Future<dynamic> listGroups() => request('GET', '/groups');

  /// Group name, participants and settings.
  Future<dynamic> getGroupMetadata(String groupJid) =>
      request('GET', '/groups/${_enc(groupJid)}/metadata');

  /// Sessions (need a personal access token, not a device key).
  Future<dynamic> listSessions() => request('GET', '/whatsapp-sessions');

  /// One session.
  Future<dynamic> getSession(Object id) =>
      request('GET', '/whatsapp-sessions/${_enc(id)}');

  /// Create a session.
  Future<dynamic> createSession(Map<String, Object?> params) =>
      request('POST', '/whatsapp-sessions', body: params);

  /// Connect a session by QR code, or by pairing code when [phone] is given.
  Future<dynamic> connectSession(Object id, {String? phone}) =>
      request('POST', '/whatsapp-sessions/${_enc(id)}/connect',
          body: phone == null
              ? {'method': 'qr'}
              : {'method': 'code', 'phone': phone});

  /// QR code for linking the number.
  Future<dynamic> getSessionQrCode(Object id) =>
      request('GET', '/whatsapp-sessions/${_enc(id)}/qrcode');

  /// Close the underlying HTTP client (only if this instance created it).
  void close() {
    if (_ownsClient) _http.close();
  }

  /// Constant-time check of the `X-Webhook-Signature` header against your
  /// device's webhook secret.
  static bool verifyWebhook(String? signature, String secret) {
    if (signature == null || signature.isEmpty || secret.isEmpty) return false;
    final a = utf8.encode(signature), b = utf8.encode(secret);
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String _enc(Object value) => Uri.encodeComponent('$value');
}
