import 'dart:math' as math;

// ---------------------------------------------------------------------------
// String extensions
// ---------------------------------------------------------------------------
extension StringX on String {
  /// Capitalise the first character.
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Title-case every word.
  String get titleCase =>
      split(' ').map((w) => w.capitalised).join(' ');

  /// Parse hex string to int (e.g. "0F" -> 15).
  int? get hexToInt => int.tryParse(this, radix: 16);

  /// Check if the string looks like a valid OBD response (hex pairs).
  bool get isObdResponse => RegExp(r'^[0-9A-Fa-f\s]+$').hasMatch(trim());

  /// Remove all whitespace.
  String get stripped => replaceAll(RegExp(r'\s+'), '');

  /// Truncate to [maxLen] with optional [ellipsis].
  String truncate(int maxLen, {String ellipsis = '...'}) {
    if (length <= maxLen) return this;
    return '${substring(0, maxLen - ellipsis.length)}$ellipsis';
  }

  /// Safe substring that never throws.
  String safeSubstring(int start, [int? end]) {
    final s = start.clamp(0, length);
    final e = (end ?? length).clamp(s, length);
    return substring(s, e);
  }

  /// Parse OBD hex response bytes into a list of ints.
  /// "41 0C 1A F8" => [0x41, 0x0C, 0x1A, 0xF8]
  List<int> get obdBytes =>
      stripped
          .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
          .let((s) {
        final result = <int>[];
        for (var i = 0; i + 1 < s.length; i += 2) {
          result.add(int.parse(s.substring(i, i + 2), radix: 16));
        }
        return result;
      });
}

// ---------------------------------------------------------------------------
// Num extensions
// ---------------------------------------------------------------------------
extension NumX on num {
  /// Convert Celsius to Fahrenheit.
  double get celsiusToFahrenheit => (this * 9 / 5) + 32;

  /// Convert Fahrenheit to Celsius.
  double get fahrenheitToCelsius => (this - 32) * 5 / 9;

  /// Convert km/h to mph.
  double get kmhToMph => this * 0.621371;

  /// Convert mph to km/h.
  double get mphToKmh => this * 1.60934;

  /// Convert metres to kilometres.
  double get mToKm => this / 1000;

  /// Convert km to metres.
  double get kmToM => this * 1000;

  /// Convert m/s to km/h.
  double get mpsToKmh => this * 3.6;

  /// Convert km/h to m/s.
  double get kmhToMps => this / 3.6;

  /// Convert litres/100km to km/l.
  double get lPer100KmToKmPerL => this == 0 ? 0 : 100 / this;

  /// Clamp to [0, 1] range.
  double get normalized => toDouble().clamp(0.0, 1.0);

  /// Format as rpm string "3,250 RPM".
  String get rpmFormatted {
    final val = toInt();
    final thousands = val ~/ 1000;
    final remainder = (val % 1000).toString().padLeft(3, '0');
    if (thousands > 0) return '$thousands,$remainder';
    return '$val';
  }

  /// Format as temperature "85 C".
  String tempFormatted({bool fahrenheit = false}) {
    if (fahrenheit) {
      return '${celsiusToFahrenheit.round()} F';
    }
    return '${round()} C';
  }

  /// Format as speed "120 km/h".
  String get speedFormatted => '${round()} km/h';

  /// Linear interpolation to [other] by [t].
  double lerpTo(num other, double t) =>
      toDouble() + (other.toDouble() - toDouble()) * t;

  /// Map from [fromLow, fromHigh] range to [toLow, toHigh].
  double mapRange(
    num fromLow,
    num fromHigh,
    num toLow,
    num toHigh,
  ) {
    return toLow +
        (toDouble() - fromLow) * (toHigh - toLow) / (fromHigh - fromLow);
  }

  /// Round to [decimals] places.
  double roundTo(int decimals) {
    final fac = math.pow(10, decimals);
    return (this * fac).round() / fac;
  }
}

// ---------------------------------------------------------------------------
// Int extensions
// ---------------------------------------------------------------------------
extension IntX on int {
  /// Convert an OBD byte pair (A, B) encoded RPM to actual RPM.
  /// RPM = ((A * 256) + B) / 4
  double obdRpm(int b) => (this * 256 + b) / 4.0;

  /// Hex string with optional padding.
  String toHexString({int pad = 2}) =>
      toRadixString(16).toUpperCase().padLeft(pad, '0');

  /// Duration from milliseconds.
  Duration get ms => Duration(milliseconds: this);

  /// Duration from seconds.
  Duration get seconds => Duration(seconds: this);

  /// Duration from minutes.
  Duration get minutes => Duration(minutes: this);
}

// ---------------------------------------------------------------------------
// Double extensions
// ---------------------------------------------------------------------------
extension DoubleX on double {
  /// Degrees to radians.
  double get toRadians => this * math.pi / 180;

  /// Radians to degrees.
  double get toDegrees => this * 180 / math.pi;

  /// Format with fixed decimal places, stripping trailing zeros.
  String toCleanString(int decimals) {
    final s = toStringAsFixed(decimals);
    if (!s.contains('.')) return s;
    var trimmed = s;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

// ---------------------------------------------------------------------------
// Duration extensions
// ---------------------------------------------------------------------------
extension DurationX on Duration {
  /// Format as "mm:ss" or "hh:mm:ss".
  String get formatted {
    final h = inHours;
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  /// Human-readable Turkish duration: "2 saat 15 dakika".
  String get humanReadableTr {
    final h = inHours;
    final m = inMinutes.remainder(60);
    if (h > 0 && m > 0) return '$h saat $m dakika';
    if (h > 0) return '$h saat';
    if (m > 0) return '$m dakika';
    return '${inSeconds} saniye';
  }
}

// ---------------------------------------------------------------------------
// DateTime extensions
// ---------------------------------------------------------------------------
extension DateTimeX on DateTime {
  /// Format as "HH:mm".
  String get timeFormatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Format as "dd.MM.yyyy".
  String get dateFormatted =>
      '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';

  /// Format as "dd.MM.yyyy HH:mm".
  String get dateTimeFormatted => '$dateFormatted $timeFormatted';
}

// ---------------------------------------------------------------------------
// List<int> extensions (for byte processing)
// ---------------------------------------------------------------------------
extension ByteListX on List<int> {
  /// Convert byte list to hex string with spaces: "41 0C 1A".
  String get toHexString =>
      map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');

  /// Decode two bytes as unsigned 16-bit big-endian.
  int uint16BE(int offset) {
    if (offset + 1 >= length) return 0;
    return (this[offset] << 8) | this[offset + 1];
  }
}

// ---------------------------------------------------------------------------
// Scope function (Kotlin-style let)
// ---------------------------------------------------------------------------
extension LetX<T> on T {
  /// Kotlin-style let: transform and return.
  R let<R>(R Function(T it) block) => block(this);
}
