# 🚀 Fuel Metrics — Release Updates & Changelog

All notable changes, feature releases, database migrations, and platform updates for **Fuel Metrics** are documented in this file.

---

## [Version 1.1.1] — Stable Release (Current)

### 🌟 New Features & Enhancements

#### 🤖 Layer 4: AI Data Cleaner (Convert via Gemini / ChatGPT)
- **1-Click AI Formatting Assistant**:
  - Embedded `GeminiFallbackCard` in the Import Screen, automatically highlighted when local parsers detect 0 rows or high error rates.
  - Step 1: One-tap button (`Copy Prompt & Open Gemini`) copies strict formatting instructions to the clipboard and opens `https://gemini.google.com/app` in the external browser or Gemini mobile app (with optional ChatGPT quick-link).
  - Explicit privacy disclaimer and explanation informing users of third-party processing before using external AI.
- **Direct Paste-to-Parser Engine**:
  - Step 2: Multi-line paste area allowing users to paste Gemini's output directly into the app without having to save a `.csv` file.
  - `cleanMarkdownFences()` automatically sanitizes markdown wrappers (```` ```csv ```` and ```` ``` ````), strips invisible zero-width unicode characters, and normalizes line breaks.
  - Feeds cleaned data straight into `FileParserService` and `ImportPreviewScreen`.

#### 📱 Import UI Enhancements
- **Bottom-Positioned Action Controls**:
  - Relocated **Cancel (Red `#DC2626`)** and **Accept (Green `#16A34A`)** buttons from the top header into a pinned bottom navigation bar.
  - Added bottom padding to the table scroll views so that all data rows remain fully visible above the bottom controls.

#### ⛽ Fuel Grade Database Propagation
- **Universal Fuel Type Sync**:
  - When a vehicle's default fuel type (fuel grade) is edited or changed in vehicle details, all historical and existing records for that vehicle in the database automatically update to reflect the new fuel grade.

#### 💾 Public Downloads Folder Integration
- **Direct Public File Export**:
  - Standalone JSON full database backups are saved directly into the device's public Downloads directory (`/storage/emulated/0/Download` on Android, system Downloads on desktop/iOS).
  - Grid view table CSV exports are saved directly to the public Downloads folder for easy file management and sharing.
  - Maintained redundant internal storage mirroring to protect against external file deletion.

---

## [Version 1.1.0] — Previous Release

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

#### 🛠️ Platform & Build System Optimizations
- **Android SDK 36 Compatibility**:
  - Upgraded main application `compileSdk = 36` in `android/app/build.gradle.kts`.
  - Injected dynamic subproject SDK configuration in `android/build.gradle.kts` to safely align all transitive dependencies (e.g., `flutter_plugin_android_lifecycle`, `file_picker`) to Android SDK 36, eliminating `checkDebugAarMetadata` emulator and device build failures.
- **GitHub Actions Modernization**:
  - Upgraded Java runtime setup to `actions/setup-java@v5` with Temurin JDK 17 and Gradle build caching.
  - Migrated CI/CD runner execution environment to **Node.js 24** (`ACTIONS_RUNNER_FORCE_ACTIONS_NODE_VERSION: 'node24'` and `actions/setup-node@v4` with `node-version: 24`).
  - Added repository-level `.nvmrc` and `.node-version` locks to enforce Node.js 24 consistency.
- **Codebase Optimization & Pruning**:
  - Deprecated and removed redundant `lib/screens/text_import_review_screen.dart` (554 lines of superseded logic), unifying both spreadsheet files and unstructured text through `ImportPreviewScreen`.
  - Zero lint warnings (`flutter analyze`) and 100% green test suite across 23 unit and widget test cases.
- **Global Graphify Skill & Architecture Map**:
  - Installed `graphifyy` and registered the global Antigravity skill (`~/.gemini/config/skills/graphify/SKILL.md`).
  - Extracted complete project AST knowledge graph into `graphify-out/graph.json` (788 nodes, 1025 edges, 40 communities).
  - Generated standalone interactive visual maps (`graphify-out/graph.html` and `graphify-out/GRAPH_TREE.html`).

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

