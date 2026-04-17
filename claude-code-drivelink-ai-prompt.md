# DriveLink AI — Offline Araç Asistanı
# Claude Code Proje Promptu

## Vizyon
DriveLink uygulamasına tamamen offline çalışan yapay zeka asistanı entegrasyonu. Sesli komut tanıma, doğal dil anlama, araç sağlık izleme ve anomali algılama — hepsi internet olmadan, telefon üzerinde çalışacak.

## Donanım Bağlamı
- **Telefon:** Redmi 7 (Snapdragon 632, 3GB RAM, Android, rootlu)
- **Mikrofon:** Telefon dahili mikrofon
- **Hoparlör:** Araç hoparlörleri (AUX üzerinden)
- **VAN Bus:** ESP32 Beetle → USB seri → telefon (JSON veri)
- **OBD-II:** ELM327 USB → telefon (PID verileri)
- **Direksiyon:** Source tuşu → VAN bus → ESP32 → telefon (wake trigger)

## Teknik Stack
- **Framework:** Flutter 3.x (Dart)
- **Ses Tanıma:** Vosk (offline, Türkçe)
- **Wake Word:** Picovoice Porcupine (offline)
- **LLM:** Smollm 135M (llama.cpp üzerinden, 4-bit quantized)
- **Anomali Algılama:** TensorFlow Lite (TFLite)
- **TTS:** flutter_tts (Android dahili Türkçe motor)
- **Sensörler:** sensors_plus (ivmeölçer, jiroskop)

## Modül Yapısı

```
lib/features/ai/
├── presentation/
│   ├── screens/
│   │   ├── ai_assistant_screen.dart      # AI asistan tam ekran
│   │   └── ai_settings_screen.dart       # AI ayarları
│   ├── widgets/
│   │   ├── voice_indicator.dart          # Mikrofon dinleme animasyonu
│   │   ├── ai_response_card.dart         # Yanıt gösterimi
│   │   ├── wake_word_status.dart         # Wake word durumu
│   │   ├── anomaly_alert.dart            # Anomali uyarı kartı
│   │   └── driving_score_widget.dart     # Sürüş puanı
│   └── providers/
│       ├── ai_provider.dart              # Ana AI state yönetimi
│       ├── voice_provider.dart           # Ses tanıma state
│       └── anomaly_provider.dart         # Anomali algılama state
│
├── domain/
│   ├── models/
│   │   ├── intent.dart                   # Komut intent modeli
│   │   ├── ai_response.dart              # AI yanıt modeli
│   │   ├── anomaly.dart                  # Anomali modeli
│   │   ├── driving_event.dart            # Sürüş olay modeli
│   │   └── vehicle_health.dart           # Araç sağlık modeli
│   ├── repositories/
│   │   ├── voice_repository.dart         # Ses tanıma arayüzü
│   │   ├── llm_repository.dart           # LLM arayüzü
│   │   └── anomaly_repository.dart       # Anomali algılama arayüzü
│   └── usecases/
│       ├── process_voice_command.dart     # Ses komutu işleme
│       ├── detect_anomaly.dart           # Anomali tespiti
│       ├── calculate_driving_score.dart  # Sürüş puanı
│       └── predict_maintenance.dart      # Bakım tahmini
│
├── data/
│   ├── datasources/
│   │   ├── vosk_source.dart              # Vosk ses tanıma
│   │   ├── porcupine_source.dart         # Wake word algılama
│   │   ├── llm_source.dart              # Smollm llama.cpp
│   │   ├── tflite_source.dart           # TFLite anomali modeli
│   │   └── sensor_source.dart           # İvmeölçer verileri
│   ├── parsers/
│   │   ├── intent_parser.dart            # Kural tabanlı intent çözme
│   │   └── natural_language_parser.dart  # LLM ile doğal dil çözme
│   └── repositories/
│       ├── voice_repository_impl.dart
│       ├── llm_repository_impl.dart
│       └── anomaly_repository_impl.dart
│
├── native/
│   ├── android/
│   │   ├── LlamaChannel.kt              # llama.cpp platform channel
│   │   ├── VoskChannel.kt               # Vosk platform channel
│   │   └── PorcupineChannel.kt          # Porcupine platform channel
│   └── cpp/
│       ├── llama_bridge.cpp              # llama.cpp JNI bridge
│       └── CMakeLists.txt
│
└── models/                               # AI model dosyaları (assets)
    ├── vosk-model-small-tr/              # Türkçe ses tanıma (~50MB)
    ├── porcupine_drivelink.ppn           # Özel wake word modeli (~2MB)
    ├── smollm-135m-q4.gguf              # LLM model (~50MB)
    ├── anomaly_detector.tflite           # Anomali modeli (~1MB)
    └── driving_classifier.tflite         # Sürüş sınıflandırma (~1MB)
```

