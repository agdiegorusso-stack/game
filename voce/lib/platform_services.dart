import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'domain.dart';

class Device {
  static const channel = MethodChannel('it.diegorusso.voce/device');
  static Future<String?> read(String key) =>
      channel.invokeMethod<String>('read', {'key': key});
  static Future<void> write(String key, String value) =>
      channel.invokeMethod('write', {'key': key, 'value': value});
  static Future<String?> sharedText() =>
      channel.invokeMethod<String>('sharedText');
  static Future<void> open(String url) =>
      channel.invokeMethod('open', {'url': url});
}

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class Api {
  String base = '';
  String token = '';
  bool get configured => base.isNotEmpty && token.isNotEmpty;
  static bool validBase(String value) {
    final u = Uri.tryParse(value);
    if (u == null ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        u.hasQuery ||
        u.hasFragment)
      return false;
    return u.scheme == 'https' ||
        (u.scheme == 'http' &&
            ['localhost', '127.0.0.1', '10.0.2.2'].contains(u.host));
  }

  Future<Json> call(String path, {Json? data}) async {
    if (!configured)
      throw ApiException(
        'Configura indirizzo e chiave del tuo server nella sezione Profilo.',
      );
    if (!validBase(base)) throw ApiException('Usa un indirizzo HTTPS valido.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}$path');
      final request = await client
          .openUrl(data == null ? 'GET' : 'POST', uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (data != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(data));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final bytes = <int>[];
      await for (final part in response.timeout(const Duration(seconds: 90))) {
        bytes.addAll(part);
        if (bytes.length > 2 * 1024 * 1024)
          throw ApiException('Risposta troppo grande.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>)
        throw ApiException('Risposta del server non valida.');
      if (response.statusCode >= 300)
        throw ApiException(
          (decoded['error'] ?? 'Errore del server').toString(),
          response.statusCode,
        );
      return decoded;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(
        'Server non raggiungibile. Verifica connessione e indirizzo.',
      );
    } on FormatException {
      throw ApiException('Il server non ha restituito dati validi.');
    } catch (_) {
      throw ApiException(
        'Connessione interrotta o richiesta scaduta. Riprova.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
