import 'dart:math';

import 'package:drivelink/features/ai/domain/models/intent.dart';

/// Rule-based Turkish intent parser.
///
/// Resolves voice transcripts into structured [Intent] objects by matching
/// against a predefined keyword map. Falls back to 'AI_CHAT' when no match.
class IntentParser {
  // ── Keyword map ──────────────────────────────────────────────────────

  // Only ACTION commands that need code execution.
  // Info queries (vehicle data, general questions) go to LLM.
  static const Map<String, List<String>> _keywords = {
    // Navigasyon aksiyonlari
    'NAV_HOME': ['eve git', 'eve navigasyon', 'eve yol', 'eve surelim', 'eve gidelim'],
    'NAV_WORK': ['ise git', 'ise navigasyon', 'ofise git', 'ise gidelim'],
    'NAV_SEARCH': ['navigasyon baslat', 'yol tarifi', 'nasil giderim', 'rota olustur'],
    'NAV_STOP': ['navigasyonu kapat', 'navigasyonu durdur', 'rota iptal'],
    'NAV_NEARBY_GAS': ['en yakin benzinlik', 'benzinlik nerede', 'yakit istasyonu'],
    'NAV_NEARBY_PARKING': ['en yakin otopark', 'otopark nerede', 'park yeri'],
    'NAV_NEARBY_HOSPITAL': ['en yakin hastane', 'hastane nerede', 'hastaneye git'],
    'VEHICLE_TRIP': ['trip ekrani', 'trip bilgisi', 'yol bilgisi ekrani'],

    // Medya aksiyonlari
    'MEDIA_PLAY': ['muzik ac', 'muzik cal', 'muzigi baslat', 'sarki ac', 'sarki cal'],
    'MEDIA_PAUSE': ['muzik kapat', 'muzigi durdur', 'durdur', 'sarki kapat'],
    'MEDIA_NEXT': ['sonraki sarki', 'sonraki parca', 'degistir', 'atlat', 'sonraki'],
    'MEDIA_PREV': ['onceki sarki', 'onceki parca', 'geri al'],
    'MEDIA_VOLUME_UP': ['sesi ac', 'sesi yukselt', 'daha yuksek', 'ses yukari'],
    'MEDIA_VOLUME_DOWN': ['sesi kis', 'sesi azalt', 'daha kisik', 'ses asagi'],

    // Sistem aksiyonlari
    'SYSTEM_SCREEN_OFF': ['ekrani kapat', 'ekrani kara'],
    'SYSTEM_NIGHT_MODE': ['gece modu', 'karanlik mod'],
    'SYSTEM_DAY_MODE': ['gunduz modu', 'acik mod'],
  };

  /// Parse a transcript into an [Intent].
  Intent parse(String text) {
    if (text.trim().isEmpty) {
      return const Intent(action: 'UNKNOWN', confidence: 0);
    }

    final normalized = _normalize(text);

    String? bestAction;
    double bestScore = 0;

    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        final score = _matchScore(normalized, keyword);
        if (score > bestScore) {
          bestScore = score;
          bestAction = entry.key;
        }
      }
    }

    if (bestAction != null && bestScore >= 0.70) {
      return Intent(
        action: bestAction,
        params: _extractParams(normalized, bestAction),
        confidence: bestScore,
        source: 'rule_based',
        transcript: text,
      );
    }

    // No match → fallback to AI_CHAT
    return Intent(
      action: 'AI_CHAT',
      params: {'query': text},
      confidence: 0.5,
      source: 'fallback',
      transcript: text,
    );
  }

  // ── Text normalization ───────────────────────────────────────────────

  String _normalize(String text) {
    var s = text.toLowerCase().trim();

    const replacements = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o',
      'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u',
    };
    for (final entry in replacements.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }

    s = s.replaceAll(RegExp(r'[^\w\s]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  // ── Matching ─────────────────────────────────────────────────────────

  double _matchScore(String input, String keyword) {
    // 1. Word-boundary phrase match — keyword must appear as complete words
    // Prevents "muzik acarken" from matching "muzik ac" or
    // "sonraki adimda" from matching "sonraki"
    final escaped = RegExp.escape(keyword);
    if (RegExp('(?:^|\\s)$escaped(?:\\s|\$)').hasMatch(input)) return 1.0;

    // 2. Token-based matching — only exact token matches count
    final inputTokens = input.split(' ');
    final keyTokens = keyword.split(' ');

    if (keyTokens.isEmpty) return 0;

    int matched = 0;
    for (final kt in keyTokens) {
      if (kt.length < 2) continue; // Skip single-char tokens

      for (final it in inputTokens) {
        // Exact token match
        if (it == kt) {
          matched++;
          break;
        }
        // Allow stem match only for longer tokens (4+ chars)
        // e.g. "sicaklik" matches "sicakligi"
        if (kt.length >= 4 && it.length >= 4) {
          if (it.startsWith(kt) || kt.startsWith(it)) {
            matched++;
            break;
          }
        }
        // Fuzzy only for longer tokens (5+ chars), max 1 edit distance
        if (kt.length >= 5 && it.length >= 5) {
          if (_levenshtein(it, kt) <= 1) {
            matched++;
            break;
          }
        }
      }
    }

    final keyTokenCount = keyTokens.where((t) => t.length >= 2).length;
    if (keyTokenCount == 0) return 0;

    return matched / keyTokenCount;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> prev = List.generate(b.length + 1, (i) => i);
    List<int> curr = List.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce(min);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[b.length];
  }

  // ── Parameter extraction ─────────────────────────────────────────────

  Map<String, String> _extractParams(String text, String action) {
    final params = <String, String>{};

    switch (action) {
      case 'NAV_SEARCH':
        final patterns = [
          RegExp(r'(?:navigasyon|yol tarifi|giderim)\s+(.+)'),
          RegExp(r'(.+?)\s*(?:nasil giderim|nereye)'),
        ];
        for (final p in patterns) {
          final match = p.firstMatch(text);
          if (match != null && match.group(1)!.trim().isNotEmpty) {
            params['destination'] = match.group(1)!.trim();
            break;
          }
        }
      case 'NAV_NEARBY_GAS':
        params['poi_type'] = 'gas_station';
      case 'NAV_NEARBY_PARKING':
        params['poi_type'] = 'parking';
      case 'NAV_NEARBY_HOSPITAL':
        params['poi_type'] = 'hospital';
      case 'AI_CHAT':
        params['query'] = text;
    }

    return params;
  }
}
