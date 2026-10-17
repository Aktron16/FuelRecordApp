# 🚀 Fuel Metrics — Release Updates & Changelog

All notable changes, feature releases, database migrations, and platform updates for **Fuel Metrics** are documented in this file.

---

## [Version 1.1.0] — Stable Release (Current)

### 🌟 New Features & Enhancements

#### 📊 3-Layer Hybrid Import System (Spreadsheets & Text)
- **Layer 1: Official Template Generation (`exportSampleTemplate()`)**:
  - One-tap download and sharing of clean `.csv` sample files containing canonical database headers and realistic example fuel data.
- **Layer 2: Universal File Reader & Auto-Header Detector**:
  - Reads `.csv`, `.tsv`, and Microsoft Excel `.xlsx` spreadsheets (with multi-sheet auto-selection).
  - Skips non-data title banners automatically until rows with $\ge 3$ columns appear.
  - **Header Nickname Dictionary**: Matches normalized column nicknames with prioritized multi-word matching (`Cost Per Liter`, `Mileage (KM)`, `Ltrs Pumped`, `Amount Paid`).
  - **Math Fallback Rule**: Solves missing headers by discovering numeric triplets where $|A \times B - C| \le 0.05$, mapping $C \to \text{totalCost}$, $\min(A,B) \to \text{pricePerUnit}$, and $\max(A,B) \to \text{fuelVolume}$.
  - **Data Cleaner**: Strips currency signs (`$`, `AED`, `€`, `£`, `₹`), unit suffixes (`L`, `km`, `mi`), and parses multiple date styles (`YYYY-MM-DD`, `DD/MM/YYYY`, `MM/DD/YYYY`, `15-Oct-26`).
- **Layer 3: Interactive Column-Mapper & Staging Preview UI**:
  - Clear 1-paragraph non-technical explanation banner on arrival.
  - Interactive dropdown selector over every column pre-populated with auto-detected fields.
  - Quarantine view highlighting incomplete rows, routing raw unparseable data to `notes`, and providing inline cell editors plus a "Skip invalid rows" toggle.
  - Prominent top action buttons: **Cancel (Red `#DC2626`)** and **Accept (Green `#16A34A`)**.
- **Component D: Atomic Database Batch Insert**:
  - `FuelAppState.importSpreadsheetRecordsBatch()` commits all records in a single atomic memory and disk transaction with SHA-256 encrypted persistence and audit logging.

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

