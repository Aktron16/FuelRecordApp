# Fuel Metrics (Version 1.0.0)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2.svg?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)]()
[![Material Design](https://img.shields.io/badge/UI-Material%203-7C4DFF.svg)]()
[![License](https://img.shields.io/badge/License-MIT-amber.svg)](LICENSE)

**Fuel Metrics** is a private, modern, cross-platform mobile application designed for Android and iOS to keep detailed, private records of vehicle fuel consumption, track running expenses, compute granular efficiency analytics, and monitor periodic 6-month vehicle maintenance—all stored locally with built-in encryption and tamper-evident audit tracking.

---

## 🌟 Key Features

### 🚗 Multi-Vehicle Garage Management
- **Detailed Vehicle Profiling:** Record vehicle name, brand, owner, vehicle type, purchase date (`Date Bought`), and initial odometer reading.
- **Dynamic Ownership Tracking:** Automatically calculates and displays real-time ownership duration (years, months, and days) from the purchase date.
- **Custom Vector Artwork:** Handcrafted, scalable vector illustrations for 8 vehicle types:
  - SUV
  - Sedan
  - Compact / Hatchback
  - Pickup Truck
  - Coupe / Sports Car
  - Van / Minivan
  - Motorcycle
  - Electric Vehicle (EV)
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
- **Days Since Last Fueled:** Number of days elapsed between fuel stops.
- **Running Cost per Distance:** Cost per kilometre or mile driven.
- **Combined Lifetime Statistics:** Overall dashboard displaying total distance driven, total fuel consumed, total money spent, lifetime average fuel economy, and total refuel visits.

---

### 📈 Excel / Table View & Interactive Trend Charting
- **Spreadsheet Table View:** View every accessible metric in a scrollable, structured table format.
- **One-Tap Trend Graphs:** Tap any column header (Distance, Odometer, Price, Fuel Amount, Fuel Efficiency, Cost/km) to view an interactive line chart powered by `fl_chart`.
- **Chart Telemetry:** Interactive line graphs display minimum, maximum, and average values with smooth Bezier curves and timestamp-labeled axes.
- **Instance-Based Unit Switching:** Temporarily toggle units (e.g., switch from `km/L` to `L/100km` or `MPG`) on any metric card during your session without permanently altering your settings. Defaults automatically revert upon app relaunch.

---

### 🔧 6-Month Vehicle Servicing Tracker
- **Scheduled Maintenance Tracking:** Keeps a structured record of vehicle servicing events, oil changes, and inspection notes.
- **Non-Intrusive In-App Alert Banner:** Alerts appear directly inside the app below vehicle details when a 6-month service is approaching (within 30 days) or overdue.
- **Zero Push Notification Noise:** No background battery drain or spammy OS push notifications; alerts are visible exclusively when you open the app.

---

### ⚙️ Centralized Settings & Customization
- **Country & Currency Synchronization:** Select your country of residence (USA, UK, Canada, Australia, India, Germany, France, UAE, Japan, Brazil, etc.) to automatically configure the appropriate currency symbol and regional gas station presets.
- **Simplified Dropdown Selectors:** Centralized dropdown selectors for Distance (`km`, `mi`), Volume (`L`, `gal`), and Efficiency (`km/L`, `L/100km`, `MPG`).
- **Dark & Light Themes:** Toggle between dark mode and clean light mode with adaptive Material 3 color palettes.
- **Custom Brand Identity:** Custom vector brand logo (`FuelManLogo`) featuring a man refueling a vehicle viewed from behind.

---

### 🔒 Privacy, Local Storage & Security
- **Local Application Data Directory:** All records, settings, and logs are stored in a dedicated app directory (`<app_documents>/FuelMetricsData/`).
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

## 🤖 Automated GitHub Releases (Android & iOS)

A complete CI/CD workflow is included in `.github/workflows/release.yml`. When you push this project to GitHub, you can publish a new release with compiled Android & iOS binaries in two ways:

### Method 1: Push a Git Tag (Recommended)
```bash
git tag v1.0.0
git push origin v1.0.0
```
This triggers GitHub Actions to automatically:
1. Run `flutter analyze` and `flutter test`.
2. Compile the Android release APK (`FuelMetrics-v1.0.0-android.apk`) and App Bundle (`FuelMetrics-v1.0.0-android.aab`).
3. Compile the iOS application bundle (`FuelMetrics-v1.0.0-ios-unsigned.ipa` and `Runner.app.zip`) on a macOS runner.
4. Create a formal GitHub Release and attach all binaries automatically.

### Method 2: Manual Trigger via GitHub UI
1. Navigate to the **Actions** tab on your GitHub repository.
2. Select **"Release Fuel Metrics"** from the left sidebar.
3. Click **"Run workflow"**, specify the version tag (e.g. `v1.0.0`), and run.

---

## 🛡️ Security & Privacy Notice
All records and personal vehicle metrics remain strictly on your physical device. No telemetry, analytics, or private log files are transmitted to external cloud servers. Records are secured locally using encryption within the app's dedicated storage directory.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
