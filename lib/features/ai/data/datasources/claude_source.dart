import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

/// Cloud LLM client using Anthropic Claude API.
class ClaudeSource {
  ClaudeSource();

  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-6';
  static const String _apiVersion = '2023-06-01';
  static const Duration _timeout = Duration(seconds: 15);

  String? _apiKey;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void setApiKey(String key) {
    _apiKey = key.trim().isEmpty ? null : key.trim();
  }

  /// Test the API key. Returns null on success, error message on failure.
  Future<String?> testConnection() async {
    if (!isConfigured) return 'API anahtari girilmedi';

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: _headers(),
            body: jsonEncode({
              'model': _model,
              'max_tokens': 10,
              'messages': [
                {'role': 'user', 'content': 'Merhaba'}
              ],
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) return null;
      if (response.statusCode == 401) return 'Gecersiz API anahtari';
      if (response.statusCode == 429) return 'Istek limiti asildi, bekleyin';
      debugPrint('[Claude] Test error ${response.statusCode}: ${response.body}');
      return 'Hata: ${response.statusCode}';
    } on TimeoutException {
      return 'Baglanti zaman asimi';
    } catch (e) {
      return 'Baglanti hatasi: $e';
    }
  }

  /// Generate a response using Claude API.
  Future<String> generate(
    String userQuery, {
    VehicleState? vehicleState,
    ObdData? obdData,
    String vehicleName = 'Peugeot 206',
    List<({String user, String assistant})> history = const [],
  }) async {
    if (!isConfigured) return '';

    final systemPrompt =
        _buildSystemPrompt(vehicleState, obdData, vehicleName);
    final messages = _buildMessages(userQuery, history);

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: _headers(),
            body: jsonEncode({
              'model': _model,
              'max_tokens': 200,
              'system': systemPrompt,
              'messages': messages,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[Claude] HTTP ${response.statusCode}');
        return '';
      }

      return _parseResponse(response.body);
    } on TimeoutException {
      debugPrint('[Claude] Timeout');
      return '';
    } catch (e) {
      debugPrint('[Claude] Error: $e');
      return '';
    }
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey!,
        'anthropic-version': _apiVersion,
      };

  String _buildSystemPrompt(
    VehicleState? vs,
    ObdData? obd,
    String vehicleName,
  ) {
    final hour = DateTime.now().hour;
    final timeContext = hour < 6
        ? 'gece'
        : hour < 12
            ? 'sabah'
            : hour < 18
                ? '\u00f6\u011fleden sonra'
                : 'ak\u015fam';

    final sb = StringBuffer();

    sb.writeln('Sen Abidin. Bir ara\u00e7 asistan\u0131s\u0131n ama \u00f6nce bir yol arkada\u015f\u0131s\u0131n.');
    sb.writeln('');
    sb.writeln('K\u0130\u015e\u0130L\u0130\u011e\u0130N:');
    sb.writeln('- Samimi, s\u0131cak, esprili bir abisi/kankasi gibisin');
    sb.writeln('- "kanka", "reis", "birader", "abi", "moruk" gibi hitaplar kullan\u0131rs\u0131n, kar\u0131\u015f\u0131k ve do\u011fal');
    sb.writeln('- Sokak a\u011fz\u0131yla konu\u015fursun ama k\u00fcf\u00fcr/argo yok, temiz bir samimiyet');
    sb.writeln('- Esprili yorumlar yapars\u0131n: h\u0131z y\u00fcksekse "u\u00e7ak m\u0131 bu reis?", so\u011fuksa "ayaz kesiyor d\u0131\u015far\u0131da"');
    sb.writeln('- Her konuda muhabbet edebilirsin: futbol, yemek, hayat, m\u00fczik, teknoloji, ne sorulursa');
    sb.writeln('- Sohbeti sen de ba\u015flatabilirsin: verilere bakarak "hava bug\u00fcn ka\u00e7 derece biliyor musun?" gibi');
    sb.writeln('');
    sb.writeln('KONUSMA TARZI:');
    sb.writeln('- K\u0131sa ve \u00f6z: 1-3 c\u00fcmle, uzatma');
    sb.writeln('- Do\u011fal T\u00fcrk\u00e7e, yaz\u0131 dili de\u011fil konu\u015fma dili');
    sb.writeln('- Arac verilerini e\u011flenceli yorumla, kuru rakam okuma');
    sb.writeln('- Tehlike varsa espriyi b\u0131rak ciddi uyar');
    sb.writeln('');
    sb.writeln('Ara\u00e7: $vehicleName');
    sb.writeln('Vakit: $timeContext');

    final data = <String>[];
    if (vs?.externalTemp != null) {
      data.add('D\u0131\u015f: ${vs!.externalTemp!.toStringAsFixed(0)}\u00b0C');
    }
    if (obd?.coolantTemp != null) {
      data.add('Motor: ${obd!.coolantTemp!.toStringAsFixed(0)}\u00b0C');
    }
    if (obd?.speed != null || vs?.speed != null) {
      final spd = obd?.speed ?? vs?.speed;
      data.add('H\u0131z: ${spd!.toStringAsFixed(0)} km/h');
    }
    if (obd?.rpm != null || vs?.rpm != null) {
      final rpm = obd?.rpm ?? vs?.rpm;
      data.add('Devir: ${rpm!.toStringAsFixed(0)} RPM');
    }
    if (obd?.fuelRate != null) {
      data.add('Yak\u0131t: ${obd!.fuelRate!.toStringAsFixed(1)} L/100km');
    }
    if (obd?.batteryVoltage != null) {
      data.add('Ak\u00fc: ${obd!.batteryVoltage!.toStringAsFixed(1)}V');
    }
    if (data.isNotEmpty) {
      sb.writeln('Canl\u0131 ara\u00e7 verileri: ${data.join(", ")}');
    } else {
      sb.writeln('Ara\u00e7 verileri: ba\u011fl\u0131 de\u011fil');
    }

    return sb.toString();
  }

  List<Map<String, String>> _buildMessages(
    String userQuery,
    List<({String user, String assistant})> history,
  ) {
    final messages = <Map<String, String>>[];
    for (final turn in history) {
      messages.add({'role': 'user', 'content': turn.user});
      messages.add({'role': 'assistant', 'content': turn.assistant});
    }
    messages.add({'role': 'user', 'content': userQuery});
    return messages;
  }

  String _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final content = json['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) return '';
      return (content[0]['text'] ?? '').toString().trim();
    } catch (e) {
      debugPrint('[Claude] Parse error: $e');
      return '';
    }
  }
}
