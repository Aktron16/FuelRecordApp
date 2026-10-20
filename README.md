# Fuel Metrics (Version 1.2.0)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2.svg?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)]()
[![Material Design](https://img.shields.io/badge/UI-Material%203-7C4DFF.svg)]()
[![Updates](https://img.shields.io/badge/Changelog-Updates.md-brightgreen.svg)](Updates.md)
[![License](https://img.shields.io/badge/License-Apache%202.0%20w%2F%20Commons%20Clause-blue.svg)](LICENSE)

**Fuel Metrics** is a private, modern, cross-platform mobile application designed for Android and iOS to keep detailed, private records of vehicle fuel consumption, track running expenses, compute granular efficiency analytics, and monitor periodic vehicle maintenance—all stored locally with built-in encryption, full JSON backup/restore portability, and tamper-evident audit tracking.

---

## 🌟 Key Features

### ⚡ Automated Fuel Feeder & 5-Tier Fallback Engine
- **Tier 1 (Apple CarPlay & Android Auto Tandem)**: Detects ignition fuel jump ($\ge +10\%$) combined with head-unit attachment for zero-touch logging.
- **Tier 2 (Real-Time OBD-II BLE Sensors)**: Reads live fuel level and odometer directly from Bluetooth ELM327 adapters with dynamic 5-reading anti-slosh filtering.
- **Tier 3 (Manual Quick-Draft & Photo EXIF)**: Rapid capture of pump displays with deferred OBD telemetry injection.
- **Tier 4 (Motion Pit-Stop Fingerprinting)**: Automatically flags 3–10 minute stops near fuel amenities.
- **Tier 5 (Delayed ECU Math & Trip Back-Calculation)**: Uses fuel burn math to distinguish real refuels from fluid slosh and back-calculate trip odometers.

### 🔋 Hardware-Gated Power Lifecycle (`PowerLifecycleState`)
- **4-State State Machine**: `DORMANT_SUSPENDED`, `ACTIVE_CRUISE_TELEMETRY`, `REFUEL_WATCH_WINDOW`, and `TEARDOWN_AND_SCRUB`.
- **Zero Background BLE Scanning**: BLE peripheral scanning is strictly restricted to foreground pairing.
- **OS-Managed Passive Auto-Connect**: GATT auto-connect wakes sessions only when dongles power on.
- **Adaptive Exponential Cruise Backoff**: PID polling scales ($15\text{s} \rightarrow 30\text{s} \rightarrow 60\text{s}$) during drives, keeping radio and CPU idle $>96\%$ of the trip.
- **180s Hard Refuel Watch Window**: $1\text{Hz}$ fuel polling upon engine stop with immediate traffic light green recovery (`RPM > 0`).
- **Single-Shot GPS Gating**: Bounded by a strict 5-second timeout, completely eliminating continuous location drain.
- **Deterministic Teardown & RAM Scrubbing**: Purges all ephemeral telemetry from memory upon completion.

### 🔒 GDPR-by-Design Privacy Architecture
- **100% On-Device Storage**: Zero external servers, zero scraping, and zero tracking.
- **First-Run Onboarding Flow**: Clear disclosure with granular opt-in or seamless Manual Mode continuation.
- **Granular Settings Toggles**: Plain-English confirmation modals when turning off automated features.
- **Exact 64-Bit Integer Schema**: Scaled integers (`volumeMilliliters`, `odometerMeters`, `totalCostCents`, `timestampEpochSec`) eliminate floating-point drift while maintaining backward compatibility.

---

### 🚗 Multi-Vehicle Garage Management
- **Detailed Vehicle Profiling:** Record vehicle name, brand, owner, vehicle type, fuel grade/type (`Regular (87)`, `Premium (93)`, `Diesel`, etc.), purchase date (`Date Bought`), and initial odometer reading.
- **Dynamic Ownership Tracking:** Automatically calculates and displays real-time ownership duration (years, months, and days) from the purchase date.
- **Custom Vector Artwork:** Handcrafted, scalable vector illustrations for 8 vehicle types (SUV, Sedan, Compact, Truck, Coupe, Van, Motorcycle, EV).
- **Single-Tap Navigation:** Switch between cars with a single tap from the garage screen or the quick-switch vehicle sheet, instantly bringing up that vehicle's dashboard.

---

### ⛽ Refueling Logs & Editability
- **Add New Record & Change Existing Records:** Dedicated flows to either log a new fill-up or edit any prior record with full recalculation of subsequent metrics.
- **Date-Only Picker:** Clean calendar picker focused solely on dates without unnecessary time inputs.
- **Regional Gas Station Presets:** Quick-select gas station chips tailored to the selected country (e.g., Shell, Chevron, Exxon, BP, Total, ENOC, ADNOC, IndianOil, etc.).
- **Live Calculation Preview:** Dynamic preview showing computed distance, unit price, and fuel efficiency before saving.

---

### 📊 Calculated Fuel & Financial Metrics
For every refueling record, the app automatically calculates and displays:
- **Distance Driven ($\Delta\text{dist}$):** Distance traveled since the previous record.
- **Fuel Efficiency:** Calculated for each refuel in **km/L**, **L/100km**, or **MPG**.
- **Price Delta & Trend:** Price increase or decrease (nominal value and percentage) compared to the prior refuel.
- **Price per Unit:** Cost per litre or gallon.
- **Days Since Last Fueled:** Precise time elapsed since the most recent fill-up date (`DateTime.now() - Last Entry Date`).
- **Running Cost per Distance:** Cost per kilometre or mile driven.
- **Combined Lifetime Statistics:** Overall dashboard displaying total distance driven, total fuel consumed, total money spent, lifetime average fuel economy, and total refuel visits.

---

### 📈 Data Grid View & Interactive Trend Charting
- **Data Grid View:** View every accessible metric in a structured table format with pinned selection, **sticky headers** that remain pinned at the top and fully interactable during vertical scrolling, and synchronized horizontal scrolling.
- **Distance Travelled Alignment:** Positioned immediately adjacent to the Odometer column for intuitive tracking.
- **Color-Coded Efficiency & Consumption Deltas:** Displays the incremental change vs. prior refuel (e.g., `16.00 km/L (+1.00)`), color-coded **green for increases** and **orange for decreases**.
- **One-Tap Trend Graphs (Last 8 Records):** Tap any column header (Distance, Odometer, Price, Fuel Amount, Fuel Efficiency, Cost/km) to view an interactive line chart focused on the last 8 records.
- **Two-Line Month/Date X-Axis & Dark High-Contrast Numerals:** Displays month abbreviations along the x-axis, and automatically formats consecutive records within the same month across two lines (`(month)\n(date)`). Both axes feature bold slate-800 high-contrast typography with a 20% y-axis buffer to ensure trend lines never touch or dip into axis text.
- **CSV & Template Exporters:** One-tap export of records and official sample CSV templates directly to the device's public Downloads directory (`/storage/emulated/0/Download`).
- **Standardized Date Formats:** Clean, universal `DD-Month(abbreviation)-YY` formatting (e.g. `16-Oct-26`) across all screens, tables, and exports.
- **Thick Stamped License Plates:** Authentic stamped metal license plate badges (`2.0px` solid black border, heavy typography, and subtle drop shadow) across Home, Garage, Add/Edit Vehicle, and Add Record screens.

---

### 🔧 Servicing Tracker
- **Scheduled Maintenance Tracking:** Keeps a structured record of vehicle servicing events, oil changes, and inspection notes.
- **Non-Intrusive In-App Alert Banner:** Alerts appear directly inside the app below vehicle details when a 6-month service is approaching (within 30 days) or overdue.
- **Zero Push Notification Noise:** No background battery drain or spammy OS push notifications; alerts are visible exclusively when you open the app.

---

### ⚙️ Centralized Settings & Customization
- **Country & Currency Synchronization:** Select your country of residence to automatically configure the appropriate currency symbol and regional gas station presets.
- **Simplified Dropdown Selectors:** Centralized dropdown selectors for Distance (`km`, `mi`), Volume (`L`, `gal`), and Efficiency (`km/L`, `L/100km`, `MPG`).
- **Dark & Light Themes:** Toggle between dark mode and clean light mode with adaptive Material 3 color palettes.
- **Bright High-Contrast App Icon & Logo:** High-contrast, vibrant palette icon depicting a person filling a sedan from behind with bright neon accents.
- **Data Backup & Restore:** Complete JSON snapshot export/import with one-tap clipboard copy and file backup for total peace of mind.

---

### 🔒 Privacy, Local Storage & Security
- **Local Application Data Directory:** All records, settings, and logs are stored in a dedicated app directory (`<app_documents>/FuelMetricsData/`).
- **Production Package ID & Permanent Keystore:** Configured with `com.aktron.fuelmetrics` and dedicated release signing for seamless, conflict-free updates forever.
- **Basic Encryption:** Fuel logs are saved encrypted in `records.enc` to protect against unauthorized direct reading or external file tampering outside the app.
- **Private Tamper-Evident Timestamps:** Every record maintains non-user-editable internal timestamps (`createdTimestamp`, `lastModifiedTimestamp`) for audit validation.
- **Audit Logging:** An internal `audit_logs.txt` log records operations and security checkpoints locally.

---

## 🏗️ Project Architecture

```
fuel_records/
├── android/                   # Android native configuration & Gradle scripts
├── ios/                       # iOS native configuration & Xcode project
├── lib/
│   ├── main.dart              # App entry point, MultiProvider & Theme setup
│   ├── models/
│   │   ├── vehicle.dart           # Vehicle model, types, dateBought & ownership logic
│   │   ├── fuel_record.dart       # Fuel record model with private audit timestamps
│   │   ├── service_record.dart    # 6-month vehicle maintenance model
│   │   ├── record_calculation.dart# Per-record delta calculations & conversions
│   │   └── vehicle_stats.dart     # Lifetime combined aggregate analytics
│   ├── screens/
│   │   ├── home_screen.dart           # Dashboard, stats, service banner & actions
│   │   ├── add_edit_record_screen.dart# Fuel record entry & modification form
│   │   ├── add_edit_vehicle_sheet.dart# Vehicle creation & editing bottom sheet
│   │   ├── vehicles_screen.dart       # Garage manager with single-tap navigation
│   │   ├── records_table_screen.dart  # Excel table & interactive trend chart viewer
│   │   ├── services_screen.dart       # 6-month service history & log manager
│   │   └── settings_screen.dart       # Country, currency, units & theme settings
│   ├── services/
│   │   ├── country_data.dart      # Regional presets (currencies, gas stations, units)
│   │   └── fuel_app_state.dart    # Central state manager, encryption & file I/O
│   └── widgets/
│       ├── app_logo.dart          # Vector SVG illustration of man fueling car
│       └── vehicle_artwork.dart   # Vector illustrations for 8 vehicle types
├── test/
│   └── widget_test.dart       # Unit calculation & UI smoke test suite
├── pubspec.yaml               # Dependencies & assets configuration
└── README.md                  # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.19 or higher)
- [Dart SDK](https://dart.dev/get-dart) (version 3.3 or higher)
- Android Studio / VS Code with Flutter extension
- Android SDK (API level 21+) or Xcode (for iOS builds)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/fuel-metrics.git
   cd fuel-metrics/fuel_records
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run static analysis and tests:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Run the application:**
   - On a connected Android device or emulator:
     ```bash
     flutter run -d android
     ```
   - On an iOS simulator (macOS required):
     ```bash
     flutter run -d ios
     ```

---

## 📦 Building Production Binaries

### Android APK
To compile a standalone release APK:
```bash
flutter build apk --release
```
The output binary will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (AAB for Google Play)
```bash
flutter build appbundle --release
```

### iOS IPA (Requires macOS & Xcode)
```bash
flutter build ipa --release
```

---

## 🛡️ Security & Privacy Notice
All records and personal vehicle metrics remain strictly on your physical device. No telemetry, analytics, or private log files are transmitted to external cloud servers. Records are secured locally using encryption within the app's dedicated storage directory.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