## Bileşen 1: Wake Word Algılama

### Picovoice Porcupine
```
Sürekli arka planda çalışır (düşük güç):
    Mikrofon → Porcupine → "abidin" algılandı mı?
    
    Hayır → devam et, bekle
    Evet  → Vosk'u aktifle, dinlemeye başla

Alternatif tetikleyici:
    VAN bus → ESP32 → {"type":"steering","button":"src","action":"press"}
    → Source tuşu basıldı → Vosk'u aktifle

İkisi birlikte:
    Ya "abidin" de
    Ya direksiyon source tuşuna bas
    İkisi de aynı pipeline'ı tetikler
```

### Konfigürasyon
```dart
class WakeWordConfig {
  static const String keyword = "abidin";
  static const double sensitivity = 0.6; // 0-1 arası, düşük = az yanlış tetikleme
  static const int audioFrameLength = 512;
  static const int sampleRate = 16000;
}
```

### Wake Word + Source Tuşu Birleşimi
```dart
class WakeWordService {
  bool _isListening = false;
  
  // Porcupine wake word callback
  void onWakeWordDetected() {
    _startVoiceRecognition();
  }
  
  // VAN bus source tuşu callback
  void onSourceButtonPressed() {
    if (_isListening) {
      _stopVoiceRecognition(); // İkinci basış → iptal
    } else {
      _startVoiceRecognition();
    }
  }
  
  void _startVoiceRecognition() {
    _isListening = true;
    // Ses tanıma başlat
    // UI'da mikrofon animasyonu göster
    // 5 saniye sessizlik → otomatik dur
  }
}
```

## Bileşen 2: Ses Tanıma (Vosk)

### Offline Türkçe Model
```
Model: vosk-model-small-tr-0.3
Boyut: ~50MB
Dil: Türkçe
Doğruluk: ~85-90% (sessiz ortamda)
Araç içi gürültü: ~70-80% (gürültü filtresi ile artırılabilir)

İndirme: https://alphacephei.com/vosk/models
```

### Gürültü Filtreleme
```dart
class AudioPreprocessor {
  // Araç içi gürültü azaltma
  
  // 1. High-pass filtre (motor gürültüsü düşük frekanslı)
  static const double highPassCutoff = 300.0; // Hz
  
  // 2. Noise gate (sessizlik eşiği)
  static const double noiseGateThreshold = -40.0; // dB
  
  // 3. AGC (Otomatik kazanç kontrolü)
  // Farklı ses seviyelerini normalize et
  
  // 4. VAD (Voice Activity Detection)
  // Sadece konuşma varken kaydet
  // Vosk'un dahili VAD'ı var
}
```

### Vosk Pipeline
```dart
class VoskService {
  late VoskRecognizer _recognizer;
  
  Future<void> initialize() async {
    // Türkçe modeli yükle
    final model = await VoskModel.create("vosk-model-small-tr");
    _recognizer = VoskRecognizer(model: model, sampleRate: 16000);
  }
  
  Stream<String> startListening() async* {
    // Mikrofon stream başlat
    // Her ses frame'ini Vosk'a gönder
    // Partial result → UI'da anlık göster
    // Final result → intent parser'a gönder
    
    // Zaman aşımı: 5 saniye sessizlik → dur
    // Maksimum dinleme: 15 saniye
  }
  
  // Araç gürültü profili öğrenme
  // İlk 3 saniye gürültü baseline al
  // Sonra bu baseline'ı çıkar
  void calibrateNoise() {
    // Motor rölanti gürültüsünü öğren
    // Yol gürültüsünü öğren
    // Adaptif filtre uygula
  }
}
```

## Bileşen 3: Intent Parser (Komut Anlama)

