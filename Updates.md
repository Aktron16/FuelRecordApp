# 🚀 Fuel Metrics — Release Updates & Changelog

All notable changes, feature releases, database migrations, and platform updates for **Fuel Metrics** are documented in this file.

---

## [Version 1.1.3] — Current Release

### 🛠️ Bug Fixes & Layout Responsiveness
- **Layout Overflow Elimination**:
  - Fixed `RenderFlex overflowed by 10 pixels on the right` in `GeminiFallbackCard` Step 2 header by wrapping the title in `Expanded` and streamlining the action button to `Paste` (with tooltip).
  - Fixed `RenderFlex overflowed by 18 pixels on the right` in `SettingsScreen`'s Fuel Efficiency dropdown by setting `isExpanded: true` and `TextOverflow.ellipsis`.
  - Added `isExpanded: true` and text truncation across all dropdowns in the app:
    - `Country`, `Distance Unit`, `Volume Unit`, `Fuel Efficiency`, and `Currency` in Settings Screen.
    - `Default Fuel Grade` in Vehicle Creation/Edit Sheet.
    - `Service Type` in Vehicle Maintenance & Services Screen.
    - `Fuel Grade` in Spreadsheet Import dialog.
  - Added responsive `LayoutBuilder` in `GeminiFallbackCard` Step 1 to dynamically stack `Copy & Open Gemini` and `ChatGPT` buttons when container width is under 290px.
  - Fixed Card header column overflows in Settings Screen by enclosing title columns in `Expanded`.
  - Fixed backup and data management button row overflow by wrapping `Clear All` and `Demo Data` buttons in `Expanded` with `FittedBox`.
- **Build & JVM Optimization**:
  - Added `--enable-native-access=ALL-UNNAMED` to `org.gradle.jvmargs` in `android/gradle.properties` to eliminate JVM warnings when compiling on modern Java 21+ / 24 runtimes.
- **Beautified Licensing**:
  - Cleanly formatted and aligned the Apache 2.0 License with Commons Clause Condition with elegant section dividers in both root `LICENSE` and `fuel_records/LICENSE`.
- **Automated Viewport Regression Tests**:
  - Added `v1_1_3_layout_test.dart` to assert 0 layout overflows on compact 317px and 320px mobile viewport widths.

---

## [Version 1.1.2] — Previous Release

### 🌟 New Features & Enhancements

#### 🎨 UI/UX Decluttering & Refined Button Styling
- **Concise Copywriting**: Removed redundant parenthetical specifications and technical jargon across all headings, metrics, and cards (e.g., "Overall Stats", "Clean with AI", "Key Metrics", "Trends").
- **Tastefully Elevated Buttons**: Upgraded primary and secondary buttons across the app with subtle drop shadows, 10–12px rounded corners, clear leading icons, and polished tap feedback.

#### 📑 Redesigned "Import Fuel Data" Page (Tabbed Method Selector)
- **3-Pill Segmented Selector**: Switch seamlessly between three import methods via a modern segmented pill bar:
  - `Pick File (.csv, .xlsx)`: Direct spreadsheet file picker with sample template generator.
  - `Paste Text`: Multi-line text field to directly paste CSV/TSV table rows or receipts.
  - `Clean with AI`: Integrated Gemini AI data cleaner fallback card.
- **Dynamic Action Area**: Contextual instructions and tools display dynamically based on the active tab without screen clutter.
- **Sticky Bottom Action Bar**: Redesigned bottom navigation bar with Cancel (red `#DC2626`) and Accept (green `#16A34A`) buttons with responsive bottom padding.

#### 🚗 Car License Plate, Profile Picture (PFP) & Banner Image
- **Vehicle Customization**:
  - Added License Plate tracking with uppercase auto-capitalization and pill badges.
  - Added camera and gallery pickers for car Profile Pictures (avatars) and Banner Images (cover photos).
  - Integrated native image compression on capture (512×512 for PFP, 1280×720 at 80% quality for banners) to prevent memory overhead.
  - PFP displayed across the Garage and Home Screen, with banner image and gradient scrim overlay displayed on the Home hero overview card.
  - Image removal support and automatic local file purging when deleting vehicles.

#### 📊 Grid View Table Updates (Sticky Selection Column)
- **Sticky Leftmost Checkbox Column**: Pinned ~52px selection column remains strictly fixed during horizontal scrolling of wide data columns, utilizing dual synchronized vertical controllers.
- **Master Select All**: Checkbox in the table header toggles all visible records simultaneously.
- **Floating Multi-Select Action Bar**: Appears at the bottom when rows are selected, showing selected count, "Deselect All", and a red "Delete Selected" button.
- **Removed Fuel Grade Column**: Cleaned up the table by eliminating the redundant "Fuel Grade" column from headers and data rows.

#### 🛡️ Safe Record Deletion & Backup Checkbox
- **Accidental Deletion Prevention**: Prominent confirmation dialogs detail the exact number of records or data being deleted.
- **Create Backup Before Deletion Checkbox**: Every deletion modal (single record deletion in edit sheets, bulk deletion in grid view table, cascade vehicle deletion in Garage, and clear all data in Settings) includes an explicit `[x] Create backup before deletion` checkbox that saves a complete JSON snapshot to Downloads before executing the deletion.

#### ⚡ Performance & Data Architecture Optimizations
- **In-Memory Indexing**: Added `_recordsByVehicleId` and sorted date lookups for $O(1)$ and instant query times.
- **Memoized Statistics Cache**: Reusable `_statsCache` eliminates redundant KPI recalculation on UI rebuilds.
- **Atomic File Writing**: File writes use temporary file replacement (`.tmp` -> replace destination) to prevent file corruption during sudden app termination or power loss.
- **Atomic Batch Deletions**: Single-pass `deleteRecordsBatch()` deletes multi-selected records in an atomic transaction.

#### 🌍 45-Country Presets Dataset & Custom Currency Box
- **Comprehensive Country Database**: Expanded `CountryRepository` to 45 major countries with ISO codes, currency symbol/code (USD, EUR, GBP, JPY, CAD, AUD, etc.), default units, popular station brands, and regional fuel grades.
- **Custom Currency Box**: Retained the editable custom currency text box in Settings so users can override default currency symbols anytime.

#### 📜 Licensing (Apache 2.0 with Commons Clause)
- **Open Source with Non-Sale Restriction**: Added official `LICENSE` file containing the Apache License 2.0 with the Commons Clause ("Nothing in this License grants any right to 'Sell' the Software").

---

## [Version 1.1.1] — Previous Release

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

