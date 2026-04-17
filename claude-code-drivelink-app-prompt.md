# DriveLink — Açık Kaynak Araç Infotainment Uygulaması
# Claude Code Proje Promptu

## Vizyon
Eski araçları akıllı araçlara dönüştüren, tamamen offline çalışabilen, açık kaynak araç infotainment uygulaması. ESP32 + VAN/CAN bus üzerinden araç verilerini okur, ELM327 OBD-II ile motor verilerini alır, offline harita ile turn-by-turn navigasyon sunar, müzik kontrolü yapar — hepsini tek ekranda birleştirir.

Google Play'de yayınlanacak. Hedef kitle: eski araç sahipleri, DIY araç modifiye toplulukları, araç bilişim meraklıları.

## Uygulama Adı: DriveLink
**Slogan:** "Eski aracını akıllı yap"

## Teknik Stack
- **Framework:** Flutter 3.x (Dart)
- **Minimum Android:** API 24 (Android 7.0) — eski telefonlar için
- **State Management:** Riverpod 2.x
- **Mimari:** Clean Architecture (domain / data / presentation katmanları)
- **Navigasyon:** GoRouter
- **Veritabanı:** Drift (SQLite) — araç logları, ayarlar, rota geçmişi
- **Test:** unit test + widget test + integration test

## Modüler Yapı
```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_theme.dart
│       ├── dark_theme.dart          # Araç için varsayılan karanlık tema
│       └── colors.dart
│
├── core/
│   ├── constants/
│   ├── utils/
│   ├── extensions/
│   └── services/
│       ├── usb_serial_service.dart  # USB seri haberleşme katmanı
│       ├── location_service.dart     # GPS konum servisi
│       ├── audio_service.dart        # Müzik kontrolü
│       └── tts_service.dart          # Text-to-speech (navigasyon sesleri)
│
├── features/
│   ├── dashboard/                    # Ana ekran — tüm widget'lar burada
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── dashboard_screen.dart
│   │   │   └── widgets/
│   │   │       ├── status_bar.dart
│   │   │       ├── speed_gauge.dart
│   │   │       ├── mini_map.dart
│   │   │       └── media_controls.dart
│   │   ├── domain/
│   │   └── data/
│   │
│   ├── navigation/                   # Offline harita + turn-by-turn
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── map_screen.dart         # Tam ekran harita
│   │   │   │   └── route_search_screen.dart # Adres arama
│   │   │   └── widgets/
│   │   │       ├── map_widget.dart
│   │   │       ├── turn_instruction.dart
│   │   │       ├── route_info_bar.dart
│   │   │       └── lane_guidance.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── route_model.dart
│   │   │   │   ├── turn_instruction.dart
│   │   │   │   └── map_tile.dart
│   │   │   ├── repositories/
│   │   │   │   └── navigation_repository.dart
│   │   │   └── usecases/
│   │   │       ├── calculate_route.dart
│   │   │       ├── get_turn_instructions.dart
│   │   │       └── search_address.dart
│   │   └── data/
│   │       ├── datasources/
│   │       │   ├── osm_tile_source.dart      # Offline tile cache
│   │       │   ├── graphhopper_source.dart    # Offline rota hesaplama
│   │       │   └── nominatim_source.dart      # Adres arama (online/cache)
│   │       └── repositories/
│   │           └── navigation_repository_impl.dart
│   │
│   ├── vehicle_bus/                  # VAN/CAN bus (ESP32 üzerinden)
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── bus_monitor_screen.dart    # Raw veri izleme (debug)
│   │   │   └── widgets/
│   │   │       ├── temperature_widget.dart
│   │   │       ├── door_status_widget.dart
│   │   │       └── steering_controls.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── van_message.dart
│   │   │   │   ├── vehicle_state.dart
│   │   │   │   └── steering_button.dart
│   │   │   └── repositories/
│   │   │       └── vehicle_bus_repository.dart
│   │   └── data/
│   │       ├── datasources/
│   │       │   └── esp32_serial_source.dart   # USB seri ile ESP32 haberleşme
│   │       ├── parsers/
│   │       │   ├── van_message_parser.dart     # JSON parse
│   │       │   └── peugeot_206_parser.dart     # Peugeot 206 spesifik
│   │       └── repositories/
│   │           └── vehicle_bus_repository_impl.dart
│   │
│   ├── obd/                          # OBD-II (ELM327 üzerinden)
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── obd_dashboard_screen.dart
│   │   │   │   └── dtc_screen.dart           # Arıza kodu okuma/silme
│   │   │   └── widgets/
│   │   │       ├── rpm_gauge.dart
│   │   │       ├── fuel_consumption.dart
│   │   │       ├── coolant_temp.dart
│   │   │       └── obd_grid.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── obd_data.dart
│   │   │   │   ├── dtc_code.dart
│   │   │   │   └── pid.dart
│   │   │   └── repositories/
│   │   │       └── obd_repository.dart
│   │   └── data/
│   │       ├── datasources/
│   │       │   └── elm327_serial_source.dart  # ELM327 AT komutları
│   │       ├── parsers/
│   │       │   ├── obd_pid_parser.dart
│   │       │   └── dtc_parser.dart
│   │       └── repositories/
│   │           └── obd_repository_impl.dart
│   │
│   ├── media/                        # Müzik kontrolü
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── media_screen.dart
│   │   │   └── widgets/
│   │   │       ├── now_playing.dart
│   │   │       ├── playlist.dart
│   │   │       └── volume_control.dart
│   │   ├── domain/
│   │   └── data/
│   │
│   ├── settings/                     # Ayarlar
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       ├── settings_screen.dart
│   │   │       ├── vehicle_config_screen.dart  # Araç seçimi (206, 307 vs.)
│   │   │       ├── usb_config_screen.dart      # USB port eşleştirme
│   │   │       └── theme_config_screen.dart     # Tema, renk ayarları
│   │   └── domain/
│   │
│   └── trip_computer/                # Yol bilgisayarı
│       ├── presentation/
│       │   └── widgets/
│       │       ├── trip_stats.dart
│       │       ├── fuel_economy.dart
│       │       └── trip_history.dart
│       ├── domain/
│       └── data/
│
├── shared/
│   ├── widgets/
│   │   ├── gauge_widget.dart          # Yeniden kullanılabilir gauge
│   │   ├── animated_value.dart        # Sayı animasyonları
│   │   └── connection_indicator.dart   # USB bağlantı durumu
│   └── models/
│       └── connection_status.dart
│
└── generated/                         # Build runner çıktıları
```