### Katman 1 — Kural Tabanlı (Hızlı, Güvenilir)
```dart
class IntentParser {
  
  // Anahtar kelime haritası
  static final Map<String, List<String>> keywords = {
    // Navigasyon
    'NAV_HOME': ['eve git', 'eve navigasyon', 'eve yol', 'eve sürelim'],
    'NAV_WORK': ['işe git', 'işe navigasyon', 'ofise git'],
    'NAV_SEARCH': ['navigasyon başlat', 'yol tarifi', 'nasıl giderim'],
    'NAV_STOP': ['navigasyonu kapat', 'navigasyonu durdur', 'yeter'],
    'NAV_ETA': ['ne zaman varırız', 'kalan süre', 'ne kadar kaldı'],
    'NAV_DISTANCE': ['kalan mesafe', 'ne kadar yol var'],
    'NAV_NEARBY': ['en yakın benzinlik', 'en yakın otopark', 'en yakın hastane'],
    
    // Araç bilgi
    'VEHICLE_TEMP': ['hava kaç derece', 'dışarısı kaç derece', 'sıcaklık kaç'],
    'VEHICLE_ENGINE_TEMP': ['motor sıcaklığı', 'su sıcaklığı', 'motor ısısı'],
    'VEHICLE_SPEED': ['hızım kaç', 'kaç kilometre', 'süratim'],
    'VEHICLE_FUEL': ['yakıt durumu', 'benzin ne kadar', 'depo durumu'],
    'VEHICLE_BATTERY': ['akü durumu', 'akü voltajı', 'batarya'],
    'VEHICLE_STATUS': ['araç durumu', 'araba nasıl', 'genel durum'],
    'VEHICLE_RPM': ['devir kaç', 'motor devri'],
    'VEHICLE_TRIP': ['yol bilgisi', 'trip bilgisi', 'ne kadar yol gittim'],
    
    // Medya
    'MEDIA_PLAY': ['müzik aç', 'çal', 'müziği başlat', 'şarkı aç'],
    'MEDIA_PAUSE': ['müzik kapat', 'durdur', 'pause', 'ses kapat'],
    'MEDIA_NEXT': ['sonraki şarkı', 'değiştir', 'atlat', 'next'],
    'MEDIA_PREV': ['önceki şarkı', 'geri al', 'previous'],
    'MEDIA_VOLUME_UP': ['sesi aç', 'sesi yükselt', 'daha yüksek'],
    'MEDIA_VOLUME_DOWN': ['sesi kıs', 'sesi azalt', 'daha kısık'],
    
    // Sistem
    'SYSTEM_SCREEN_OFF': ['ekranı kapat', 'ekranı kara'],
    'SYSTEM_NIGHT_MODE': ['gece modu', 'karanlık mod'],
    'SYSTEM_DAY_MODE': ['gündüz modu', 'açık mod'],
    'SYSTEM_BLUETOOTH': ['bluetooth aç', 'bluetooth kapat'],
    
    // AI Sohbet (LLM'e yönlendir)
    'AI_CHAT': ['ne demek', 'nedir', 'ne yapmalıyım', 'nasıl', 'neden'],
  };
  
  Intent parse(String text) {
    String normalized = text.toLowerCase().trim();
    
    // 1. Exact ve fuzzy keyword match
    for (var entry in keywords.entries) {
      for (var keyword in entry.value) {
        if (_fuzzyMatch(normalized, keyword)) {
          return Intent(
            action: entry.key,
            params: _extractParams(normalized, entry.key),
            confidence: _calculateConfidence(normalized, keyword),
            source: 'rule_based',
          );
        }
      }
    }
    
    // 2. Kural tabanlı eşleşme bulunamadı → LLM'e gönder
    return Intent(action: 'AI_CHAT', params: {'query': text}, source: 'fallback');
  }
  
  bool _fuzzyMatch(String input, String keyword) {
    // Levenshtein distance veya token overlap
    // "eve gidelim" ↔ "eve git" → eşleşir
    // Minimum %70 benzerlik
  }
  
  Map<String, String> _extractParams(String text, String action) {
    // "En yakın benzinlik" → {'poi_type': 'gas_station'}
    // "Ankara'ya navigasyon" → {'destination': 'Ankara'}
    // Basit entity extraction
  }
}
```

### Katman 2 — LLM ile Doğal Dil (Smollm)
```dart
class NaturalLanguageParser {
  // Kural tabanlı eşleşmeyen her şey buraya gelir
  
  // Smollm'e gönderilecek prompt
  String buildPrompt(String userQuery, VehicleState state) {
    return '''
<|system|>
Sen DriveLink araç asistanısın. Kısa ve net cevap ver. Türkçe konuş.
Araç: Peugeot 206
Mevcut araç verileri:
- Dış sıcaklık: ${state.extTemp}°C
- Motor sıcaklığı: ${state.engineTemp}°C
- Hız: ${state.speed} km/h
- Devir: ${state.rpm}
- Yakıt tüketimi: ${state.fuelRate} L/100km
- Akü voltajı: ${state.batteryVoltage}V
- Kilometre: ${state.odometer} km
<|user|>
${userQuery}
<|assistant|>
''';
  }
  
  // Yanıt sınıflandırma
  // LLM yanıtının bir aksiyon tetikleyip tetiklemeyeceğini belirle
  // "Motor yağını 10.000 km'de değiştirin" → bilgi yanıtı
  // "Navigasyonu açayım" → NAV_SEARCH aksiyonu tetikle
}
```

