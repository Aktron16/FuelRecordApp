import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../models/service_record.dart';
import '../models/record_calculation.dart';
import '../models/vehicle_stats.dart';
import '../utils/app_date_format.dart';
import 'country_data.dart';

class FuelAppState extends ChangeNotifier {
  static const String _keyVehicles = 'fuel_app_vehicles';
  static const String _keyRecords = 'fuel_app_records';
  static const String _keyServices = 'fuel_app_services';
  static const String _keyActiveVehicleId = 'fuel_app_active_vehicle_id';
  static const String _keyThemeMode = 'fuel_app_theme_mode';
  static const String _keyCountry = 'fuel_app_country';
  static const String _keyDefaultCurrency = 'fuel_app_default_currency';
  static const String _keyDefaultDistUnit = 'fuel_app_default_dist_unit';
  static const String _keyDefaultVolUnit = 'fuel_app_default_vol_unit';
  static const String _keyDefaultEffUnit = 'fuel_app_default_eff_unit';

  // Secret cipher key for basic encryption of offline records file
  static const String _cipherKey = 'FuelMetricsSecureVault2026_KeyX!';

  List<Vehicle> _vehicles = [];
  List<FuelRecord> _records = [];
  List<ServiceRecord> _services = [];
  String? _activeVehicleId;
  ThemeMode _themeMode = ThemeMode.system;

  // Settings
  String _selectedCountry = 'United States';
  String _defaultCurrency = '\$';
  String _defaultDistanceUnit = 'mi';
  String _defaultVolumeUnit = 'gal';
  String _defaultEfficiencyUnit = 'MPG';

  // Temporary in-memory unit overrides for current session (reverts on app reopen)
  String? _tempEfficiencyUnit;
  String? _tempDistanceUnit;
  String? _tempVolumeUnit;

  bool _isLoading = true;
  String _appDataFolderPath = '';
  final Directory? customStorageDir;

  FuelAppState({this.customStorageDir, bool autoLoad = true}) {
    if (autoLoad) {
      loadFromStorage();
    }
  }

  // Getters
  bool get isLoading => _isLoading;
  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<FuelRecord> get allRecords => List.unmodifiable(_records);
  List<ServiceRecord> get allServices => List.unmodifiable(_services);
  ThemeMode get themeMode => _themeMode;
  String get selectedCountry => _selectedCountry;
  String get defaultCurrency => _defaultCurrency;
  String get defaultDistanceUnit => _defaultDistanceUnit;
  String get defaultVolumeUnit => _defaultVolumeUnit;
  String get defaultEfficiencyUnit => _defaultEfficiencyUnit;
  String get appDataFolderPath => _appDataFolderPath;

  // Active units considering temporary in-memory toggles
  String get activeEfficiencyUnit => _tempEfficiencyUnit ?? _defaultEfficiencyUnit;
  String get activeDistanceUnit => _tempDistanceUnit ?? _defaultDistanceUnit;
  String get activeVolumeUnit => _tempVolumeUnit ?? _defaultVolumeUnit;

  // Temporary toggles (in-memory only, not saved to disk)
  void setTemporaryEfficiencyUnit(String unit) {
    _tempEfficiencyUnit = unit;
    notifyListeners();
  }

  void setTemporaryDistanceUnit(String unit) {
    _tempDistanceUnit = unit;
    notifyListeners();
  }

  void setTemporaryVolumeUnit(String unit) {
    _tempVolumeUnit = unit;
    notifyListeners();
  }

  CountryInfo get currentCountryInfo => CountryRepository.getCountryByName(_selectedCountry);

  Vehicle? get activeVehicle {
    if (_vehicles.isEmpty) return null;
    if (_activeVehicleId == null) return _vehicles.first;
    return _vehicles.firstWhere(
      (v) => v.id == _activeVehicleId,
      orElse: () => _vehicles.first,
    );
  }

  String? get activeVehicleId => activeVehicle?.id;

