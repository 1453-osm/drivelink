import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

class OpenRouterModelInfo {
  const OpenRouterModelInfo({
    required this.id,
    required this.displayName,
    this.description,
    this.contextLength,
    this.promptPrice = 0,
    this.completionPrice = 0,
    this.requestPrice = 0,
  });

  final String id;
  final String displayName;
  final String? description;
  final int? contextLength;
  final double promptPrice;
  final double completionPrice;
  final double requestPrice;

  bool get isFree =>
      promptPrice == 0 && completionPrice == 0 && requestPrice == 0;
}

/// Cloud LLM client using the OpenRouter chat completions API.
class OpenRouterSource {
  OpenRouterSource();

  static const String _chatUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _modelsUrl = 'https://openrouter.ai/api/v1/models';
  static const Duration _timeout = Duration(seconds: 15);
  static const String defaultModel = 'openrouter/free';

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

  Future<List<OpenRouterModelInfo>> listAvailableModels() async {
    if (!isConfigured) return const [];

    try {
      final response = await http
          .get(Uri.parse(_modelsUrl), headers: _headers())
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[OpenRouter] Model list HTTP ${response.statusCode}: ${response.body}',
        );
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawModels = json['data'] as List<dynamic>? ?? const [];
      final byId = <String, OpenRouterModelInfo>{};

      for (final raw in rawModels.whereType<Map<String, dynamic>>()) {
        final info = _parseModel(raw);
        if (info != null) {
          byId[info.id] = info;
        }
      }

      final models = byId.values.toList()..sort(_compareModels);
      return models;
    } on TimeoutException {
      debugPrint('[OpenRouter] Model list timeout');
      return const [];
    } catch (e) {
      debugPrint('[OpenRouter] Model list error: $e');
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
      if (response.statusCode == 402) {
        return 'OpenRouter bakiyesi veya odeme yontemi gerekli';
      }
      if (response.statusCode == 404) return 'Model bulunamadi';
      if (response.statusCode == 429) return 'Istek limiti asildi, bekleyin';
      debugPrint(
        '[OpenRouter] Test error ${response.statusCode}: ${response.body}',
      );
      return 'Hata: ${response.statusCode}';
    } on TimeoutException {
      return 'Baglanti zaman asimi';
    } catch (e) {
      return 'Baglanti hatasi: $e';
    }
  }

  /// Generate a response using OpenRouter with vehicle context and history.
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
      debugPrint('[OpenRouter] HTTP ${response.statusCode}: ${response.body}');
      return '';
    } on TimeoutException {
      debugPrint('[OpenRouter] Timeout');
      return '';
    } catch (e) {
      debugPrint('[OpenRouter] Error: $e');
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
    sb.writeln('ARAC VERISI YORUMLAMA ORNEKLERI:');
    sb.writeln('- Hiz 120+ ise: "Yavas reis, Formula 1 degil burasi!"');
    sb.writeln(
      '- Motor 95\u00b0C+ ise: "Birader motor kizdi, mola ver yoksa piser"',
    );
    sb.writeln(
      '- Dis sicaklik 0\u00b0C alti: "Ayi sogugu var disarida, dikkat et buzlanma olabilir"',
    );
    sb.writeln('- Aku dusuk: "Aku bitmek uzere kanka, sarj lazim"');
    sb.writeln('- Normal hiz: "Guzel tempo, boyle devam"');
    sb.writeln('');

    sb.writeln('Arac: $vehicleName');
    sb.writeln('Vakit: $timeContext');

    final data = <String>[];
    if (vs?.externalTemp != null) {
      data.add(
        'Dis sicaklik: ${vs!.externalTemp!.toStringAsFixed(0)}\u00b0C',
      );
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
      if (content is List<dynamic>) {
        return content
            .whereType<Map<String, dynamic>>()
            .map((part) => (part['text'] ?? '').toString())
            .join()
            .trim();
      }
      return '';
    } catch (e) {
      debugPrint('[OpenRouter] Parse error: $e');
      return '';
    }
  }

  OpenRouterModelInfo? _parseModel(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    if (id.isEmpty || !_isTextCapableModel(json, id)) return null;

    final pricing = json['pricing'] as Map<String, dynamic>? ?? const {};
    final promptPrice = _asDouble(pricing['prompt']) ?? 0;
    final completionPrice = _asDouble(pricing['completion']) ?? 0;
    final requestPrice = _asDouble(pricing['request']) ?? 0;
    final isPinned = _isPinnedModel(id);
    final isFree =
        id == defaultModel ||
        id.endsWith(':free') ||
        (promptPrice == 0 && completionPrice == 0 && requestPrice == 0);
    if (!isFree && !isPinned) return null;

    final name = (json['name'] ?? '').toString().trim();
    return OpenRouterModelInfo(
      id: id,
      displayName: name.isEmpty ? id : name,
      description: (json['description'] ?? '').toString().trim(),
      contextLength: _asInt(json['context_length']),
      promptPrice: promptPrice,
      completionPrice: completionPrice,
      requestPrice: requestPrice,
    );
  }

  bool _isTextCapableModel(Map<String, dynamic> json, String id) {
    final lowerId = id.toLowerCase();
    const blockedFragments = [
      'embedding',
      'moderation',
      'rerank',
      'image',
      'speech',
      'tts',
      'transcribe',
      'whisper',
    ];
    if (blockedFragments.any(lowerId.contains)) return false;

    final architecture = json['architecture'];
    if (architecture is Map<String, dynamic>) {
      final modality = (architecture['modality'] ?? '').toString().toLowerCase();
      final outputModalities =
          (architecture['output_modalities'] as List<dynamic>? ?? const [])
              .map((item) => item.toString().toLowerCase())
              .toSet();
      if (outputModalities.isNotEmpty) {
        return outputModalities.contains('text');
      }
      if (modality.isNotEmpty) {
        return modality.contains('text');
      }
    }

    return true;
  }

  int _compareModels(OpenRouterModelInfo a, OpenRouterModelInfo b) {
    final priorityDiff = _priority(a.id).compareTo(_priority(b.id));
    if (priorityDiff != 0) return priorityDiff;

    final freeDiff = b.isFree == a.isFree ? 0 : (a.isFree ? -1 : 1);
    if (freeDiff != 0) return freeDiff;

    final nameA = a.displayName.toLowerCase();
    final nameB = b.displayName.toLowerCase();
    return nameA.compareTo(nameB);
  }

  int _priority(String modelId) {
    final lower = modelId.toLowerCase();
    if (lower.contains('grok')) return 0;
    if (lower.contains('qwen')) return 1;
    if (lower == defaultModel) return 2;
    return 3;
  }

  bool _isPinnedModel(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('grok') || lower.contains('qwen');
  }

  String _resolveModel(String? overrideModel) {
    final normalized = overrideModel?.trim() ?? '';
    return normalized.isEmpty ? _selectedModel : normalized;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