## Bileşen 4: Smollm LLM Entegrasyonu

### llama.cpp Android Build
```
Model: Smollm 135M (HuggingFace SmolLM-135M)
Quantization: Q4_K_M (4-bit)
Dosya boyutu: ~50MB
RAM kullanımı: ~150MB
Yanıt süresi: ~2-3 saniye (Redmi 7)
Context window: 512 token (kısa tutuyoruz)
```

### Platform Channel (Kotlin → C++)
```kotlin
// android/app/src/main/kotlin/LlamaChannel.kt

class LlamaChannel(private val flutterEngine: FlutterEngine) : MethodChannel.MethodCallHandler {
    private var llamaModel: Long = 0 // Native pointer
    
    companion object {
        init {
            System.loadLibrary("llama_bridge")
        }
    }
    
    // Native JNI methods
    external fun nativeLoadModel(modelPath: String): Long
    external fun nativeGenerate(model: Long, prompt: String, maxTokens: Int): String
    external fun nativeUnloadModel(model: Long)
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val path = call.argument<String>("path")!!
                llamaModel = nativeLoadModel(path)
                result.success(llamaModel != 0L)
            }
            "generate" -> {
                val prompt = call.argument<String>("prompt")!!
                val maxTokens = call.argument<Int>("maxTokens") ?: 128
                // Arka plan thread'de çalıştır
                thread {
                    val response = nativeGenerate(llamaModel, prompt, maxTokens)
                    Handler(Looper.getMainLooper()).post {
                        result.success(response)
                    }
                }
            }
            "unload" -> {
                nativeUnloadModel(llamaModel)
                result.success(true)
            }
        }
    }
}
```

### C++ Bridge
```cpp
// android/app/src/main/cpp/llama_bridge.cpp

#include <jni.h>
#include "llama.h"

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_drivelink_app_LlamaChannel_nativeLoadModel(
    JNIEnv *env, jobject thiz, jstring model_path) {
    
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0; // CPU only (Redmi 7)
    
    llama_model *model = llama_load_model_from_file(path, model_params);
    
    env->ReleaseStringUTFChars(model_path, path);
    return reinterpret_cast<jlong>(model);
}

JNIEXPORT jstring JNICALL
Java_com_drivelink_app_LlamaChannel_nativeGenerate(
    JNIEnv *env, jobject thiz, jlong model_ptr, jstring prompt, jint max_tokens) {
    
    llama_model *model = reinterpret_cast<llama_model*>(model_ptr);
    const char *prompt_cstr = env->GetStringUTFChars(prompt, nullptr);
    
    // Context oluştur
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 512;        // Kısa context (hız için)
    ctx_params.n_threads = 4;      // Snapdragon 632 = 4 büyük çekirdek
    ctx_params.n_threads_batch = 4;
    
    llama_context *ctx = llama_new_context_with_model(model, ctx_params);
    
    // Tokenize + generate
    // ... standart llama.cpp generation loop ...
    
    std::string result = generated_text;
    
    llama_free(ctx);
    env->ReleaseStringUTFChars(prompt, prompt_cstr);
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT void JNICALL
Java_com_drivelink_app_LlamaChannel_nativeUnloadModel(
    JNIEnv *env, jobject thiz, jlong model_ptr) {
    
    llama_model *model = reinterpret_cast<llama_model*>(model_ptr);
    llama_free_model(model);
}

} // extern "C"
```

### Flutter Dart Wrapper
```dart
class LlmService {
  static const _channel = MethodChannel('com.drivelink.app/llama');
  bool _isLoaded = false;
  
  Future<bool> loadModel() async {
    // Model dosyasını assets'ten kopyala
    final modelPath = await _copyModelToLocal('smollm-135m-q4.gguf');
    _isLoaded = await _channel.invokeMethod('loadModel', {'path': modelPath});
    return _isLoaded;
  }
  
  Future<String> generate(String prompt, {int maxTokens = 128}) async {
    if (!_isLoaded) throw Exception('Model yüklenmedi');
    
    return await _channel.invokeMethod('generate', {
      'prompt': prompt,
      'maxTokens': maxTokens,
    });
  }
  
  // Araç bağlamıyla zenginleştirilmiş sorgu
  Future<String> askAboutVehicle(String query, VehicleState state) async {
    final prompt = '''
<|system|>
Sen bir araç asistanısın. Araç: Peugeot 206 2011.
Mevcut veriler: Motor ${state.engineTemp}°C, Hız ${state.speed}km/h, 
Akü ${state.batteryVoltage}V, Dış sıcaklık ${state.extTemp}°C
Kısa ve net Türkçe cevap ver. Maksimum 2 cümle.
<|user|>
${query}
<|assistant|>
''';
    return await generate(prompt, maxTokens: 100);
  }
  
  void dispose() {
    _channel.invokeMethod('unload');
  }
}
```