## Ekran Tasarımları

### Ana Dashboard (Dikey — Telefon)
```
┌─────────────────────────────────────┐
│ 🌡️23°C  📡VAN  🔌OBD  ⏱12:45  🔋14.2V │ ← Status bar (her zaman görünür)
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │   OFFLINE HARİTA               │ │ ← %40 ekran
│ │   Mevcut konum + yön oku       │ │    Dokunursan tam ekran açılır
│ │   Sonraki manevra: ↱ 200m      │ │    Navigasyon aktifse manevra gösterir
│ │                                 │ │
│ └─────────────────────────────────┘ │
├──────────────┬──────────────────────┤
│              │                      │
│   65 km/h    │    2500 RPM          │ ← Hız + Devir gauge
│   ████████   │    ████████          │    VAN bus veya OBD'den
│              │                      │
├──────────────┼──────────────────────┤
│ ⛽ 6.2 L/100 │ 💧 90°C motor        │ ← OBD verileri
│ 📏 Trip:45km │ 🌡️ Dış: 23°C        │    VAN bus verileri
├──────────────┴──────────────────────┤
│ 🎵 [◀️] Şarkı Adı - Sanatçı [▶️]   │ ← Müzik mini player
├─────────────────────────────────────┤
│  [🗺️NAV] [📊OBD] [🎵MÜZİK] [⚙️SET] │ ← Alt menü (sabit)
└─────────────────────────────────────┘
```

### Tam Ekran Navigasyon
```
┌─────────────────────────────────────┐
│        ↱ 200m sonra sağa dön       │ ← Manevra kartı
│        Atatürk Caddesi              │
├─────────────────────────────────────┤
│                                     │
│                                     │
│          TAM EKRAN HARİTA           │ ← flutter_map
│          Rota çizgisi               │
│          Konum takibi               │
│          Otomatik zoom              │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  65km/h │ 12dk │ 4.5km │ 13:05 ETA │ ← Rota bilgisi bar
├─────────────────────────────────────┤
│  [✖️İptal] [🔇Ses] [📋Adımlar] [⬅️] │ ← Navigasyon kontrolleri
└─────────────────────────────────────┘
```

### OBD Dashboard (Tam Ekran)
```
┌─────────────────────────────────────┐
│           OBD-II Dashboard          │
├──────────────┬──────────────────────┤
│              │                      │
│   RPM Gauge  │   Hız Gauge          │
│   ◉ 2500     │   ◉ 65 km/h         │
│              │                      │
├──────────────┼──────────────────────┤
│ Motor Sıcak. │ Emme Basıncı        │
│  💧 90°C     │  📊 35 kPa           │
├──────────────┼──────────────────────┤
│ Yakıt Tüket. │ Akü Voltajı         │
│  ⛽ 6.2L/100 │  🔋 14.2V            │
├──────────────┼──────────────────────┤
│ Throttle     │ Motor Yükü          │
│  🎚️ 23%      │  📈 45%              │
├──────────────┴──────────────────────┤
│ [⚠️ DTC Kodları]  [📊 Canlı Grafik] │
└─────────────────────────────────────┘
```

