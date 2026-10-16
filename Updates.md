# 🚀 Fuel Metrics — Release Updates & Changelog

All notable changes, feature releases, database migrations, and platform updates for **Fuel Metrics** are documented in this file.

---

## [Version 1.1.0] — Stable Release (Current)

### 🌟 New Features & Enhancements

#### 📝 Smart Unstructured Text Import
- **Natural Language & Receipt Parser**: Convert raw notes, SMS payment alerts, and unstructured receipt text directly into structured fuel records without external cloud APIs or third-party tracking.
- **Dedicated Import Flow**: Accessible via the "Import Data from Text" button when adding new vehicle records or from the Records List screen. Features an educational walkthrough card and one-tap template chips (SMS/Receipt Note, Gallon/US format, Compact quick-log).
- **Expanded Synonyms for Odometer**:
  - Prefix keywords: `distance`, `dist`, `kms`, `km`, `kilometres`, `kilometers`, `miles`, `mi`, `odometer`, `odo`, `reading`, `readings`, `meter`, `dash`, `clock`, `clocked`, `counter`, `travelled`, `traveled`.
  - Suffix units: `54000 km`, `54000 kms`, `54000 distance`, `54000 dist`, `54000 miles`, `54000 mi`.
- **Expanded Synonyms for Fuel Quantity**:
  - Prefix keywords: `petrol`, `diesel`, `gas`, `gasoline`, `fuel`, `quantity`, `qty`, `volume`, `vol`, `litres`, `liters`, `ltrs`, `gallons`, `gals`, `filled`, `pumped`, `dispensed`, `refuel`, `refueled`, `put in`, `added`.
  - Suffix units: `45.2 petrol`, `40 diesel`, `12 gas`, `45.2 litres`, `45.2 liters`, `45.2 ltrs`, `45.2 L`, `12.4 gallons`, `12.4 gal`.
- **Strict Column Validation (No Forced Guesswork)**:
  - If a column keyword or unit is absent, numbers are **never forced** into the odometer, fuel volume, or price columns.
  - Residual numbers and text are safely routed to record notes for transparent inspection.
- **Dual-Action Review Data Grid Screen**:
  - Before committing parsed records to storage, all rows are displayed in an editable, dual-axis scrollable data grid.
  - In-cell text editing for odometer, fuel quantity, total price, gas station, and notes.
  - Interactive date picker chips and fuel grade dropdown selectors.
  - **Top Action Controls**:
    - **Cancel** (`#DC2626` Red Background): Confirms cancellation and discards uncommitted parsed drafts.
    - **Accept** (`#16A34A` Green Background): Validates all entries and commits an atomic batch write to local storage with encrypted backup and audit logging.

#### 🔄 In-Place Upgrade & Data Integrity Guarantee
- **Clean In-Place Replacement**:
  - Built with a permanent release signing keystore (`fuel_metrics_release.jks`) and unified application ID `com.aktron.fuelmetrics`.
  - Upgrading the app replaces the existing version in-place without creating duplicate "clone" apps or failing with "package conflict" errors.
- **Zero Data Reset**:
  - All car profiles, fuel records, service logs, and custom settings stored in internal storage (`<app_documents>/FuelMetricsData/`) and `SharedPreferences` are completely preserved during updates.
  - Explicit `android:allowBackup="true"` configuration enabled.

---

## [Version 1.0.2]

### 🔒 Security, Signing & Visual Identity
- **Permanent Release Keystore**: Configured `fuel_metrics_release.jks` in Android Gradle build configuration to guarantee identical signature verification across all future GitHub releases.
- **Package Conflict Resolution**: Standardized namespace and application ID to `com.aktron.fuelmetrics`.
- **Brighter High-Contrast App Launcher Icon**:
  - Redesigned silhouette icon featuring a man refueling a sedan viewed from behind.
  - Vibrant cyan-to-royal-blue radial background gradient with elevated golden fuel nozzle accents and clean contrast.
  - Generated and packaged for all standard Android mipmap densities and iOS AppIcon catalog sizes.
- **Full Database Backup & Restore**:
  - Added standalone JSON export (`Export Full Backup (.json)`) and restore (`Import Backup (.json)`) in Settings for manual offsite backup and device migration.

---

## [Version 1.0.1]

### 📊 Grid Enhancements & Centralized Preferences
- **Centralized Settings Architecture**:
  - Relocated currency, distance unit, volume unit, and country preferences from individual vehicle forms into the centralized Settings screen.
  - Country selection dropdown with automatic regional presets.
- **Data Grid View Upgrades**:
  - Renamed from Table View to **Data Grid View**.
  - Positioned **Distance Travelled** column immediately adjacent to **Odometer** for intuitive comparison.
  - Added color-coded efficiency and consumption diff indicators:
    - Green (`+` / positive efficiency trend).
    - Orange (`-` / decreased efficiency trend).
  - Elevated bottom scroll padding to prevent navigation bar obstruction.
- **Universal Date Format**: Standardized all date displays to `DD-Month(abbr)-YY` (e.g. `16-Oct-26`).
- **Days Since Last Refuel**: Real-time dynamic calculation based on current date minus last refueling date (`DateTime.now() - Last Entry Date`).
- **Standalone CSV File Export**: One-tap export to `.csv` on local device storage with clipboard copy support.
- **Servicing Quick Access**: Direct shortcut button and non-intrusive 6-month maintenance tracking banner.

---

## [Version 1.0.0] — Initial Release

### 🚗 Core Capabilities
- Multi-vehicle garage profiling with custom vector artwork for 8 body types.
- Fuel logging with price, distance, consumption, and efficiency calculations (km/L, L/100km, MPG).
- Interactive line charts powered by `fl_chart`.
- Encrypted local storage with XOR cipher and SHA-256 integrity verification.
- Tamper-evident private audit action logging.
- Light and dark theme switching.