## Bileşen 5: TFLite Anomali Algılama

### Model 1 — OBD Anomali Detektörü
```
Girdi: Son 60 saniyenin OBD verileri (sliding window)
    - Motor sıcaklığı (60 değer)
    - RPM (60 değer)
    - Hız (60 değer)
    - Yakıt tüketimi (60 değer)
    - Motor yükü (60 değer)
    - Akü voltajı (60 değer)

Model tipi: Autoencoder (anormal veriyi yeniden oluşturamaz)
    Encoder: [360] → [128] → [32] → [8] (bottleneck)
    Decoder: [8] → [32] → [128] → [360]
    
    Reconstruction error yüksek → anomali
    
Model boyutu: ~500KB
Inference süresi: ~10ms
```

### Model 2 — Sürüş Sınıflandırıcı
```
Girdi: İvmeölçer + jiroskop verileri (100Hz, 2 saniyelik pencere)
    - Accelerometer X, Y, Z (200 değer x 3 eksen)
    - Gyroscope X, Y, Z (200 değer x 3 eksen)

Çıktı sınıfları:
    - Normal sürüş
    - Sert fren
    - Sert gaz
    - Ani şerit değişimi
    - Kasis geçişi
    - Çukur geçişi
    - Keskin viraj

Model tipi: 1D-CNN
    Conv1D(32) → Conv1D(64) → GlobalAvgPool → Dense(7)
    
Model boyutu: ~200KB
Inference süresi: ~5ms
```

### Model 3 — Bakım Tahmin
```
Girdi: Uzun vadeli araç istatistikleri
    - Son 30 günün ortalama değerleri
    - Motor sıcaklığı trendi
    - Akü voltajı trendi
    - Yakıt tüketimi trendi
    - Toplam kilometre

Çıktı:
    - Yağ değişimi kalan km tahmini
    - Fren balatası uyarısı (tüketim bazlı)
    - Akü sağlık yüzdesi
    - Genel bakım puanı

Model tipi: Gradient Boosted Trees (TFLite'a çevrilmiş)
Model boyutu: ~100KB
```

### TFLite Flutter Entegrasyonu
```dart
class AnomalyDetector {
  late Interpreter _obdModel;
  late Interpreter _drivingModel;
  
  // Sliding window buffers
  final List<List<double>> _obdBuffer = []; // Son 60 saniye
  final List<List<double>> _imuBuffer = []; // Son 2 saniye
  
  Future<void> initialize() async {
    _obdModel = await Interpreter.fromAsset('anomaly_detector.tflite');
    _drivingModel = await Interpreter.fromAsset('driving_classifier.tflite');
  }
  
  // Her saniye çağrılır (OBD verileri)
  AnomalyResult checkObd(OBDData data) {
    _obdBuffer.add([
      data.engineTemp,
      data.rpm.toDouble(),
      data.speed.toDouble(),
      data.fuelRate,
      data.engineLoad,
      data.batteryVoltage,
    ]);
    
    if (_obdBuffer.length < 60) return AnomalyResult.normal();
    if (_obdBuffer.length > 60) _obdBuffer.removeAt(0);
    
    // Normalize et
    var input = _normalize(_obdBuffer);
    
    // Inference
    var output = List.filled(360, 0.0).reshape([1, 360]);
    _obdModel.run(input.reshape([1, 360]), output);
    
    // Reconstruction error hesapla
    double error = _reconstructionError(input, output[0]);
    
    if (error > 0.8) {
      return AnomalyResult(
        level: AnomalyLevel.critical,
        message: _identifyAnomaly(input, output[0]),
        confidence: error,
      );
    } else if (error > 0.5) {
      return AnomalyResult(
        level: AnomalyLevel.warning,
        message: _identifyAnomaly(input, output[0]),
        confidence: error,
      );
    }
    
    return AnomalyResult.normal();
  }
  
  // Her 20ms çağrılır (IMU verileri, 50Hz)
  DrivingEvent checkDriving(SensorData data) {
    _imuBuffer.add([
      data.accelX, data.accelY, data.accelZ,
      data.gyroX, data.gyroY, data.gyroZ,
    ]);
    
    if (_imuBuffer.length < 100) return DrivingEvent.normal;
    if (_imuBuffer.length > 100) _imuBuffer.removeAt(0);
    
    // Inference
    var input = _imuBuffer.expand((e) => e).toList();
    var output = List.filled(7, 0.0).reshape([1, 7]);
    _drivingModel.run(input.reshape([1, 600]), output);
    
    // En yüksek olasılıklı sınıf
    int maxIdx = output[0].indexOf(output[0].reduce(max));
    double confidence = output[0][maxIdx];
    
    if (confidence > 0.7) {
      return DrivingEvent.values[maxIdx];
    }
    return DrivingEvent.normal;
  }
  
  String _identifyAnomaly(List<double> input, List<double> reconstructed) {
    // Hangi parametrede en büyük fark var?
    // Motor sıcaklığı farkı yüksekse → "Motor sıcaklığı anormal"
    // Akü voltajı farkı yüksekse → "Akü voltajı düşüyor"
    // vs.
  }
}
```

