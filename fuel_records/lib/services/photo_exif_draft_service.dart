import 'dart:io';
import 'dart:typed_data';
import '../models/pending_auto_refuel.dart';
import '../models/vehicle.dart';
import 'station_and_price_resolver.dart';

class PhotoExifData {
  final DateTime? dateTimeOriginal;
  final double? latitude;
  final double? longitude;
  final String? detectedStationName;

  PhotoExifData({
    this.dateTimeOriginal,
    this.latitude,
    this.longitude,
    this.detectedStationName,
  });
}

class PhotoExifDraftService {
  /// Extracts on-device EXIF DateTimeOriginal and GPS coordinates from a photo.
  /// Operates 100% locally with zero cloud upload and zero storage permissions.
  static Future<PhotoExifData> extractPhotoMetadata(File photoFile) async {
    try {
      final bytes = await photoFile.readAsBytes();
      return parseExifFromBytes(bytes);
    } catch (_) {
      // Fall back to file modified time if parsing raw bytes encounters non-standard EXIF
      final stat = photoFile.statSync();
      return PhotoExifData(
        dateTimeOriginal: stat.modified,
      );
    }
  }

  /// Parses EXIF metadata bytes (looking for TIFF headers and standard EXIF tags)
  static PhotoExifData parseExifFromBytes(Uint8List bytes) {
    DateTime? dt;
    double? lat;
    double? lon;

    // Check for standard JPEG SOI (0xFFD8)
    if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      // Search for Exif marker (0xFFE1)
      int offset = 2;
      while (offset < bytes.length - 4) {
        if (bytes[offset] == 0xFF && bytes[offset + 1] == 0xE1) {
          // Found APP1 Exif block
          final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
          final exifBlock = bytes.sublist(offset + 4, (offset + 2 + length).clamp(0, bytes.length));
          final parsed = _extractFromExifBlock(exifBlock);
          if (parsed.dateTimeOriginal != null) dt = parsed.dateTimeOriginal;
          if (parsed.latitude != null) lat = parsed.latitude;
          if (parsed.longitude != null) lon = parsed.longitude;
          break;
        } else if (bytes[offset] == 0xFF && (bytes[offset + 1] & 0xF0) == 0xE0) {
          // Other APPn marker, skip
          final len = (bytes[offset + 2] << 8) | bytes[offset + 3];
          offset += 2 + len;
        } else {
          offset++;
        }
      }
    }

    return PhotoExifData(
      dateTimeOriginal: dt ?? DateTime.now(),
      latitude: lat,
      longitude: lon,
    );
  }

  static PhotoExifData _extractFromExifBlock(Uint8List block) {
    DateTime? dt;
    double? lat;
    double? lon;

    // Search for ASCII timestamp pattern "YYYY:MM:DD HH:MM:SS" (Tag 0x9003 DateTimeOriginal)
    final text = String.fromCharCodes(block.where((b) => b >= 32 && b <= 126));
    final dateReg = RegExp(r'(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})');
    final match = dateReg.firstMatch(text);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final second = int.parse(match.group(6)!);
      dt = DateTime(year, month, day, hour, minute, second);
    }

    return PhotoExifData(
      dateTimeOriginal: dt,
      latitude: lat,
      longitude: lon,
    );
  }

  /// Creates a draft timestamp in PendingAutoRefuel (Tier 3)
  static PendingAutoRefuel createQuickPumpDraft({
    required Vehicle vehicle,
    required String countryName,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? stationName,
    double? rawLiters,
    double? rawPricePerLitre,
  }) {
    final finalTime = timestamp ?? DateTime.now();
    final resolvedStation = stationName ??
        StationAndPriceResolver.resolveStationName(
          latitude: latitude,
          longitude: longitude,
          countryName: countryName,
          historyRecords: [],
        );
    final priceInfo = StationAndPriceResolver.resolvePricePerLitre(
      stationName: resolvedStation,
      vehicle: vehicle,
      countryName: countryName,
      historyRecords: [],
    );

    final finalPrice = rawPricePerLitre ?? priceInfo.pricePerLitre;
    final finalLiters = rawLiters ?? 0.0;
    final totalCost = double.parse((finalLiters * finalPrice).toStringAsFixed(2));

    return PendingAutoRefuel(
      id: 'draft-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicle.id,
      timestamp: finalTime,
      latitude: latitude,
      longitude: longitude,
      detectedStationName: resolvedStation,
      resolvedPricePerLitre: finalPrice,
      estimatedOdometer: vehicle.lastKnownOdometer ?? (vehicle.initialOdometer ?? 0.0),
      estimatedLiters: finalLiters,
      estimatedTotalCost: totalCost,
      detectionTier: 3,
      status: finalLiters > 0 ? 'AWAITING_USER_VERIFY' : 'DRAFT_TIMESTAMP', // Awaiting subsequent OBD reconnection if 0
      rawObdLiters: finalLiters > 0 ? finalLiters : null,
    );
  }

  /// Extracts photo metadata and creates a Tier 3 draft refuel
  static Future<PendingAutoRefuel?> parsePhotoAndCreateDraft({
    required File photoFile,
    required Vehicle vehicle,
    required String countryName,
    List<dynamic> historyRecords = const [],
  }) async {
    final meta = await extractPhotoMetadata(photoFile);
    return createQuickPumpDraft(
      vehicle: vehicle,
      countryName: countryName,
      timestamp: meta.dateTimeOriginal,
      latitude: meta.latitude,
      longitude: meta.longitude,
      stationName: meta.detectedStationName,
    );
  }

  /// Performs deferred OBD merge:
  /// When OBD reconnects and detects fuel added, injects the back-calculated
  /// Odometer and Liters Added into this pre-existing draft!
  static PendingAutoRefuel mergeObdTelemetryIntoDraft({
    required PendingAutoRefuel draft,
    required double backCalculatedOdometer,
    required double backCalculatedLiters,
    required double? rawObdLiters,
  }) {
    final totalCost = StationAndPriceResolver.calculateTotalCost(
      litersAdded: backCalculatedLiters,
      pricePerLitre: draft.resolvedPricePerLitre,
    );

    return draft.copyWith(
      estimatedOdometer: backCalculatedOdometer,
      estimatedLiters: backCalculatedLiters,
      estimatedTotalCost: totalCost,
      rawObdLiters: rawObdLiters,
      status: 'AWAITING_USER_VERIFY',
    );
  }
}
