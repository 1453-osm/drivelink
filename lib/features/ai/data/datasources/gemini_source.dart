import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

class GeminiModelInfo {
  const GeminiModelInfo({
    required this.id,
    required this.displayName,
    this.description,
    this.inputTokenLimit,
    this.outputTokenLimit,
    this.supportsThinking = false,
  });

  final String id;
  final String displayName;
  final String? description;
  final int? inputTokenLimit;
  final int? outputTokenLimit;
  final bool supportsThinking;
}

/// Cloud LLM client using the Google Gemini API.
class GeminiSource {
  GeminiSource();

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const Duration _timeout = Duration(seconds: 10);
  static const String defaultModel = 'gemini-2.5-flash-lite';

  String? _apiKey;
  String _selectedModel = defaultModel;

  // Public API

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

  Future<List<GeminiModelInfo>> listAvailableModels() async {
    if (!isConfigured) return const [];

    final byId = <String, GeminiModelInfo>{};
    String? nextPageToken;

    do {
      final uri = Uri.parse('$_baseUrl/models').replace(
        queryParameters: {
          'key': _apiKey,
          'pageSize': '1000',
          if (nextPageToken != null && nextPageToken.isNotEmpty)
            'pageToken': nextPageToken,
        },
      );

      try {
        final response = await http.get(uri).timeout(_timeout);
        if (response.statusCode != 200) {
          debugPrint(
            '[Gemini] Model list HTTP ${response.statusCode}: ${response.body}',
          );
          return const [];
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rawModels = json['models'] as List<dynamic>? ?? const [];

        for (final raw in rawModels.whereType<Map<String, dynamic>>()) {
          final info = _parseModel(raw);
          if (info != null) {
            byId[info.id] = info;
          }
        }

        final token = (json['nextPageToken'] ?? '').toString().trim();
        nextPageToken = token.isEmpty ? null : token;
      } on TimeoutException {
        debugPrint('[Gemini] Model list timeout');
        return const [];
      } catch (e) {
        debugPrint('[Gemini] Model list error: $e');
        return const [];
      }
    } while (nextPageToken != null);

    final models = byId.values.toList()
      ..sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
    return models;
  }

  /// Test the selected model. Returns null on success, error message on failure.
  Future<String?> testConnection({String? model}) async {
    if (!isConfigured) return 'API anahtari girilmedi';

    final targetModel = _resolveModel(model);

    try {
      final response = await http
          .post(
            Uri.parse(
              '$_baseUrl/models/$targetModel:generateContent?key=$_apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'Merhaba'},
                  ],
                },
              ],
              'generationConfig': {'maxOutputTokens': 10},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) return null;
      if (response.statusCode == 400 || response.statusCode == 403) {
        return 'API anahtari gecersiz ya da model erisimi yok';
      }
      if (response.statusCode == 404) {
        return 'Model bulunamadi veya hesabinda etkin degil';
      }
      if (response.statusCode == 429) return 'Istek limiti asildi, bekleyin';
      if (response.statusCode == 503)
        return 'Model mesgul, biraz sonra deneyin';
      return 'Hata: ${response.statusCode}';
    } on TimeoutException {
      return 'Baglanti zaman asimi';
    } catch (e) {
      return 'Baglanti hatasi: $e';
    }
  }

  /// Generate a response using Gemini API with vehicle context and history.
  ///
  /// Returns empty string on any failure (timeout, HTTP error, no API key).
  Future<String> generate(
    String userQuery, {
    VehicleState? vehicleState,
    ObdData? obdData,
    String vehicleName = 'Peugeot 206',
    List<({String user, String assistant})> history = const [],
    String? model,
  }) async {
    if (!isConfigured) return '';

    final targetModel = _resolveModel(model);
    final systemPrompt = _buildSystemPrompt(vehicleState, obdData, vehicleName);
    final contents = _buildContents(userQuery, history);
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.9,
        'maxOutputTokens': 150,
      },
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '$_baseUrl/models/$targetModel:generateContent?key=$_apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      }
      debugPrint('[Gemini] $targetModel HTTP ${response.statusCode}');
      return '';
    } on TimeoutException {
      debugPrint('[Gemini] $targetModel timeout');
      return '';
    } catch (e) {
      debugPrint('[Gemini] Error: $e');
      return '';
    }
  }

  // Prompt construction

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

    // Abidin persona
    sb.writeln(
      'Sen Abidin. Bir ara\u00e7 asistan\u0131s\u0131n ama \u00f6nce bir yol arkada\u015f\u0131s\u0131n.',
    );
    sb.writeln('');
    sb.writeln('K\u0130\u015e\u0130L\u0130\u011e\u0130N:');
    sb.writeln('- Samimi, s\u0131cak, esprili bir abisi/kankasi gibisin');
    sb.writeln(
      '- "kanka", "reis", "birader", "abi", "moruk" gibi hitaplar kullan\u0131rs\u0131n, kar\u0131\u015f\u0131k ve do\u011fal',
    );
    sb.writeln(
      '- Sokak a\u011fz\u0131yla konu\u015fursun ama k\u00fcf\u00fcr/argo yok, temiz bir samimiyet',
    );
    sb.writeln(
      '- Esprili yorumlar yapars\u0131n: h\u0131z y\u00fcksekse "u\u00e7ak m\u0131 bu reis?", so\u011fuksa "ayaz kesiyor d\u0131\u015far\u0131da"',
    );
    sb.writeln(
      '- Her konuda muhabbet edebilirsin: futbol, yemek, hayat, m\u00fczik, teknoloji, ne sorulursa',
    );
    sb.writeln(
      '- Sohbeti sen de ba\u015flatabilirsin: verilere bakarak "hava bug\u00fcn ka\u00e7 derece biliyor musun?" gibi',
    );
    sb.writeln('');
    sb.writeln('KONUSMA TARZI:');
    sb.writeln('- K\u0131sa ve \u00f6z: 1-3 c\u00fcmle, uzatma');
    sb.writeln(
      '- Do\u011fal T\u00fcrk\u00e7e, yaz\u0131 dili de\u011fil konu\u015fma dili',
    );
    sb.writeln('- Arac verilerini e\u011flenceli yorumla, kuru rakam okuma');
    sb.writeln('- Tehlike varsa espriyi b\u0131rak ciddi uyar');
    sb.writeln('');
    sb.writeln('ARAC VER\u0130S\u0130 YORUMLAMA \u00d6RNEKLER\u0130:');
    sb.writeln(
      '- H\u0131z 120+ ise: "Yava\u015f reis, Formula 1 de\u011fil buras\u0131!"',
    );
    sb.writeln(
      '- Motor 95\u00b0C+ ise: "Birader motor k\u0131zd\u0131, mola ver yoksa pi\u015fer"',
    );
    sb.writeln(
      '- D\u0131\u015f s\u0131cakl\u0131k 0\u00b0C alt\u0131: "Ay\u0131 so\u011fu\u011fu var d\u0131\u015far\u0131da, dikkat et buzlanma olabilir"',
    );
    sb.writeln(
      '- Ak\u00fc d\u00fc\u015f\u00fck: "Ak\u00fc bitmek \u00fczere kanka, \u015farj laz\u0131m"',
    );
    sb.writeln('- Normal h\u0131z: "G\u00fczel tempo, b\u00f6yle devam"');
    sb.writeln('');

    // Context
    sb.writeln('Ara\u00e7: $vehicleName');
    sb.writeln('Vakit: $timeContext');

    // Vehicle data
    final data = <String>[];
    if (vs?.externalTemp != null) {
      data.add(
        'D\u0131\u015f s\u0131cakl\u0131k: ${vs!.externalTemp!.toStringAsFixed(0)}\u00b0C',
      );
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

  List<Map<String, dynamic>> _buildContents(
    String userQuery,
    List<({String user, String assistant})> history,
  ) {
    final contents = <Map<String, dynamic>>[];

    // Conversation history
    for (final turn in history) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': turn.user},
        ],
      });
      contents.add({
        'role': 'model',
        'parts': [
          {'text': turn.assistant},
        ],
      });
    }

    // Current query
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userQuery},
      ],
    });

    return contents;
  }

  // Response parsing

  String _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return '';

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      if (content == null) return '';

      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return '';

      final text = (parts[0]['text'] ?? '').toString().trim();
      return text;
    } catch (e) {
      debugPrint('[Gemini] Parse error: $e');
      return '';
    }
  }

  GeminiModelInfo? _parseModel(Map<String, dynamic> json) {
    final methods =
        (json['supportedGenerationMethods'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toSet();
    if (!methods.contains('generateContent')) return null;

    final rawName = (json['name'] ?? '').toString().trim();
    var modelId = (json['baseModelId'] ?? '').toString().trim();
    if (modelId.isEmpty) {
      modelId = rawName.startsWith('models/')
          ? rawName.substring('models/'.length)
          : rawName;
    }

    if (modelId.isEmpty || !_isTextCapableModel(modelId)) {
      return null;
    }

    final displayName = (json['displayName'] ?? '').toString().trim();

    return GeminiModelInfo(
      id: modelId,
      displayName: displayName.isEmpty ? modelId : displayName,
      description: (json['description'] ?? '').toString().trim(),
      inputTokenLimit: _asInt(json['inputTokenLimit']),
      outputTokenLimit: _asInt(json['outputTokenLimit']),
      supportsThinking: json['thinking'] == true,
    );
  }

  bool _isTextCapableModel(String modelId) {
    final lower = modelId.toLowerCase();
    const blockedFragments = [
      'embedding',
      'aqa',
      'image',
      'tts',
      'native-audio',
    ];
    return !blockedFragments.any(lower.contains);
  }

  String _resolveModel(String? overrideModel) {
    final normalized = overrideModel?.trim() ?? '';
    return normalized.isEmpty ? _selectedModel : normalized;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