### Anomali Bildirimleri
```dart
class AnomalyAlertManager {
  
  void handleAnomaly(AnomalyResult result, VehicleState state) {
    switch (result.level) {
      case AnomalyLevel.critical:
        // Sesli uyarı (TTS)
        tts.speak("Dikkat! ${result.message}");
        // Ekranda kırmızı uyarı
        showCriticalAlert(result);
        // Log kaydet
        logAnomaly(result, state);
        break;
        
      case AnomalyLevel.warning:
        // Sadece ekranda sarı uyarı
        showWarningAlert(result);
        // Log kaydet
        logAnomaly(result, state);
        break;
        
      case AnomalyLevel.normal:
        // Hiçbir şey yapma
        break;
    }
  }
  
  // Anomali mesaj şablonları
  static final Map<String, String> alertMessages = {
    'engine_temp_high': 'Motor sıcaklığı normalin üstüne çıktı: {value}°C',
    'engine_temp_rising': 'Motor sıcaklığı hızla yükseliyor',
    'battery_low': 'Akü voltajı düşük: {value}V',
    'battery_dropping': 'Akü voltajı düşmeye devam ediyor',
    'fuel_consumption_high': 'Yakıt tüketimi normalin üstünde: {value} L/100km',
    'rpm_unstable': 'Motor devri dengesiz',
    'idle_rough': 'Rölanti düzensiz',
    'speed_sensor_error': 'Hız sensörü tutarsız veri gönderiyor',
  };
}
```

## Bileşen 6: Sürüş Puanlama

### Gerçek Zamanlı Sürüş Analizi
```dart
class DrivingScoreCalculator {
  double _smoothness = 100.0;   // Yumuşak sürüş
  double _efficiency = 100.0;   // Yakıt verimliliği  
  double _safety = 100.0;       // Güvenlik
  int _eventCount = 0;
  
  void onDrivingEvent(DrivingEvent event) {
    switch (event) {
      case DrivingEvent.hardBrake:
        _safety -= 5.0;
        _smoothness -= 3.0;
        _eventCount++;
        break;
      case DrivingEvent.hardAccel:
        _efficiency -= 3.0;
        _smoothness -= 2.0;
        _eventCount++;
        break;
      case DrivingEvent.sharpTurn:
        _safety -= 3.0;
        _smoothness -= 2.0;
        _eventCount++;
        break;
      // ... diğer eventler
    }
    
    // Zaman geçtikçe puan yavaşça toparlanır
    _smoothness = min(100, _smoothness + 0.01);
    _efficiency = min(100, _efficiency + 0.01);
    _safety = min(100, _safety + 0.01);
  }
  
  double get overallScore => (_smoothness + _efficiency + _safety) / 3.0;
  
  String get feedback {
    if (overallScore > 90) return "Mükemmel sürüş!";
    if (overallScore > 75) return "İyi sürüş, biraz daha yumuşak olabilir";
    if (overallScore > 60) return "Orta, ani manevralardan kaçının";
    return "Dikkatli olun, sert sürüş tespit edildi";
  }
  
  // Yolculuk sonu özeti
  TripSummary generateSummary() {
    return TripSummary(
      score: overallScore,
      smoothness: _smoothness,
      efficiency: _efficiency,
      safety: _safety,
      eventCount: _eventCount,
      feedback: feedback,
      tips: _generateTips(),
    );
  }
  
  List<String> _generateTips() {
    List<String> tips = [];
    if (_safety < 80) tips.add("Takip mesafesini artırmayı deneyin");
    if (_efficiency < 80) tips.add("2000-2500 RPM aralığında vites değiştirin");
    if (_smoothness < 80) tips.add("Frene daha erken ve yumuşak basın");
    return tips;
  }
}
```

## Bileşen 7: Ana AI Pipeline

