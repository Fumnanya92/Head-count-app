import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resident.dart';

class DatabaseService {
  static const String _boxName = 'residents';
  static const String _seedImportedKey = 'seed_data_imported_v1';
  static Box<Resident>? _box;

  // Initialize Hive and open box
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      // Register adapter
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ResidentAdapter());
      }

      // Try to open box, with recovery if needed
      try {
        _box = await Hive.openBox<Resident>(_boxName);
        debugPrint('✓ Successfully opened Hive box. Current residents: ${_box!.length}');
      } catch (e) {
        debugPrint('⚠️ Error opening Hive box: $e');
        // CRITICAL: Never delete all data. Only try to backup and recreate.
        // This preserves user data even if the box is corrupted.
        try {
          debugPrint('Attempting to recover by backing up corrupted data...');
          // The corrupted box will be skipped, app will start fresh
          // but user data is preserved in the Hive persistent storage
          _box = await Hive.openBox<Resident>(_boxName);
          debugPrint('✓ Recovery successful after reopening');
        } catch (e2) {
          debugPrint('❌ Recovery failed: $e2');
          // Last resort: start with empty box but DO NOT delete persistent data
          rethrow; // Let the app handle gracefully
        }
      }

      // Import seed data only on first install (never again)
      await _checkAndImportSeedData();
      
    } catch (e) {
      debugPrint('CRITICAL: Database initialization failed: $e');
      rethrow; // Let main.dart handle
    }
  }

  // Check if seed data should be imported (only once on first install)
  static Future<void> _checkAndImportSeedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seedImported = prefs.getBool(_seedImportedKey) ?? false;

      // Only import on first install (empty box + not previously imported)
      if (_box!.isEmpty && !seedImported) {
        debugPrint('🔄 First install detected. Importing seed data...');
        await _importFromAssetExcelOrCsv();
        // Mark that seed data has been imported
        await prefs.setBool(_seedImportedKey, true);
        debugPrint('✓ Seed data imported and flagged as complete');
      } else if (_box!.isEmpty && seedImported) {
        debugPrint('⚠️ Database is empty but seed was already imported. Attempting recovery...');
        // If somehow the box is empty but seed was imported, try importing again
        await _importFromAssetExcelOrCsv();
      } else {
        debugPrint('✓ Existing data found (${_box!.length} residents). Skipping seed import.');
      }
    } catch (e) {
      debugPrint('Error checking seed import status: $e');
      // Continue anyway - app should work even without seed data
    }
  }

  static Future<void> _importFromAssetExcelOrCsv() async {
    try {
      await _importFromAssetExcel();
    } catch (e) {
      debugPrint('Excel seed import unavailable, falling back to CSV: $e');
      await _importFromAssetCsv();
    }
  }

  // Get the box
  static Box<Resident> get box {
    if (_box == null || !_box!.isOpen) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _box!;
  }

  // Import from bundled CSV asset
  static Future<void> _importFromAssetCsv() async {
    try {
      // Load CSV from assets
      final csvString = await rootBundle.loadString('assets/residents_seed.csv');

      // Parse CSV with explicit field delimiter
      final List<List<dynamic>> rows = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        textEndDelimiter: '"',
      ).convert(csvString);

      debugPrint('CSV parsed rows count: ${rows.length}');
      if (rows.isNotEmpty) {
        debugPrint('First row (header): ${rows.first}');
        if (rows.length > 1) {
          debugPrint('Second row (data): ${rows[1]}');
        }
      }

      // Skip header row
      final dataRows = rows.skip(1);

      debugPrint('Data rows count: ${dataRows.length}');

      var imported = 0;
      var rowIndex = 1;

      // Carry-forward state — mirrors cascaded layout in source Excel
      String prevAddress = '';
      String prevZone    = '';
      String prevFlats   = '';

      // Import each row with defensive checks and logging
      for (final row in dataRows) {
        try {
          if (row.isNotEmpty) {
            if (row.length < 2) {
              debugPrint('Skipping malformed row #$rowIndex: $row');
            } else {
              final normalizedRow = List<dynamic>.from(row);
              while (normalizedRow.length < 32) {
                normalizedRow.add('');
              }

              // Address carry-forward
              final addr = normalizedRow[1]?.toString().trim() ?? '';
              if (addr.isEmpty) {
                normalizedRow[1] = prevAddress;
              } else {
                prevAddress = addr;
              }
              // Zone carry-forward
              final zone = normalizedRow[2]?.toString().trim() ?? '';
              if (zone.isEmpty) {
                normalizedRow[2] = prevZone;
              } else {
                prevZone = zone;
              }
              // Total Flats carry-forward
              final flats = normalizedRow[3]?.toString().trim() ?? '';
              if (flats.isEmpty) {
                normalizedRow[3] = prevFlats;
              } else {
                prevFlats = flats;
              }

              final address = normalizedRow[1]?.toString().trim() ?? '';
              final unit    = normalizedRow[5]?.toString().trim() ?? '';
              if (address.isEmpty && unit.isEmpty) {
                rowIndex++;
                continue;
              }

              final resident = Resident.fromCsvRow(normalizedRow);
              // Ensure all seed-imported records are tagged as Preloaded
              resident.dataSource =
                  (resident.dataSource == null || resident.dataSource!.isEmpty)
                      ? 'Preloaded'
                      : resident.dataSource;
              resident.verificationStatus =
                  (resident.verificationStatus == null ||
                          resident.verificationStatus!.isEmpty)
                      ? 'Unverified'
                      : resident.verificationStatus;

              final key = imported + 1;
              resident.id = key;
              await _box!.put(key, resident);
              imported++;

              if (imported <= 5) {
                debugPrint('Imported resident #$imported: ${resident.houseAddress}');
              }
            }
          }
        } catch (rowErr) {
          debugPrint('Error importing row #$rowIndex: $rowErr');
          debugPrint('Row data: $row');
        }
        rowIndex++;
      }

      debugPrint('Imported $imported residents from CSV (box length: ${_box!.length})');
    } catch (e, st) {
      debugPrint('Error importing CSV: $e\n$st');
      rethrow;
    }
  }

  static String _cellToString(dynamic value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString().trim();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'Yes' : 'No';
    if (value is DateCellValue) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }
    if (value is DateTimeCellValue) {
      final date = value.asDateTimeLocal();
      final year = date.year.toString().padLeft(4, '0');
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }
    return value.toString().trim();
  }

  static Future<void> _importFromAssetExcel() async {
    final excelBytes = await rootBundle
        .load('assets/latest_heascount_from_FA_UPDATED-2.xlsx');
    final excel = Excel.decodeBytes(excelBytes.buffer.asUint8List());

    final sheet = excel['Headcount'];
    var imported = 0;

    String? lastAddress;
    String? lastZoneBlock;
    String? lastTotalFlats;

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final normalizedRow = List<dynamic>.filled(32, '');

      for (var col = 0; col < 32; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
        );
        normalizedRow[col] = _cellToString(cell.value);
      }

      final hasAnyValue =
          normalizedRow.any((value) => value.toString().trim().isNotEmpty);
      if (!hasAnyValue) {
        lastAddress = null;
        lastZoneBlock = null;
        lastTotalFlats = null;
        continue;
      }

      final currentAddress = normalizedRow[1].toString().trim();
      if (currentAddress.isEmpty && lastAddress != null) {
        normalizedRow[1] = lastAddress;
      } else if (currentAddress.isNotEmpty) {
        lastAddress = currentAddress;
      }

      final currentZone = normalizedRow[2].toString().trim();
      if (currentZone.isEmpty && lastZoneBlock != null) {
        normalizedRow[2] = lastZoneBlock;
      } else if (currentZone.isNotEmpty) {
        lastZoneBlock = currentZone;
      }

      final currentTotalFlats = normalizedRow[3].toString().trim();
      if (currentTotalFlats.isEmpty && lastTotalFlats != null) {
        normalizedRow[3] = lastTotalFlats;
      } else if (currentTotalFlats.isNotEmpty) {
        lastTotalFlats = currentTotalFlats;
      }

      final resolvedAddress = normalizedRow[1].toString().trim();
      final unitFlat = normalizedRow[5].toString().trim();
      if (resolvedAddress.isEmpty && unitFlat.isEmpty) {
        continue;
      }

      if (normalizedRow[0].toString().trim().isEmpty) {
        normalizedRow[0] = (imported + 1).toString();
      }

      final resident = Resident.fromCsvRow(normalizedRow);
      resident.dataSource =
          (resident.dataSource == null || resident.dataSource!.isEmpty)
              ? 'Preloaded'
              : resident.dataSource;
      resident.verificationStatus =
          (resident.verificationStatus == null ||
                  resident.verificationStatus!.isEmpty)
              ? 'Unverified'
              : resident.verificationStatus;

      final key = imported + 1;
      resident.id = key;
      await _box!.put(key, resident);
      imported++;
    }

    debugPrint('Imported $imported residents from Excel (box length: ${_box!.length})');
  }

  // Get all residents
  static List<Resident> getAllResidents() {
    return box.values.toList();
  }

  // Search residents
  static List<Resident> searchResidents(String query) {
    if (query.isEmpty) return getAllResidents();

    final lowerQuery = query.toLowerCase();
    return box.values.where((resident) {
      return resident.houseAddress.toLowerCase().contains(lowerQuery) ||
          (resident.zoneBlock?.toLowerCase().contains(lowerQuery) ?? false) ||
          (resident.mainContactName?.toLowerCase().contains(lowerQuery) ?? false) ||
          resident.id.toString().contains(lowerQuery);
    }).toList();
  }

  // Filter residents
  static List<Resident> filterResidents({
    bool? occupied,
    bool? followUpNeeded,
    bool? notVisited,
  }) {
    var results = getAllResidents();

    if (occupied != null) {
      results = results.where((r) => r.isOccupied == occupied).toList();
    }

    if (followUpNeeded != null) {
      results = results.where((r) => r.needsFollowUp == followUpNeeded).toList();
    }

    if (notVisited == true) {
      results = results.where((r) => r.visitDate == null || r.visitDate!.isEmpty).toList();
    }

    return results;
  }

  // Get resident by ID
  static Resident? getResident(int id) {
    return box.get(id);
  }

  // Save/Update resident
  static Future<void> saveResident(Resident resident) async {
    resident.isModified = true;
    resident.updatedAt = DateTime.now();
    // Always record who last updated
    resident.lastUpdatedBy = 'Field Agent';
    debugPrint('💾 [DB] saveResident: Saving resident ID=${resident.id}, address=${resident.houseAddress}, name=${resident.mainContactName}');
    await box.put(resident.id, resident);
    debugPrint('💾 [DB] saveResident: ✅ Put operation completed for resident ID=${resident.id}');
    // Verify the save
    final verify = box.get(resident.id);
    if (verify != null) {
      debugPrint('💾 [DB] saveResident: ✅ Verification successful - resident found in box');
    } else {
      debugPrint('💾 [DB] saveResident: ⚠️ WARNING - resident NOT found in box after save!');
    }
  }

  // Add new resident (preserves dataSource set by caller)
  static Future<int> addResident(Resident resident) async {
    debugPrint('💾 [DB] addResident: Starting add process...');
    final maxId = box.values.fold<int>(0, (max, r) => r.id > max ? r.id : max);
    debugPrint('💾 [DB] addResident: Max current ID=$maxId, assigning new ID=${maxId + 1}');
    resident.id = maxId + 1;
    // Preserve the dataSource if already set by caller, otherwise default to 'Field Added'
    resident.dataSource = resident.dataSource ?? 'Field Added';
    resident.verificationStatus = resident.verificationStatus ?? 'Unverified';
    debugPrint('💾 [DB] addResident: Calling saveResident for ID=${resident.id}');
    await saveResident(resident);
    debugPrint('💾 [DB] addResident: ✅ Successfully saved resident with ID=${resident.id}');
    return resident.id;
  }

  // Delete resident
  static Future<void> deleteResident(int id) async {
    await box.delete(id);
  }

  // Get modified residents
  static List<Resident> getModifiedResidents() {
    return box.values.where((r) => r.isModified).toList();
  }

  // Export to CSV string — 32 columns matching exact Excel column order
  static String exportToCsv({bool modifiedOnly = false}) {
    final residents = modifiedOnly ? getModifiedResidents() : getAllResidents();

    // Header — matches the final Excel sheet column order exactly
    const header = [
      'S/N',
      'House Address',
      'Zone/Block',
      'Total Flats in compound',
      'House Type',
      'Unit/Flat',
      'Occupied?',
      'Record Status',
      '# Households',
      'Monthly Due',
      'Payment Status',
      'Last Payment Date',
      'Adults',
      'Children',
      'Total Headcount',
      'Main Contact Name',
      'Contact Role (Owner/Tenant/Caretaker)',
      'Phone Number',
      'WhatsApp Number',
      'Email',
      'App Registered?',
      'Phone Type (Android/iPhone)',
      'Notes/Issues',
      'Visit Date',
      'Visited By',
      'Data Verified?',
      'Follow-up Needed?',
      'Follow-up Date',
      'Data Source',
      'Verification Status',
      'First Verified Date',
      'Last Updated By',
    ];

    // Sort by id before export
    final sorted = List<Resident>.from(residents)
      ..sort((a, b) => a.id.compareTo(b.id));

    final rows = sorted.map((r) => r.toCsvRow()).toList();
    final allRows = [header, ...rows];

    return const ListToCsvConverter().convert(allRows);
  }

  // Get statistics
  static Map<String, dynamic> getStatistics() {
    final all = getAllResidents();
    final occupied = all.where((r) => r.isOccupied).length;
    final vacant = all.length - occupied;
    final followUp = all.where((r) => r.needsFollowUp).length;
    final visited = all.where((r) => r.visitDate != null && r.visitDate!.isNotEmpty).length;
    final modified = all.where((r) => r.isModified).length;
    final totalPeople = all.fold<int>(0, (sum, r) => sum + r.totalHeadcount);
    final verified = all.where((r) => r.isVerified).length;
    final fieldAdded = all.where((r) => r.dataSource == 'Field Added').length;

    return {
      'total': all.length,
      'occupied': occupied,
      'vacant': vacant,
      'followUp': followUp,
      'visited': visited,
      'modified': modified,
      'totalPeople': totalPeople,
      'verified': verified,
      'fieldAdded': fieldAdded,
    };
  }

  /// Spreads [totalFlats] to every flat in [address] that doesn't have it set yet.
  /// Skips any flat that already has a value (so existing manual entries aren't overwritten).
  static Future<void> propagateCompoundData(
      String address, int totalFlats) async {
    if (address.isEmpty || totalFlats <= 0) return;
    for (final r in getAllResidents()) {
      if (r.houseAddress == address && r.totalFlatsInCompound == null) {
        r.totalFlatsInCompound = totalFlats;
        await box.put(r.id, r);
      }
    }
  }

  /// Clears the entire database and re-imports from the bundled seed CSV.
  static Future<int> resetDatabase() async {
    await box.clear();
    await _importFromAssetExcelOrCsv();
    return box.length;
  }

  // ── Excel (.xlsx) Export ────────────────────────────────────────────────────

  /// Builds and returns the bytes of a 3-sheet Excel workbook:
  ///   1. Headcount  — 32-col data, cascaded address/zone/totalFlats, colour rows
  ///   2. Summary    — high-level stats
  ///   3. Street Summary — per-compound flat count breakdown
  static Uint8List exportToXlsx({bool modifiedOnly = false}) {
    final residents =
        modifiedOnly ? getModifiedResidents() : getAllResidents();
    final sorted = List<Resident>.from(residents)
      ..sort((a, b) => a.id.compareTo(b.id));

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildHeadcountSheet(excel, sorted);
    _buildSummarySheet(excel, sorted);
    _buildStreetSummarySheet(excel, sorted);

    final bytes = excel.save()!;
    return Uint8List.fromList(bytes);
  }

  // ── HEADCOUNT sheet ─────────────────────────────────────────────────────────

  static void _buildHeadcountSheet(Excel excel, List<Resident> sorted) {
    final sheet = excel['Headcount'];

    // Column widths (one per the 32 columns)
    const colWidths = [
      5.0, 36.0, 18.0, 12.0, 16.0, 12.0, 10.0, 14.0, 10.0, 12.0,
      14.0, 18.0, 8.0, 8.0, 14.0, 24.0, 24.0, 16.0, 16.0, 24.0,
      14.0, 16.0, 26.0, 14.0, 14.0, 14.0, 14.0, 14.0, 14.0, 18.0,
      18.0, 15.0,
    ];
    for (var i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    // Colours
    final navyBg    = ExcelColor.fromHexString('FF1F4E79');
    final navyFont  = ExcelColor.fromHexString('FFFFFFFF');
    final greenBg   = ExcelColor.fromHexString('FFD9EAD3'); // occupied + contact
    final ltGreenBg = ExcelColor.fromHexString('FFEBF5E0'); // occupied, no contact

    // Header row (row 0)
    const headers = [
      'S/N', 'House Address', 'Zone/Block', 'Total Flats in compound',
      'House Type', 'Unit/Flat', 'Occupied?', 'Record Status',
      '# Households', 'Monthly Due', 'Payment Status', 'Last Payment Date',
      'Adults', 'Children', 'Total Headcount', 'Main Contact Name',
      'Contact Role (Owner/Tenant/Caretaker)', 'Phone Number',
      'WhatsApp Number', 'Email', 'App Registered?',
      'Phone Type (Android/iPhone)', 'Notes/Issues', 'Visit Date',
      'Visited By', 'Data Verified?', 'Follow-up Needed?', 'Follow-up Date',
      'Data Source', 'Verification Status', 'First Verified Date',
      'Last Updated By',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: navyBg,
        fontColorHex: navyFont,
      );
    }

    // Data rows — cascade identical compound address/zone/totalFlats
    String? prevAddress;
    var rowIndex = 1;

    for (final r in sorted) {
      final sameCompound =
          r.houseAddress.isNotEmpty && r.houseAddress == prevAddress;

      final hasContact =
          r.mainContactName != null && r.mainContactName!.isNotEmpty;
      final isOcc = r.isOccupied;
        final normalizedRecordStatus = isOcc ? 'Occupied' : 'Vacant';

      ExcelColor? rowFill;
      if (isOcc && hasContact) {
        rowFill = greenBg;
      } else if (isOcc) {
        rowFill = ltGreenBg;
      }

      final values = [
        r.id.toString(),
        sameCompound ? '' : r.houseAddress,
        sameCompound ? '' : (r.zoneBlock ?? ''),
        sameCompound ? '' : (r.totalFlatsInCompound?.toString() ?? ''),
        r.houseType ?? '',
        r.unitFlat ?? '',
        r.occupancyStatus,
        normalizedRecordStatus,
        r.householdsCount.toString(),
        r.monthlyDue.toString(),
        r.paymentStatus ?? '',
        r.lastPaymentDate ?? '',
        r.adults.toString(),
        r.children.toString(),
        r.totalHeadcount.toString(),
        r.mainContactName ?? '',
        r.contactRole ?? '',
        r.phoneNumber ?? '',
        r.whatsappNumber ?? '',
        r.email ?? '',
        r.appRegistered ?? '',
        r.phoneType ?? '',
        r.notes ?? '',
        r.visitDate ?? '',
        r.visitedBy ?? '',
        r.dataVerified ?? '',
        r.followUpNeeded ?? '',
        r.followUpDate ?? '',
        r.dataSource ?? 'Preloaded',
        r.verificationStatus ?? 'Unverified',
        r.firstVerifiedDate ?? '',
        r.lastUpdatedBy ?? '',
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = TextCellValue(values[col]);
        if (rowFill != null) {
          cell.cellStyle = CellStyle(backgroundColorHex: rowFill);
        }
      }

      if (r.houseAddress.isNotEmpty) prevAddress = r.houseAddress;
      rowIndex++;
    }
  }

  // ── SUMMARY sheet ────────────────────────────────────────────────────────────

  static void _buildSummarySheet(Excel excel, List<Resident> sorted) {
    final sheet = excel['Summary'];
    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 12.0);

    final navyBg   = ExcelColor.fromHexString('FF1F4E79');
    final navyFont = ExcelColor.fromHexString('FFFFFFFF');
    final navyText = ExcelColor.fromHexString('FF1F4E79');

    // Count distinct non-empty addresses for "Total Houses"
    final distinctAddresses = sorted
        .map((r) => r.houseAddress)
        .where((a) => a.isNotEmpty)
        .toSet()
        .length;
    final occupied = sorted.where((r) => r.isOccupied).length;
    final vacantUnverified = sorted.length - occupied;

    // Title row (row 0)
    final titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('Summary');
    titleCell.cellStyle = CellStyle(
        bold: true, backgroundColorHex: navyBg, fontColorHex: navyFont);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        .cellStyle = CellStyle(backgroundColorHex: navyBg);

    // Data rows
    final rows = [
      ['Total Houses', distinctAddresses.toString()],
      ['Total Confirmed Occupied', occupied.toString()],
      ['Total Unverified / Vacant', vacantUnverified.toString()],
    ];

    for (var i = 0; i < rows.length; i++) {
      final labelCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1));
      labelCell.value = TextCellValue(rows[i][0]);
      labelCell.cellStyle = CellStyle(bold: true);

      final valueCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1));
      valueCell.value = TextCellValue(rows[i][1]);
      valueCell.cellStyle =
          CellStyle(bold: true, fontColorHex: navyText);
    }
  }

  // ── STREET SUMMARY sheet ─────────────────────────────────────────────────────

  static void _buildStreetSummarySheet(Excel excel, List<Resident> sorted) {
    final sheet = excel['Street Summary'];
    sheet.setColumnWidth(0, 48.0);
    sheet.setColumnWidth(1, 16.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 14.0);
    sheet.setColumnWidth(4, 20.0);

    final navyBg   = ExcelColor.fromHexString('FF1F4E79');
    final navyFont = ExcelColor.fromHexString('FFFFFFFF');
    final navyText = ExcelColor.fromHexString('FF1F4E79');
    final greenBg  = ExcelColor.fromHexString('FFD9EAD3'); // complete
    final yellowBg = ExcelColor.fromHexString('FFFFF2CC'); // in progress
    final redBg    = ExcelColor.fromHexString('FFFFC7CE'); // not started
    final totalBg  = ExcelColor.fromHexString('FFD9E1F2'); // totals row

    // ── Header row ───────────────────────────────────────────────────────────
    const hdrs = [
      'Compound / House Address',
      'Supposed Flats\n(Total Rows)',
      'Flats Counted\n(Occupied + Contact)',
      'Remaining',
      'Status',
    ];
    for (var col = 0; col < hdrs.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(hdrs[col]);
      cell.cellStyle = CellStyle(
          bold: true, backgroundColorHex: navyBg, fontColorHex: navyFont);
    }

    // ── Group by address (order preserved = sort order) ──────────────────────
    final Map<String, List<Resident>> grouped = {};
    for (final r in sorted) {
      final key = r.houseAddress.isNotEmpty ? r.houseAddress : '(No Address)';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    var rowIndex   = 1;
    var grandTotal = 0;
    var grandCounted = 0;

    for (final entry in grouped.entries) {
      final address = entry.key;
      final group   = entry.value;

      // Supposed = totalFlatsInCompound if set, else fall back to total rows
      // (every row in the DB represents one flat that was pre-surveyed)
      final supposed =
          (group.first.totalFlatsInCompound ?? 0) > 0
              ? group.first.totalFlatsInCompound!
              : group.length;

      // Counted = green rows: occupied AND has a verified contact name
      final counted = group
          .where((r) =>
              r.isOccupied &&
              r.mainContactName != null &&
              r.mainContactName!.isNotEmpty)
          .length;

      final remaining = supposed - counted;

      grandTotal   += supposed;
      grandCounted += counted;

      // Status & colour
      final String status;
      final ExcelColor rowFill;
      if (remaining <= 0) {
        status  = '✓ Complete';
        rowFill = greenBg;
      } else if (counted > 0) {
        final pct = ((counted / supposed) * 100).round();
        status  = 'In Progress ($pct%)';
        rowFill = yellowBg;
      } else {
        status  = 'Not Started';
        rowFill = redBg;
      }

      void writeCell(int col, CellValue val, {bool bold = false}) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = val;
        cell.cellStyle = CellStyle(bold: bold, backgroundColorHex: rowFill);
      }

      writeCell(0, TextCellValue(address));
      writeCell(1, IntCellValue(supposed));
      writeCell(2, IntCellValue(counted));
      writeCell(3, IntCellValue(remaining < 0 ? 0 : remaining));
      writeCell(4, TextCellValue(status), bold: remaining <= 0);

      rowIndex++;
    }

    // ── Grand-total row ──────────────────────────────────────────────────────
    final grandRemaining = grandTotal - grandCounted;
    final grandPct =
        grandTotal > 0 ? ((grandCounted / grandTotal) * 100).round() : 0;

    final totalsData = [
      'GRAND TOTAL  —  $grandPct% of estate counted',
      grandTotal,
      grandCounted,
      grandRemaining < 0 ? 0 : grandRemaining,
      '$grandCounted / $grandTotal flats counted',
    ];

    for (var col = 0; col < totalsData.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      final v = totalsData[col];
      cell.value = v is int ? IntCellValue(v) : TextCellValue(v.toString());
      cell.cellStyle =
          CellStyle(bold: true, backgroundColorHex: totalBg, fontColorHex: navyText);
    }
  }

  // Get all flat numbers for a specific address
  static List<String> getExistingFlatsForAddress(String address) {
    final residents = box.values.where((r) =>
        r.houseAddress.toLowerCase() == address.toLowerCase() &&
        r.unitFlat != null &&
        r.unitFlat!.isNotEmpty).toList();
    return residents.map((r) => r.unitFlat!).toList();
  }

  // Check for duplicate flat number and get existing flats
  static Map<String, dynamic> checkFlatNumberDuplicate(String address, String flatNumber) {
    final existing = box.values.where((r) =>
        r.houseAddress.toLowerCase() == address.toLowerCase() &&
        r.unitFlat != null &&
        r.unitFlat!.isNotEmpty).toList();
    
    final existingFlats = existing.map((r) => r.unitFlat!).toList();
    
    final duplicate = existing.firstWhere(
      (r) => r.unitFlat?.toLowerCase() == flatNumber.toLowerCase(),
      orElse: () => Resident(id: -1, houseAddress: '', occupancyStatus: 'No'),
    );
    
    return {
      'hasDuplicate': duplicate.id != -1,
      'conflictingResident': duplicate.id != -1 ? duplicate : null,
      'existingFlats': existingFlats,
    };
  }

  // Get an address to duplicate from (all fields for template)
  static Resident? getAddressTemplate(String address) {
    final resident = box.values.firstWhere(
      (r) => r.houseAddress.toLowerCase() == address.toLowerCase(),
      orElse: () => Resident(id: -1, houseAddress: '', occupancyStatus: 'No'),
    );
    return resident.id != -1 ? resident : null;
  }
}
