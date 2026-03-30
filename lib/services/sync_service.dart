import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/resident.dart';
import 'database_service.dart';

class SyncService {
  static const String _syncFileName = 'residents_sync.json';

  /// Export all residents to JSON file
  static Future<File?> exportResidentsToJson() async {
    try {
      final residents = DatabaseService.getAllResidents();
      
      // Convert residents to JSON-serializable format
      final List<Map<String, dynamic>> residentsJson = residents.map((r) {
        return {
          'id': r.id,
          'houseAddress': r.houseAddress,
          'zoneBlock': r.zoneBlock,
          'houseType': r.houseType,
          'unitFlat': r.unitFlat,
          'occupancyStatus': r.occupancyStatus,
          'recordStatus': r.recordStatus,
          'householdsCount': r.householdsCount,
          'monthlyDue': r.monthlyDue,
          'paymentStatus': r.paymentStatus,
          'lastPaymentDate': r.lastPaymentDate,
          'adults': r.adults,
          'children': r.children,
          'totalHeadcount': r.totalHeadcount,
          'mainContactName': r.mainContactName,
          'contactRole': r.contactRole,
          'phoneNumber': r.phoneNumber,
          'whatsappNumber': r.whatsappNumber,
          'email': r.email,
          'appRegistered': r.appRegistered,
          'phoneType': r.phoneType,
          'notes': r.notes,
          'visitDate': r.visitDate,
          'visitedBy': r.visitedBy,
          'dataVerified': r.dataVerified,
          'followUpNeeded': r.followUpNeeded,
          'followUpDate': r.followUpDate,
          'isModified': r.isModified,
          'updatedAt': r.updatedAt.toIso8601String(),
          'totalFlatsInCompound': r.totalFlatsInCompound,
          'dataSource': r.dataSource,
          'verificationStatus': r.verificationStatus,
          'firstVerifiedDate': r.firstVerifiedDate,
          'lastUpdatedBy': r.lastUpdatedBy,
        };
      }).toList();

      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'totalRecords': residentsJson.length,
        'residents': residentsJson,
      };

      // Get Documents folder (more accessible)
      final documentsDir = await getApplicationDocumentsDirectory();
      final file = File('${documentsDir.path}/$_syncFileName');
      
      await file.writeAsString(jsonEncode(exportData), flush: true);
      
      debugPrint('Exported ${residentsJson.length} residents to ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting residents: $e');
      return null;
    }
  }

  /// Import residents from JSON file
  static Future<ImportResult> importResidentsFromJson(File jsonFile) async {
    try {
      final content = await jsonFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final List<dynamic> residentsJson = data['residents'] ?? [];
      
      int imported = 0;
      int skipped = 0;
      int updated = 0;
      final errors = <String>[];

      for (final residentData in residentsJson) {
        try {
          final resident = Resident(
            id: residentData['id'] as int,
            houseAddress: residentData['houseAddress'] as String,
            zoneBlock: residentData['zoneBlock'] as String?,
            houseType: residentData['houseType'] as String?,
            unitFlat: residentData['unitFlat'] as String?,
            occupancyStatus: residentData['occupancyStatus'] as String? ?? 'Yes',
            recordStatus: residentData['recordStatus'] as String?,
            householdsCount: residentData['householdsCount'] as int? ?? 1,
            monthlyDue: residentData['monthlyDue'] as int? ?? 0,
            paymentStatus: residentData['paymentStatus'] as String?,
            lastPaymentDate: residentData['lastPaymentDate'] as String?,
            adults: residentData['adults'] as int? ?? 0,
            children: residentData['children'] as int? ?? 0,
            totalHeadcount: residentData['totalHeadcount'] as int? ?? 0,
            mainContactName: residentData['mainContactName'] as String?,
            contactRole: residentData['contactRole'] as String?,
            phoneNumber: residentData['phoneNumber'] as String?,
            whatsappNumber: residentData['whatsappNumber'] as String?,
            email: residentData['email'] as String?,
            appRegistered: residentData['appRegistered'] as String?,
            phoneType: residentData['phoneType'] as String?,
            notes: residentData['notes'] as String?,
            visitDate: residentData['visitDate'] as String?,
            visitedBy: residentData['visitedBy'] as String?,
            dataVerified: residentData['dataVerified'] as String?,
            followUpNeeded: residentData['followUpNeeded'] as String?,
            followUpDate: residentData['followUpDate'] as String?,
            isModified: residentData['isModified'] as bool? ?? false,
            updatedAt: DateTime.parse(residentData['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
            totalFlatsInCompound: residentData['totalFlatsInCompound'] as int?,
            dataSource: residentData['dataSource'] as String?,
            verificationStatus: residentData['verificationStatus'] as String?,
            firstVerifiedDate: residentData['firstVerifiedDate'] as String?,
            lastUpdatedBy: residentData['lastUpdatedBy'] as String?,
          );

          // Check if resident already exists
          final existing = DatabaseService.getResident(resident.id);
          if (existing != null) {
            // Check if imported version is newer
            if (resident.updatedAt.isAfter(existing.updatedAt)) {
              await DatabaseService.saveResident(resident);
              updated++;
            } else {
              skipped++;
            }
          } else {
            await DatabaseService.addResident(resident);
            imported++;
          }
        } catch (e) {
          errors.add('Error importing resident ${residentData['id']}: $e');
          skipped++;
        }
      }

      return ImportResult(
        success: true,
        imported: imported,
        updated: updated,
        skipped: skipped,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        imported: 0,
        updated: 0,
        skipped: 0,
        errors: ['Failed to import file: $e'],
      );
    }
  }

  /// Get the sync file path
  static Future<String> getSyncFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_syncFileName';
  }

  /// Check if sync file exists
  static Future<bool> syncFileExists() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_syncFileName');
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking sync file: $e');
      return false;
    }
  }

  /// Get file size (for UI info)
  static Future<String> getSyncFileSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_syncFileName');
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024) {
          return '${bytes}B';
        } else if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(2)}KB';
        } else {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
        }
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }
}

class ImportResult {
  final bool success;
  final int imported;
  final int updated;
  final int skipped;
  final List<String> errors;

  ImportResult({
    required this.success,
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  String get summary {
    if (!success) {
      return 'Import failed: ${errors.join(", ")}';
    }
    return 'Imported: $imported | Updated: $updated | Skipped: $skipped';
  }
}