### Komple Akış
```dart
class DriveAssistant {
  final VoskService _vosk;
  final PorcupineService _porcupine;
  final LlmService _llm;
  final AnomalyDetector _anomaly;
  final DrivingScoreCalculator _drivingScore;
  final IntentParser _intentParser;
  final FlutterTts _tts;
  
  VehicleState _vehicleState = VehicleState.empty();
  bool _isProcessing = false;
  
  // Ana başlatma
  Future<void> initialize() async {
    await _vosk.initialize();           // ~2 saniye
    await _porcupine.initialize();      // ~1 saniye
    await _llm.loadModel();             // ~3 saniye
    await _anomaly.initialize();        // ~1 saniye
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.9);      // Biraz yavaş, anlaşılır
    
    // Arka plan dinleyicileri başlat
    _startWakeWordDetection();
    _startAnomalyMonitoring();
    _startDrivingAnalysis();
  }
  
  // Wake word veya source tuşu tetiklendi
  Future<void> onActivated() async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    // Ses ipucu (kısa bip)
    await _playActivationSound();
    
    // Dinlemeye başla
    final transcript = await _vosk.listenOnce(
      timeout: Duration(seconds: 10),
      silenceTimeout: Duration(seconds: 3),
    );
    
    if (transcript.isEmpty) {
      await _tts.speak("Sizi duyamadım");
      _isProcessing = false;
      return;
    }
    
    // Intent çöz
    final intent = _intentParser.parse(transcript);
    
    // Aksiyonu çalıştır
    final response = await _executeIntent(intent);
    
    // Sesli yanıt
    await _tts.speak(response);
    
    _isProcessing = false;
  }
  
  Future<String> _executeIntent(Intent intent) async {
    switch (intent.action) {
      // Navigasyon
      case 'NAV_HOME':
        final home = await _getSavedAddress('home');
        if (home != null) {
          _navigationService.startRoute(home);
          return "Eve rota başlatılıyor";
        }
        return "Ev adresi kayıtlı değil. Ayarlardan ekleyebilirsiniz.";
        
      case 'NAV_NEARBY':
        final poiType = intent.params['poi_type'];
        final results = await _navigationService.searchNearby(poiType);
        if (results.isNotEmpty) {
          return "${results.first.name}, ${results.first.distance} metre ileride. Rota başlatayım mı?";
        }
        return "Yakında $poiType bulunamadı";
        
      case 'NAV_ETA':
        final eta = _navigationService.currentEta;
        return "Tahmini varış: ${eta.format()}, ${eta.distanceKm} kilometre kaldı";
      
      // Araç bilgi
      case 'VEHICLE_TEMP':
        return "Dış sıcaklık ${_vehicleState.extTemp} derece";
        
      case 'VEHICLE_ENGINE_TEMP':
        final temp = _vehicleState.engineTemp;
        final status = temp > 100 ? ", dikkat yüksek" : ", normal";
        return "Motor sıcaklığı $temp derece$status";
        
      case 'VEHICLE_STATUS':
        return _generateVehicleStatusSummary();
        
      case 'VEHICLE_FUEL':
        return "Anlık tüketim ${_vehicleState.fuelRate} litre, ortalama ${_vehicleState.avgFuelRate} litre yüz kilometre";
      
      // Medya
      case 'MEDIA_PLAY':
        _mediaService.play();
        return "Müzik çalınıyor";
        
      case 'MEDIA_NEXT':
        _mediaService.next();
        return "Sonraki şarkı";
      
      // AI Sohbet (LLM)
      case 'AI_CHAT':
        return await _llm.askAboutVehicle(
          intent.params['query'],
          _vehicleState,
        );
        
      default:
        return "Bu komutu anlayamadım";
    }
  }
  
  String _generateVehicleStatusSummary() {
    final s = _vehicleState;
    final issues = <String>[];
    
    if (s.engineTemp > 100) issues.add("motor sıcaklığı yüksek");
    if (s.batteryVoltage < 12.4) issues.add("akü voltajı düşük");
    if (s.fuelRate > 10) issues.add("yakıt tüketimi yüksek");
    
    if (issues.isEmpty) {
      return "Araç durumu normal. Motor ${s.engineTemp} derece, akü ${s.batteryVoltage} volt, hız ${s.speed} kilometre";
    }
    return "Dikkat: ${issues.join(', ')}. Motor ${s.engineTemp} derece, akü ${s.batteryVoltage} volt";
  }
  
  // Arka plan anomali izleme
  void _startAnomalyMonitoring() {
    // Her saniye OBD verisi kontrolü
    Timer.periodic(Duration(seconds: 1), (timer) {
      final result = _anomaly.checkObd(_vehicleState.toOBDData());
      if (result.level != AnomalyLevel.normal) {
        _alertManager.handleAnomaly(result, _vehicleState);
      }
    });
  }
  
  // Arka plan sürüş analizi
  void _startDrivingAnalysis() {
    // İvmeölçer verileri 50Hz
    _sensorService.accelerometerStream.listen((data) {
      final event = _anomaly.checkDriving(data);
      if (event != DrivingEvent.normal) {
        _drivingScore.onDrivingEvent(event);
        
        // GPS konumunu kaydet (çukur/kasis harita verisi)
        if (event == DrivingEvent.pothole || event == DrivingEvent.speedBump) {
          _roadQualityService.recordEvent(event, _currentLocation);
        }
      }
    });
  }
}
```

