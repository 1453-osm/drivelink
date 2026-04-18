import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

class GroqModelInfo {
  const GroqModelInfo({
    required this.id,
    required this.displayName,
    this.ownedBy,
    this.contextWindow,
    this.maxCompletionTokens,
    this.active = true,
  });

  final String id;
  final String displayName;
  final String? ownedBy;
  final int? contextWindow;
  final int? maxCompletionTokens;
  final bool active;
}

/// Cloud LLM client using the Groq OpenAI-compatible chat completions API.
class GroqSource {
  GroqSource();

  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _chatUrl = '$_baseUrl/chat/completions';
  static const String _modelsUrl = '$_baseUrl/models';
  static const Duration _timeout = Duration(seconds: 15);
  static const String defaultModel = 'llama-3.3-70b-versatile';

  String? _apiKey;
  String _selectedModel = defaultModel;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  String get selectedModel => _selectedModel;

  void setApiKey(String key) {
    _apiKey = key.trim().isEmpty ? null : key.trim();
  }

  void setModel(String model) {
    final normalized = model.trim();
    if (normalized.isNotEmpty) {
      _selectedModel = normalized;
    }
  }

  Future<List<GroqModelInfo>> listAvailableModels() async {
    if (!isConfigured) return const [];

    try {
      final response = await http
          .get(Uri.parse(_modelsUrl), headers: _headers())
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[Groq] Model list HTTP ${response.statusCode}: ${response.body}',
        );
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawModels = json['data'] as List<dynamic>? ?? const [];
      final models = <GroqModelInfo>[];

      for (final raw in rawModels.whereType<Map<String, dynamic>>()) {
        final info = _parseModel(raw);
        if (info != null) models.add(info);
      }

      models.sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
      return models;
    } on TimeoutException {
      debugPrint('[Groq] Model list timeout');
      return const [];
    } catch (e) {
      debugPrint('[Groq] Model list error: $e');
      return const [];
    }
  }

  /// Test the selected model. Returns null on success, error message on failure.
  Future<String?> testConnection({String? model}) async {
    if (!isConfigured) return 'API anahtari girilmedi';

    try {
      final response = await http
          .post(
            Uri.parse(_chatUrl),
            headers: _headers(),
            body: jsonEncode({
              'model': _resolveModel(model),
              'messages': [
                {'role': 'user', 'content': 'Merhaba'},
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) return null;
      if (response.statusCode == 401) return 'Gecersiz API anahtari';
      if (response.statusCode == 404) return 'Model bulunamadi';
      if (response.statusCode == 429) return 'Istek limiti asildi, bekleyin';
      if (response.statusCode == 400) return 'Model secimi hatali';
      debugPrint(
        '[Groq] Test error ${response.statusCode}: ${response.body}',
      );
      return 'Hata: ${response.statusCode}';
    } on TimeoutException {
      return 'Baglanti zaman asimi';
    } catch (e) {
      return 'Baglanti hatasi: $e';
    }
  }

  /// Generate a response using Groq with vehicle context and history.
  Future<String> generate(
    String userQuery, {
    VehicleState? vehicleState,
    ObdData? obdData,
    String vehicleName = 'Peugeot 206',
    List<({String user, String assistant})> history = const [],
    String? model,
  }) async {
    if (!isConfigured) return '';

    final systemPrompt = _buildSystemPrompt(vehicleState, obdData, vehicleName);
    final messages = _buildMessages(systemPrompt, userQuery, history);

    try {
      final response = await http
          .post(
            Uri.parse(_chatUrl),
            headers: _headers(),
            body: jsonEncode({
              'model': _resolveModel(model),
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 150,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      }
      debugPrint('[Groq] HTTP ${response.statusCode}: ${response.body}');
      return '';
    } on TimeoutException {
      debugPrint('[Groq] Timeout');
      return '';
    } catch (e) {
      debugPrint('[Groq] Error: $e');
      return '';
    }
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
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
        ? 'ogleden sonra'
        : 'aksam';

    final sb = StringBuffer();

    sb.writeln('Sen Abidin. Bir arac asistansin ama once bir yol arkadasisin.');
    sb.writeln('');
    sb.writeln('KISILIGIN:');
    sb.writeln('- Samimi, sicak, esprili bir abisi/kankasi gibisin');
    sb.writeln(
      '- "kanka", "reis", "birader", "abi", "moruk" gibi hitaplar kullanirsin, karisik ve dogal',
    );
    sb.writeln(
      '- Sokak agziyla konusursun ama kufur/argo yok, temiz bir samimiyet',
    );
    sb.writeln(
      '- Esprili yorumlar yaparsin: hiz yuksekse "ucak mi bu reis?", soguksa "ayaz kesiyor disarida"',
    );
    sb.writeln(
      '- Her konuda muhabbet edebilirsin: futbol, yemek, hayat, muzik, teknoloji, ne sorulursa',
    );
    sb.writeln(
      '- Sohbeti sen de baslatabilirsin: verilere bakarak "hava bugun kac derece biliyor musun?" gibi',
    );
    sb.writeln('');
    sb.writeln('KONUSMA TARZI:');
    sb.writeln('- Kisa ve oz: 1-3 cumle, uzatma');
    sb.writeln('- Dogal Turkce, yazi dili degil konusma dili');
    sb.writeln('- Arac verilerini eglenceli yorumla, kuru rakam okuma');
    sb.writeln('- Tehlike varsa espriyi birak ciddi uyar');
    sb.writeln('');

    sb.writeln('Arac: $vehicleName');
    sb.writeln('Vakit: $timeContext');

    final data = <String>[];
    if (vs?.externalTemp != null) {
      data.add('Dis sicaklik: ${vs!.externalTemp!.toStringAsFixed(0)}\u00b0C');
    }
    if (obd?.coolantTemp != null) {
      data.add('Motor: ${obd!.coolantTemp!.toStringAsFixed(0)}\u00b0C');
    }
    if (obd?.speed != null || vs?.speed != null) {
      final spd = obd?.speed ?? vs?.speed;
      data.add('Hiz: ${spd!.toStringAsFixed(0)} km/h');
    }
    if (obd?.rpm != null || vs?.rpm != null) {
      final rpm = obd?.rpm ?? vs?.rpm;
      data.add('Devir: ${rpm!.toStringAsFixed(0)} RPM');
    }
    if (obd?.fuelRate != null) {
      data.add('Yakit: ${obd!.fuelRate!.toStringAsFixed(1)} L/100km');
    }
    if (obd?.batteryVoltage != null) {
      data.add('Aku: ${obd!.batteryVoltage!.toStringAsFixed(1)}V');
    }
    if (data.isNotEmpty) {
      sb.writeln('Canli arac verileri: ${data.join(", ")}');
    } else {
      sb.writeln('Arac verileri: bagli degil');
    }

    return sb.toString();
  }

  List<Map<String, String>> _buildMessages(
    String systemPrompt,
    String userQuery,
    List<({String user, String assistant})> history,
  ) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

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
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return '';

      final choice = choices.first;
      if (choice is! Map<String, dynamic>) return '';

      final message = choice['message'];
      if (message is! Map<String, dynamic>) return '';

      final content = message['content'];
      if (content is String) return content.trim();
      return '';
    } catch (e) {
      debugPrint('[Groq] Parse error: $e');
      return '';
    }
  }

  GroqModelInfo? _parseModel(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;

    final active = json['active'];
    final isActive = active is bool ? active : true;

    return GroqModelInfo(
      id: id,
      displayName: id,
      ownedBy: (json['owned_by'] ?? '').toString().trim(),
      contextWindow: _asInt(json['context_window']),
      maxCompletionTokens: _asInt(json['max_completion_tokens']),
      active: isActive,
    );
  }

  String _resolveModel(String? overrideModel) {
    final normalized = overrideModel?.trim() ?? '';
    return normalized.isEmpty ? _selectedModel : normalized;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