## Offline Navigasyon Mimarisi

### Harita Tile'ları (flutter_map + flutter_map_tile_caching)
```
Harita indirme akışı:
1. Ayarlar → "Harita İndir" → Bölge seç (Türkiye veya şehir bazlı)
2. OSM tile sunucusundan zoom level 5-16 arası tile indir
3. SQLite cache'e kaydet
4. İnternet olmadan cache'ten oku

Tile URL: https://tile.openstreetmap.org/{z}/{x}/{y}.png
Cache: drift veritabanı, tile key = "z/x/y"
Tahmini boyut: Türkiye tam = ~2-3 GB, tek şehir = ~200-500 MB
```

### Rota Hesaplama (Offline GraphHopper)
```
graphhopper_flutter paketi veya native platform channel:

1. OSM PBF dosyasını indir (turkey-latest.osm.pbf ~1.5GB)
2. GraphHopper profil oluştur (araç tipi: car)
3. Rota hesapla: başlangıç → bitiş koordinatları
4. Turn-by-turn instruction listesi al
5. Polyline çiz + sesli yönlendirme

Alternatif: Valhalla veya OSRM embedded
    - Valhalla: Daha iyi Türkçe yönlendirme
    - OSRM: Daha hafif, daha hızlı
    
Platform channel ile C++ OSRM kütüphanesini çağırabiliriz
veya Dart FFI ile doğrudan binding yapabiliriz.
```

### Adres Arama
```
Online: Nominatim API (OSM geocoding)
Offline: Önceden indirilen POI veritabanı
    - Photon geocoder offline index
    - veya basit SQLite FTS5 ile şehir/cadde arama
```

### Sesli Yönlendirme
```
flutter_tts paketi:
    - Türkçe TTS motor (Android dahili)
    - Manevra mesajları: "200 metre sonra sağa dönün"
    - Hız uyarısı: "Hız limitini aştınız"
    - Radar uyarısı: "300 metre ileride hız kamerası"
    
Mesaj şablonları:
    turn_right: "{distance} sonra sağa dönün"
    turn_left: "{distance} sonra sola dönün"
    roundabout: "Dönel kavşakta {exit}. çıkışı alın"
    continue: "{distance} boyunca düz devam edin"
    arrive: "Hedefinize ulaştınız"
    recalculating: "Rota yeniden hesaplanıyor"
```

## USB Seri Haberleşme

### Çoklu USB Cihaz Yönetimi
```
Hub'a bağlı USB cihazlar:
    /dev/ttyUSB0 → ESP32 Beetle (CH340C) — VAN bus
    /dev/ttyUSB1 → ELM327 (PL2303 veya CH340) — OBD-II

Otomatik tanıma:
    1. USB cihaz bağlandığında VID/PID oku
    2. CH340 + baud 115200 + JSON çıktı → ESP32
    3. ELM327 → "ATZ" gönder, "ELM327" yanıtı gelirse → OBD
    4. Bağlantı koptuğunda auto-reconnect (araç çalıştırma sırasında)
```

### ESP32 Veri Formatı (VAN Bus)
```json
{"type":"temp_ext","value":23.5,"unit":"C","ts":12345}
{"type":"speed","kmh":65,"ts":12346}
{"type":"steering","button":"vol_up","action":"press","ts":12347}
{"type":"door","fl":false,"fr":true,"rl":false,"rr":false,"ts":12348}
{"type":"parking","left":45,"center":120,"right":60,"unit":"cm","ts":12349}
{"type":"raw","id":"0x5E4","data":"A1B2C3D4","len":4,"ts":12350}
```

### ELM327 Protokolü
```
Başlangıç sekansı:
    ATZ        → Reset
    ATE0       → Echo off
    ATL0       → Linefeed off  
    ATS0       → Spaces off
    ATH0       → Headers off
    ATSP0      → Auto protocol
    0100       → Supported PIDs kontrol

Periyodik sorgular (200ms aralıkla round-robin):
    010C → RPM
    010D → Speed
    0105 → Coolant temp
    0104 → Engine load
    0111 → Throttle position
    015E → Fuel rate
```

## Direksiyon Tuşu Entegrasyonu
```
VAN bus'tan gelen direksiyon tuşu eventleri:
    vol_up    → Medya ses artır
    vol_down  → Medya ses azalt
    next      → Sonraki şarkı
    prev      → Önceki şarkı
    src       → Dashboard ekranları arası geçiş (NAV→OBD→MÜZİK→NAV)
    phone     → TTS ile bildirim oku (opsiyonel)

Flutter tarafında:
    ESP32'den steering event gelir → Provider/Riverpod state güncelle
    → İlgili aksiyon tetiklenir (MediaSession, UI navigation vs.)
```