  /// Returns records for the active vehicle, sorted by date ascending (oldest first)
  List<FuelRecord> get activeVehicleRecordsAscending {
    final vId = activeVehicleId;
    if (vId == null) return [];
    final list = _records.where((r) => r.vehicleId == vId).toList();
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  /// Returns records for the active vehicle, sorted by date descending (newest first for display)
  List<FuelRecord> get activeVehicleRecordsDescending {
    final list = activeVehicleRecordsAscending;
    return list.reversed.toList();
  }

  /// Returns services for the active vehicle, sorted by date descending
  List<ServiceRecord> get activeVehicleServicesDescending {
    final vId = activeVehicleId;
    if (vId == null) return [];
    final list = _services.where((s) => s.vehicleId == vId).toList();
    list.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    return list;
  }

  /// Calculates vehicle stats for active vehicle
  VehicleStats get activeVehicleStats {
    return VehicleStats.fromRecords(activeVehicleRecordsAscending);
  }

  /// Finds calculation for a given record against its previous chronologically
  RecordCalculation getCalculationForRecord(FuelRecord record) {
    final sorted = activeVehicleRecordsAscending;
    final index = sorted.indexWhere((r) => r.id == record.id);
    if (index > 0) {
      return RecordCalculation(current: record, previous: sorted[index - 1]);
    }
    return RecordCalculation(current: record, previous: null);
  }

  /// 6-Month Servicing Status check for active vehicle
  /// Returns a map with {status: 'ok'|'due_soon'|'overdue', daysRemaining: int, lastServiceDate: DateTime, message: String}
  Map<String, dynamic>? get activeVehicleServiceStatus {
    final v = activeVehicle;
    if (v == null) return null;

    final services = activeVehicleServicesDescending;
    final DateTime referenceDate = services.isNotEmpty
        ? services.first.serviceDate
        : (v.dateBought ?? v.createdAt);

    final now = DateTime.now();
    final daysSince = now.difference(referenceDate).inDays;
    const intervalDays = 182; // ~6 months
    final daysRemaining = intervalDays - daysSince;

    String status;
    String message;

    if (daysRemaining < 0) {
      status = 'overdue';
      final overdueDays = daysRemaining.abs();
      message = '6-Month Service is overdue by $overdueDays days (Last serviced ${daysSince}d ago)';
    } else if (daysRemaining <= 30) {
      status = 'due_soon';
      message = '6-Month Service recommended in $daysRemaining days';
    } else {
      status = 'ok';
      final months = (daysRemaining / 30.4).round();
      message = 'Next service due in ~$months months';
    }

    return {
      'status': status,
      'daysRemaining': daysRemaining,
      'referenceDate': referenceDate,
      'daysSince': daysSince,
      'message': message,
      'hasPriorService': services.isNotEmpty,
    };
  }

  /// Basic symmetric cipher with salt to prevent external editing/tampering in Notepad
  static String _encryptData(String plainText) {
    final bytes = utf8.encode(plainText);
    final keyBytes = utf8.encode(_cipherKey);
    final encrypted = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ keyBytes[i % keyBytes.length] ^ ((i * 7) & 0xFF));
    }
    return base64Encode(encrypted);
  }

  static String _decryptData(String cipherText) {
    final bytes = base64Decode(cipherText);
    final keyBytes = utf8.encode(_cipherKey);
    final decrypted = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      decrypted.add(bytes[i] ^ keyBytes[i % keyBytes.length] ^ ((i * 7) & 0xFF));
    }
    return utf8.decode(decrypted);
  }

  /// Initializes app folder on disk
  Future<Directory> _getAppDirectory() async {
    final customDir = customStorageDir;
    if (customDir != null) {
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }
      _appDataFolderPath = customDir.path;
      return customDir;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final appDir = Directory('${docsDir.path}/FuelMetricsData');
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }
      _appDataFolderPath = appDir.path;
      return appDir;
    } catch (_) {
      final testDir = Directory('${Directory.systemTemp.path}/FuelMetricsData');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      _appDataFolderPath = testDir.path;
      return testDir;
    }
  }

  /// Appends to private audit log file
  Future<void> _logAuditAction(String action) async {
    try {
      final dir = await _getAppDirectory();
      final logFile = File('${dir.path}/audit_logs.txt');
      final timestamp = DateTime.now().toIso8601String();
      logFile.writeAsStringSync('[$timestamp] $action\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// Loads data from encrypted disk files and SharedPreferences
  Future<void> loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dir = await _getAppDirectory();
      final prefs = await SharedPreferences.getInstance();

      // Load Settings
      _selectedCountry = prefs.getString(_keyCountry) ?? 'United States';
      _defaultCurrency = prefs.getString(_keyDefaultCurrency) ?? '\$';
      _defaultDistanceUnit = prefs.getString(_keyDefaultDistUnit) ?? 'mi';
      _defaultVolumeUnit = prefs.getString(_keyDefaultVolUnit) ?? 'gal';
      _defaultEfficiencyUnit = prefs.getString(_keyDefaultEffUnit) ?? 'MPG';

      final themeStr = prefs.getString(_keyThemeMode);
      if (themeStr != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == themeStr,
          orElse: () => ThemeMode.system,
        );
      }

      // Check and migrate legacy files from com.example.fuel_records if accessible
      final vehiclesFile = File('${dir.path}/vehicles.json');
      final recordsEncFile = File('${dir.path}/records.enc');
      final servicesFile = File('${dir.path}/services.json');
      if (!vehiclesFile.existsSync() && !recordsEncFile.existsSync()) {
        try {
          final legacyDirs = [
            Directory('/data/user/0/com.example.fuel_records/app_flutter/FuelMetricsData'),
            Directory('/data/data/com.example.fuel_records/app_flutter/FuelMetricsData'),
          ];
          for (final legDir in legacyDirs) {
            if (legDir.existsSync()) {
              final legVehicles = File('${legDir.path}/vehicles.json');
              final legRecords = File('${legDir.path}/records.enc');
              final legServices = File('${legDir.path}/services.json');
              if (legVehicles.existsSync() && !vehiclesFile.existsSync()) {
                legVehicles.copySync(vehiclesFile.path);
              }
              if (legRecords.existsSync() && !recordsEncFile.existsSync()) {
                legRecords.copySync(recordsEncFile.path);
              }
              if (legServices.existsSync() && !servicesFile.existsSync()) {
                legServices.copySync(servicesFile.path);
              }
            }
          }
        } catch (_) {}
      }

      // 1. Load Vehicles
      if (vehiclesFile.existsSync()) {
        final content = vehiclesFile.readAsStringSync();
        if (content.isNotEmpty) {
          final List decoded = jsonDecode(content) as List;
          _vehicles = decoded.map((item) => Vehicle.fromJson(item as Map<String, dynamic>)).toList();
        }
      } else {
        // Fallback to prefs
        final vJson = prefs.getString(_keyVehicles);
        if (vJson != null && vJson.isNotEmpty) {
          final List decoded = jsonDecode(vJson) as List;
          _vehicles = decoded.map((item) => Vehicle.fromJson(item as Map<String, dynamic>)).toList();
        }
      }

      // 2. Load Encrypted Records (protected against external editing)
      if (recordsEncFile.existsSync()) {
        final encContent = recordsEncFile.readAsStringSync();
        if (encContent.isNotEmpty) {
          try {
            final plainJson = _decryptData(encContent);
            final List decoded = jsonDecode(plainJson) as List;
            _records = decoded.map((item) => FuelRecord.fromJson(item as Map<String, dynamic>)).toList();
          } catch (e) {
            debugPrint('Failed to decrypt records (tampered or corrupted): $e');
            // Try backup from prefs
            final rJson = prefs.getString(_keyRecords);
            if (rJson != null) {
              final List decoded = jsonDecode(rJson) as List;
              _records = decoded.map((item) => FuelRecord.fromJson(item as Map<String, dynamic>)).toList();
            }
          }
        }
      } else {
        final rJson = prefs.getString(_keyRecords);
        if (rJson != null && rJson.isNotEmpty) {
          final List decoded = jsonDecode(rJson) as List;
          _records = decoded.map((item) => FuelRecord.fromJson(item as Map<String, dynamic>)).toList();
        }
      }

      // 3. Load Services
      if (servicesFile.existsSync()) {
        final content = servicesFile.readAsStringSync();
        if (content.isNotEmpty) {
          final List decoded = jsonDecode(content) as List;
          _services = decoded.map((item) => ServiceRecord.fromJson(item as Map<String, dynamic>)).toList();
        }
      } else {
        final sJson = prefs.getString(_keyServices);
        if (sJson != null && sJson.isNotEmpty) {
          final List decoded = jsonDecode(sJson) as List;
          _services = decoded.map((item) => ServiceRecord.fromJson(item as Map<String, dynamic>)).toList();
        }
      }

      _activeVehicleId = prefs.getString(_keyActiveVehicleId);
      if (_vehicles.isNotEmpty && (_activeVehicleId == null || !_vehicles.any((v) => v.id == _activeVehicleId))) {
        _activeVehicleId = _vehicles.first.id;
      }
    } catch (e) {
      debugPrint('Error loading storage: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves data to encrypted app folder on disk and syncs with SharedPreferences
  Future<void> saveToStorage() async {
    try {
      final dir = await _getAppDirectory();
      final prefs = await SharedPreferences.getInstance();

      // 1. Save Vehicles
      final vehiclesJson = jsonEncode(_vehicles.map((v) => v.toJson()).toList());
      final vehiclesFile = File('${dir.path}/vehicles.json');
      await vehiclesFile.writeAsString(vehiclesJson);
      await prefs.setString(_keyVehicles, vehiclesJson);

      // 2. Save Encrypted Records
      final recordsPlainJson = jsonEncode(_records.map((r) => r.toJson()).toList());
      final recordsEncrypted = _encryptData(recordsPlainJson);
      final recordsEncFile = File('${dir.path}/records.enc');
      await recordsEncFile.writeAsString(recordsEncrypted);
      await prefs.setString(_keyRecords, recordsPlainJson);

      // 3. Save Services
      final servicesJson = jsonEncode(_services.map((s) => s.toJson()).toList());
      final servicesFile = File('${dir.path}/services.json');
      await servicesFile.writeAsString(servicesJson);
      await prefs.setString(_keyServices, servicesJson);

      // 4. Save App Settings
      final settingsData = {
        'selectedCountry': _selectedCountry,
        'defaultCurrency': _defaultCurrency,
        'defaultDistanceUnit': _defaultDistanceUnit,
        'defaultVolumeUnit': _defaultVolumeUnit,
        'defaultEfficiencyUnit': _defaultEfficiencyUnit,
        'themeMode': _themeMode.name,
        'activeVehicleId': _activeVehicleId,
      };
      final settingsFile = File('${dir.path}/settings.json');
      await settingsFile.writeAsString(const JsonEncoder.withIndent('  ').convert(settingsData));

      if (_activeVehicleId != null) {
        await prefs.setString(_keyActiveVehicleId, _activeVehicleId!);
      }
      await prefs.setString(_keyCountry, _selectedCountry);
      await prefs.setString(_keyDefaultCurrency, _defaultCurrency);
      await prefs.setString(_keyDefaultDistUnit, _defaultDistanceUnit);
      await prefs.setString(_keyDefaultVolUnit, _defaultVolumeUnit);
      await prefs.setString(_keyDefaultEffUnit, _defaultEfficiencyUnit);
      await prefs.setString(_keyThemeMode, _themeMode.name);
    } catch (e) {
      debugPrint('Error saving storage: $e');
    }
  }

  // Country & Settings Update
  Future<void> setCountry(String countryName) async {
    final info = CountryRepository.getCountryByName(countryName);
    _selectedCountry = info.name;
    _defaultCurrency = info.currency;
    _defaultDistanceUnit = info.defaultDistanceUnit;
    _defaultVolumeUnit = info.defaultVolumeUnit;
    _defaultEfficiencyUnit = info.defaultEfficiencyUnit;

    // Synchronize all vehicles with the centralized default currency and units
    for (int i = 0; i < _vehicles.length; i++) {
      _vehicles[i] = _vehicles[i].copyWith(
        currency: _defaultCurrency,
        unitDistance: _defaultDistanceUnit,
        unitVolume: _defaultVolumeUnit,
      );
    }

    await saveToStorage();
    await _logAuditAction('Changed country to ${info.name} (Currency: ${info.currency}, Dist: ${info.defaultDistanceUnit}, Vol: ${info.defaultVolumeUnit})');
    notifyListeners();
  }

  Future<void> setDefaultUnits({
    required String distanceUnit,
    required String volumeUnit,
    required String efficiencyUnit,
    required String currency,
  }) async {
    _defaultDistanceUnit = distanceUnit;
    _defaultVolumeUnit = volumeUnit;
    _defaultEfficiencyUnit = efficiencyUnit;
    _defaultCurrency = currency;

    // Synchronize all vehicles with the centralized default currency and units
    for (int i = 0; i < _vehicles.length; i++) {
      _vehicles[i] = _vehicles[i].copyWith(
        currency: _defaultCurrency,
        unitDistance: _defaultDistanceUnit,
        unitVolume: _defaultVolumeUnit,
      );
    }

    await saveToStorage();
    await _logAuditAction('Updated default units: $distanceUnit, $volumeUnit, $efficiencyUnit, $currency');
    notifyListeners();
  }

  // Vehicle Management
  Future<void> addVehicle(Vehicle vehicle) async {
    _vehicles.add(vehicle);
    _activeVehicleId = vehicle.id;
    await saveToStorage();
    await _logAuditAction('Added vehicle ${vehicle.name} (${vehicle.brand}, ${vehicle.type.name})');
    notifyListeners();
  }

  Future<void> updateVehicle(Vehicle updated) async {
    final idx = _vehicles.indexWhere((v) => v.id == updated.id);
    if (idx != -1) {
      _vehicles[idx] = updated;
      await saveToStorage();
      await _logAuditAction('Updated vehicle ${updated.name}');
      notifyListeners();
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    _vehicles.removeWhere((v) => v.id == vehicleId);
    _records.removeWhere((r) => r.vehicleId == vehicleId);
    _services.removeWhere((s) => s.vehicleId == vehicleId);

    if (_activeVehicleId == vehicleId) {
      _activeVehicleId = _vehicles.isNotEmpty ? _vehicles.first.id : null;
    }
    await saveToStorage();
    await _logAuditAction('Deleted vehicle ID $vehicleId');
    notifyListeners();
  }

  void setActiveVehicle(String vehicleId) {
    if (_vehicles.any((v) => v.id == vehicleId)) {
      _activeVehicleId = vehicleId;
      saveToStorage();
      notifyListeners();
    }
  }

  // Record Management (with private audit timestamps)
  Future<void> addRecord(FuelRecord record) async {
    final recordWithAudit = record.copyWith(); // Sets createdTimestamp and lastModifiedTimestamp
    _records.add(recordWithAudit);
    await saveToStorage();
    await _logAuditAction('Added fuel record ID ${record.id} (Odo: ${record.odometer}, Fuel: ${record.fuelAmount}, Price: ${record.totalPrice})');
    notifyListeners();
  }

  Future<void> updateRecord(FuelRecord updated) async {
    final idx = _records.indexWhere((r) => r.id == updated.id);
    if (idx != -1) {
      final updatedWithAudit = updated.copyWith(
        lastModifiedTimestamp: DateTime.now(),
      );
      _records[idx] = updatedWithAudit;
      await saveToStorage();
      await _logAuditAction('Modified fuel record ID ${updated.id}');
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String recordId) async {
    _records.removeWhere((r) => r.id == recordId);
    await saveToStorage();
    await _logAuditAction('Deleted fuel record ID $recordId');
    notifyListeners();
  }

  // Service Records Management
  Future<void> addServiceRecord(ServiceRecord service) async {
    _services.add(service);
    await saveToStorage();
    await _logAuditAction('Added service record for vehicle ${service.vehicleId} (${service.serviceType})');
    notifyListeners();
  }

  Future<void> updateServiceRecord(ServiceRecord updated) async {
    final idx = _services.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      _services[idx] = updated;
      await saveToStorage();
      await _logAuditAction('Updated service record ID ${updated.id}');
      notifyListeners();
    }
  }

  Future<void> deleteServiceRecord(String serviceId) async {
    _services.removeWhere((s) => s.id == serviceId);
    await saveToStorage();
    await _logAuditAction('Deleted service record ID $serviceId');
    notifyListeners();
  }

  // Theme & Export
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await saveToStorage();
    notifyListeners();
  }

  /// Generate sample demo data with realistic numbers including service history and purchase date
  Future<void> loadSampleData() async {
    final now = DateTime.now();

    final vehicle1 = Vehicle(
      id: 'demo-suv-01',
      name: 'Silver Explorer',
      brand: 'Toyota',
      type: VehicleType.suv,
      owner: 'Alex Morgan',
      colorValue: 0xFF2E7D32, // Forest Green
      unitDistance: _defaultDistanceUnit,
      unitVolume: _defaultVolumeUnit,
      currency: _defaultCurrency,
      initialOdometer: 42100.0,
      dateBought: now.subtract(const Duration(days: 380)), // ~1 year ago
      createdAt: now.subtract(const Duration(days: 45)),
    );

    final vehicle2 = Vehicle(
      id: 'demo-sedan-02',
      name: 'City Commuter',
      brand: 'Honda',
      type: VehicleType.sedan,
      owner: 'Alex Morgan',
      colorValue: 0xFF1976D2, // Royal Blue
      unitDistance: _defaultDistanceUnit,
      unitVolume: _defaultVolumeUnit,
      currency: _defaultCurrency,
      initialOdometer: 18500.0,
      dateBought: now.subtract(const Duration(days: 160)), // ~5 months ago (due soon)
      createdAt: now.subtract(const Duration(days: 30)),
    );

    final records = [
      // Entry 1
      FuelRecord(
        id: 'rec-01',
        vehicleId: 'demo-suv-01',
        dateTime: now.subtract(const Duration(days: 28)),
        odometer: 42520.0,
        fuelAmount: 48.5,
        totalPrice: 87.30,
        isFullTank: true,
        fuelType: 'Regular 87',
        gasStation: 'Shell',
        notes: 'Initial full tank fill',
      ),
      // Entry 2
      FuelRecord(
        id: 'rec-02',
        vehicleId: 'demo-suv-01',
        dateTime: now.subtract(const Duration(days: 21)),
        odometer: 43050.0,
        fuelAmount: 45.2,
        totalPrice: 83.17,
        isFullTank: true,
        fuelType: 'Regular 87',
        gasStation: 'ExxonMobil',
        notes: 'Highway road trip weekend',
      ),
      // Entry 3
      FuelRecord(
        id: 'rec-03',
        vehicleId: 'demo-suv-01',
        dateTime: now.subtract(const Duration(days: 14)),
        odometer: 43560.0,
        fuelAmount: 44.0,
        totalPrice: 82.72,
        isFullTank: true,
        fuelType: 'Regular 87',
        gasStation: 'BP',
        notes: 'City commute',
      ),
      // Entry 4
      FuelRecord(
        id: 'rec-04',
        vehicleId: 'demo-suv-01',
        dateTime: now.subtract(const Duration(days: 6)),
        odometer: 44140.0,
        fuelAmount: 47.1,
        totalPrice: 86.66,
        isFullTank: true,
        fuelType: 'Regular 87',
        gasStation: 'Costco Gas',
        notes: 'Good price at Costco',
      ),
      // Entry 5
      FuelRecord(
        id: 'rec-05',
        vehicleId: 'demo-suv-01',
        dateTime: now.subtract(const Duration(days: 1)),
        odometer: 44610.0,
        fuelAmount: 39.8,
        totalPrice: 75.22,
        isFullTank: true,
        fuelType: 'Regular 87',
        gasStation: 'Shell',
        notes: 'Mid-week top up',
      ),
    ];

    // Service record for vehicle 1 (~5.5 months ago - trigger due soon)
    final services = [
      ServiceRecord(
        id: 'srv-01',
        vehicleId: 'demo-suv-01',
        serviceDate: now.subtract(const Duration(days: 165)), // 17 days until 6-month mark
        odometer: 41900.0,
        serviceType: 'Periodic 6-Month Maintenance',
        cost: 145.00,
        serviceCenter: 'Authorized Toyota Dealer',
        notes: 'Engine oil replacement, oil filter, tire rotation, multi-point check',
      ),
    ];

    _vehicles = [vehicle1, vehicle2];
    _records = records;
    _services = services;
    _activeVehicleId = vehicle1.id;
    await saveToStorage();
    await _logAuditAction('Loaded sample demo data');
    notifyListeners();
  }

  /// Export records as CSV string
  String exportRecordsToCsv(String vehicleId) {
    final v = _vehicles.firstWhere((x) => x.id == vehicleId, orElse: () => activeVehicle!);
    final sorted = _records.where((r) => r.vehicleId == vehicleId).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final sb = StringBuffer();
    sb.writeln('Date,Odometer (${v.unitDistance}),Distance Travelled (${v.unitDistance}),Fuel Amount (${v.unitVolume}),Total Cost (${v.currency}),Price Per ${v.unitVolume},Fuel Efficiency (${v.unitDistance}/${v.unitVolume}),Consumption (L/100km),Days Since Last,Fuel Grade,Station,Full Tank,Notes');

    for (int i = 0; i < sorted.length; i++) {
      final curr = sorted[i];
      final prev = i > 0 ? sorted[i - 1] : null;
      final calc = RecordCalculation(current: curr, previous: prev);

      final dateStr = AppDateUtils.format(curr.dateTime);
      final odo = curr.odometer.toStringAsFixed(1);
      final dist = calc.distanceTraveled?.toStringAsFixed(1) ?? '';
      final fuel = curr.fuelAmount.toStringAsFixed(2);
      final price = curr.totalPrice.toStringAsFixed(2);
      final ppu = calc.pricePerUnit.toStringAsFixed(3);
      final eff = calc.fuelEfficiency?.toStringAsFixed(2) ?? '';
      final cons = calc.consumptionPer100Units?.toStringAsFixed(2) ?? '';
      final days = calc.daysSincePrevious?.toStringAsFixed(1) ?? '';
      final fuelType = '"${curr.fuelType.replaceAll('"', '""')}"';
      final station = '"${curr.gasStation.replaceAll('"', '""')}"';
      final fullTank = curr.isFullTank ? 'Yes' : 'No';
      final notes = '"${curr.notes.replaceAll('"', '""')}"';

      sb.writeln('$dateStr,$odo,$dist,$fuel,$price,$ppu,$eff,$cons,$days,$fuelType,$station,$fullTank,$notes');
    }

    return sb.toString();
  }

  /// Exports vehicle records to a standalone .csv file in the app documents storage directory.
  Future<File> exportVehicleRecordsToCsvFile(String vehicleId) async {
    final csvContent = exportRecordsToCsv(vehicleId);
    final dir = await _getAppDirectory();
    final exportsDir = Directory('${dir.path}/Exports');
    if (!exportsDir.existsSync()) {
      exportsDir.createSync(recursive: true);
    }
    final vehicle = _vehicles.firstWhere((x) => x.id == vehicleId, orElse: () => activeVehicle!);
    final sanitizedName = vehicle.name.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim().replaceAll(' ', '_');
    final dateStr = AppDateUtils.format(DateTime.now()).replaceAll('-', '_');
    final filePath = '${exportsDir.path}/FuelMetrics_${sanitizedName}_$dateStr.csv';
    final file = File(filePath);
    await file.writeAsString(csvContent);
    await _logAuditAction('Exported CSV file for vehicle ${vehicle.name}: $filePath');
    return file;
  }

  /// Exports complete data snapshot as formatted JSON string
  String exportAllDataBackup() {
    final data = {
      'version': '1.0.2',
      'exportedAt': DateTime.now().toIso8601String(),
      'selectedCountry': _selectedCountry,
      'defaultCurrency': _defaultCurrency,
      'defaultDistanceUnit': _defaultDistanceUnit,
      'defaultVolumeUnit': _defaultVolumeUnit,
      'defaultEfficiencyUnit': _defaultEfficiencyUnit,
      'themeMode': _themeMode.name,
      'vehicles': _vehicles.map((v) => v.toJson()).toList(),
      'records': _records.map((r) => r.toJson()).toList(),
      'services': _services.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Saves complete JSON backup to file in Backups directory
  Future<File> saveBackupToFile() async {
    final jsonStr = exportAllDataBackup();
    final dir = await _getAppDirectory();
    final backupsDir = Directory('${dir.path}/Backups');
    if (!backupsDir.existsSync()) {
      backupsDir.createSync(recursive: true);
    }
    final dateStr = AppDateUtils.format(DateTime.now()).replaceAll('-', '_');
    final filePath = '${backupsDir.path}/FuelMetrics_Backup_$dateStr.json';
    final file = File(filePath);
    await file.writeAsString(jsonStr);
    await _logAuditAction('Created full backup file: $filePath');
    return file;
  }

  /// Restores complete data snapshot from JSON string
  Future<void> importAllDataBackup(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (data.containsKey('vehicles')) {
      final List vList = data['vehicles'] as List;
      _vehicles = vList.map((v) => Vehicle.fromJson(v as Map<String, dynamic>)).toList();
    }
    if (data.containsKey('records')) {
      final List rList = data['records'] as List;
      _records = rList.map((r) => FuelRecord.fromJson(r as Map<String, dynamic>)).toList();
    }
    if (data.containsKey('services')) {
      final List sList = data['services'] as List;
      _services = sList.map((s) => ServiceRecord.fromJson(s as Map<String, dynamic>)).toList();
    }
    if (data['selectedCountry'] is String) _selectedCountry = data['selectedCountry'] as String;
    if (data['defaultCurrency'] is String) _defaultCurrency = data['defaultCurrency'] as String;
    if (data['defaultDistanceUnit'] is String) _defaultDistanceUnit = data['defaultDistanceUnit'] as String;
    if (data['defaultVolumeUnit'] is String) _defaultVolumeUnit = data['defaultVolumeUnit'] as String;
    if (data['defaultEfficiencyUnit'] is String) _defaultEfficiencyUnit = data['defaultEfficiencyUnit'] as String;

    if (_vehicles.isNotEmpty) {
      _activeVehicleId = _vehicles.first.id;
    } else {
      _activeVehicleId = null;
    }

    await saveToStorage();
    await _logAuditAction(
      'Restored full backup: ${_vehicles.length} vehicles, ${_records.length} records, ${_services.length} services',
    );
    notifyListeners();
  }

  /// Clear all data
  Future<void> clearAllData() async {
    _vehicles.clear();
    _records.clear();
    _services.clear();
    _activeVehicleId = null;
    await saveToStorage();
    await _logAuditAction('Cleared all app data');
    notifyListeners();
  }
}
