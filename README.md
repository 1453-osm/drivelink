# DriveLink

**Eski aracini akilli yap**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://developer.android.com)

---

## Nedir?

DriveLink, eski araclarini akilli bir bilgi-eglence sistemine donusturen acik kaynakli bir Android uygulamasidir. ESP32 mikrodenetleyici ve OBD-II (ELM327) adaptoru ile arac verilerini okur, offline navigasyon saglar, muzik kontrolu sunar ve hepsini tek bir ekranda birlestirir.

Aracinda Android telefon veya tablet kullanan herkes icin tasarlandi. USB baglantisi ile calisir, Bluetooth gerektirmez.

## Ekran Goruntuleri

> Ekran goruntuleri eklenecek.

## Ozellikler

- **Dashboard**: Hiz, RPM, motor sicakligi, yakit tuketimi gostergesi
- **Offline navigasyon**: OpenStreetMap haritalari, GraphHopper rotalama, TTS sesli yonlendirme
- **OBD-II**: ELM327 ile canli motor verileri, ariza kodu (DTC) okuma ve silme
- **VAN/CAN bus**: ESP32 ile arac ic ag verileri (Peugeot 206/307/407, Citroen C3/C4)
- **Muzik kontrolu**: Direksiyon tuslari ile medya yonetimi (play/pause, ileri/geri)
- **Yol bilgisayari**: Toplam mesafe, yakit tuketimi, ortalama hiz hesaplama
- **Karanlik tema**: Arac ici gece kullanimi icin optimize edilmis koyu arayuz
- **Tamamen offline**: Internet baglantisi gerektirmeden calisir

## Gereksinimler

| Gereksinim | Detay |
|---|---|
| Android | 7.0+ (API 24) |
| Flutter | 3.x |
| ESP32 | VAN/CAN bus icin (opsiyonel) |
| ELM327 | USB adaptor, OBD-II icin (opsiyonel) |
| USB OTG | Telefon/tablet ile USB baglantisi icin |

> **Not:** ESP32 ve ELM327 opsiyoneldir. Sadece navigasyon ve muzik ozellikleri icin hicbir ek donanim gerekmez.

## Kurulum

```bash
# Repoyu klonla
git clone https://github.com/osman/drivelink.git
cd drivelink

# Bagimliliklar
flutter pub get

# Drift kod uretimi
dart run build_runner build

# Calistir
flutter run
```

### Release APK

```bash
flutter build apk --release
```

APK dosyasi `build/app/outputs/flutter-apk/app-release.apk` konumunda olusur.

## Desteklenen Araclar

### VAN Bus (ESP32 gerektirir)
| Arac | Protokol | Durum |
|---|---|---|
| Peugeot 206 | VAN bus | Destekleniyor |
| Peugeot 307 | VAN bus | Destekleniyor |
| Citroen C3 | VAN bus | Destekleniyor |

### CAN Bus (ESP32 gerektirir)
| Arac | Protokol | Durum |
|---|---|---|
| Peugeot 407 | CAN bus | Destekleniyor |
| Citroen C4 | CAN bus | Destekleniyor |

### Generic OBD-II
Herhangi bir 1996+ model arac, ELM327 USB adaptor ile temel motor verilerini okuyabilir.

## Mimari

Proje **Clean Architecture** prensipleri ile yapilandirilmistir:

```
lib/
  core/
    database/        # Drift (SQLite) veritabani
    services/        # USB serial, audio, konum servisleri
  features/
    {ozellik}/
      domain/        # Entity, repository interface
      data/          # Repository implementasyonu, veri kaynaklari
      presentation/  # UI, controller, widget
```

**Teknoloji secimi:**
- **State Management**: Riverpod
- **Navigasyon**: GoRouter
- **Veritabani**: Drift (SQLite)
- **Harita**: flutter_map + FMTC (Flutter Map Tile Caching)
- **USB**: usb_serial
- **Ses**: just_audio + audio_service

## Katkida Bulunma

Katkalariniz memnuniyetle karsilanir!

1. Repoyu fork edin
2. Feature branch olusturun (`git checkout -b feature/yeni-ozellik`)
3. Degisikliklerinizi commit edin (`git commit -m 'feat: yeni ozellik ekle'`)
4. Branch'i push edin (`git push origin feature/yeni-ozellik`)
5. Pull Request acin

Hata bildirimi ve oneriler icin [Issues](../../issues) sayfasini kullanin.

## Lisans

Bu proje [GNU General Public License v3.0](LICENSE) lisansi ile lisanslanmistir.

```
DriveLink - Acik kaynakli arac bilgi-eglence sistemi
Copyright (C) 2026 DriveLink Contributors

Bu program ozgur yazilimdir; Free Software Foundation tarafindan yayimlanan
GNU Genel Kamu Lisansi'nin 3. surumu veya (secime bagli) daha sonraki
herhangi bir surumu altinda yeniden dagitabilir ve/veya degistirebilirsiniz.
```