## Araç Profil Sistemi
```
Farklı araçlar desteklenecek:

class VehicleProfile {
    String name;           // "Peugeot 206 2011"
    String busType;        // "VAN" veya "CAN"
    int busSpeed;          // 125000 (VAN) veya 500000 (CAN)
    Map<int, MessageDef> messages;  // ID → parser mapping
}

Dahili profiller:
    - Peugeot 206 (VAN bus)
    - Peugeot 307 (VAN bus)
    - Peugeot 407 (CAN bus)
    - Citroën C3 (VAN bus)
    - Citroën C4 (CAN bus)
    - Generic OBD-II only (VAN/CAN yok, sadece ELM327)

Kullanıcı kendi profilini oluşturabilir (gelecekte)
```

## Performans Gereksinimleri
```
Hedef cihaz: Redmi 7 (Snapdragon 632, 3GB RAM)

- Uygulama başlatma: < 3 saniye
- Harita render: 60 FPS
- VAN bus veri gecikmesi: < 50ms
- OBD sorgu döngüsü: < 200ms
- RAM kullanımı: < 250MB
- Arka plan servis: < 30MB
- APK boyutu: < 50MB (harita verileri hariç)
```

## Google Play Yayınlama
```
Paket adı: com.drivelink.app (veya tr.org.drivelink)
Min SDK: 24
Target SDK: 34
Kategori: Araçlar (Auto & Vehicles)
Fiyat: Ücretsiz + Açık kaynak (GPLv3)
GitHub: github.com/[kullanıcı]/drivelink

Play Store açıklaması:
    "DriveLink — Eski aracını akıllı yap!
    ESP32 + OBD-II ile araç verilerini oku,
    offline navigasyon ile yolunu bul,
    hepsini tek ekranda gör."

Ekran görüntüleri:
    1. Dashboard ana ekran
    2. Tam ekran navigasyon
    3. OBD-II dashboard
    4. Müzik kontrolü
    5. Ayarlar ekranı
```

## Geliştirme Fazları

### Faz 1 — Temel (İlk 2 hafta)
1. Proje yapısı + mimari
2. USB seri haberleşme servisi
3. ESP32 VAN bus veri okuma + parse
4. Dashboard ana ekran (hız, sıcaklık, durum)
5. Karanlık tema

### Faz 2 — Navigasyon (2-3 hafta)
1. flutter_map entegrasyonu
2. Offline tile cache sistemi
3. Rota hesaplama (GraphHopper veya OSRM)
4. Turn-by-turn yönlendirme
5. Sesli navigasyon (flutter_tts)
6. Adres arama

### Faz 3 — OBD-II (1-2 hafta)
1. ELM327 haberleşme protokolü
2. PID okuma ve parse
3. OBD dashboard ekranı
4. DTC (arıza kodu) okuma/silme
5. Yol bilgisayarı (trip computer)

### Faz 4 — Medya + Direksiyon (1 hafta)
1. Müzik kontrolü (MediaSession API)
2. Direksiyon tuşu eşleştirme
3. Now playing widget

### Faz 5 — Polish + Yayınlama (1-2 hafta)
1. Animasyonlar ve geçişler
2. Ayarlar ekranı
3. Araç profil seçimi
4. Play Store hazırlık (icon, screenshots, açıklama)
5. GitHub repo + README + lisans

## Bağımlılıklar (pubspec.yaml taslak)
```yaml
name: drivelink
description: Open-source car infotainment system
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Navigation
  go_router: ^13.0.0
  
  # Map & Navigation
  flutter_map: ^6.1.0
  flutter_map_tile_caching: ^9.0.0
  latlong2: ^0.9.0
  geolocator: ^11.0.0
  flutter_compass: ^0.8.0
  
  # USB Serial
  usb_serial: ^0.5.0
  
  # Database
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  
  # TTS & Audio
  flutter_tts: ^3.8.0
  audio_service: ^0.18.0
  just_audio: ^0.9.0
  
  # UI
  fl_chart: ^0.66.0            # Gauge ve grafikler
  syncfusion_flutter_gauges: ^24.0.0  # Radial gauge
  google_fonts: ^6.0.0
  flutter_animate: ^4.0.0
  
  # Utils
  intl: ^0.19.0
  path_provider: ^2.1.0
  permission_handler: ^11.0.0
  connectivity_plus: ^5.0.0
  wakelock_plus: ^1.1.0        # Ekranı açık tut
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  drift_dev: ^2.14.0
  flutter_lints: ^3.0.0
```

## Başla
1. Flutter projesini oluştur (`flutter create drivelink`)
2. Dizin yapısını kur
3. pubspec.yaml'ı yapılandır
4. Faz 1'den başla: USB seri servis + dashboard
5. Her adımda derle, test et, ilerle