## Model Eğitimi Notları

### OBD Anomali Modeli Eğitimi
```
Veri toplama:
    1. DriveLink app normal sürüşte OBD verisi toplar
    2. İlk 1000km "normal" veri → eğitim seti
    3. Autoencoder sadece normal veriyi öğrenir
    4. Anormal veri → reconstruction error yüksek

Transfer learning:
    → Genel bir araç anomali modeli önceden eğitilir
    → Kullanıcının aracına fine-tune yapılır
    → İlk 500km sonra kişiselleştirilmiş model
```

### Sürüş Sınıflandırıcı Eğitimi
```
Veri toplama:
    → Telefon sensörleri ile sürüş kayıtları
    → Manuel etiketleme (sert fren, kasis vs.)
    → Veya sentetik veri üretimi

Açık veri setleri:
    → UAH-DriveSet (University of Alcala)
    → OCSLab driving dataset
```

## Performans Bütçesi (Redmi 7)
```
Toplam RAM bütçesi: 3GB

Android OS:              ~800MB
DriveLink App:           ~150MB
Vosk model (yüklü):     ~100MB
Smollm model (yüklü):   ~150MB
TFLite modelleri:        ~10MB
Porcupine:               ~5MB
Harita tile cache:       ~50MB
─────────────────────────────
Toplam:                  ~1265MB
Kalan:                   ~1735MB (yeterli)

CPU kullanımı:
    Porcupine (arka plan):  ~2%
    Anomali (1Hz):          ~1%
    Sürüş analizi (50Hz):   ~5%
    Harita render:          ~10%
    ────────────────────
    Boşta toplam:           ~18%
    
    Vosk aktif:             +30%
    LLM aktif:              +80% (2-3 saniye burst)
```

## Flutter Paketleri
```yaml
dependencies:
  # Ses tanıma (offline)
  vosk_flutter: ^0.4.0
  
  # Wake word (offline)
  picovoice_flutter: ^3.0.0
  
  # Text-to-speech  
  flutter_tts: ^3.8.0
  
  # Makine öğrenmesi
  tflite_flutter: ^0.10.0
  
  # Sensörler
  sensors_plus: ^4.0.0
  
  # Ses işleme
  record: ^5.0.0           # Mikrofon kaydı
  
  # Platform channel (llama.cpp için)
  # Native Kotlin + C++ entegrasyonu
```

## Geliştirme Fazları

### Faz 1 — Ses Tanıma + Kural Tabanlı Komutlar (1 hafta)
1. Vosk Türkçe model entegrasyonu
2. Mikrofon erişimi + ses kaydı
3. Gürültü filtreleme (araç ortamı)
4. Intent parser (kural tabanlı)
5. TTS yanıtları
6. Source tuşu tetikleme (VAN bus event)
7. Temel komut seti çalışsın

### Faz 2 — Wake Word (3 gün)
1. Porcupine entegrasyonu
2. "abidin" özel model
3. Arka plan dinleme servisi
4. Wake word + source tuşu birleşimi

### Faz 3 — LLM Entegrasyonu (1 hafta)
1. llama.cpp Android build
2. Platform channel (Kotlin + C++)
3. Smollm model entegrasyonu
4. Araç bağlamıyla prompt oluşturma
5. Doğal dil sorularını yanıtlama
6. Kural tabanlı → LLM fallback zinciri

### Faz 4 — Anomali Algılama (1 hafta)
1. TFLite model entegrasyonu
2. OBD veri buffer + sliding window
3. Autoencoder inference
4. Anomali bildirimleri (sesli + görsel)
5. İvmeölçer sürüş analizi
6. Sürüş puanlama sistemi

### Faz 5 — Fine-tuning + Test (1 hafta)
1. Araç ortamında ses tanıma testi
2. Gürültü kalibrasyonu
3. Yanlış tetikleme azaltma
4. Anomali eşik değerleri ayarlama
5. Sürüş puanı kalibrasyonu
6. Genel performans optimizasyonu

## Başla
1. Flutter projesine AI modülünü ekle
2. Vosk Türkçe model dosyasını indir
3. Mikrofon izni + ses kaydı pipeline'ı kur
4. İlk ses tanıma testini yap
5. Her adımda derle, test et, ilerle
