import 'package:hive/hive.dart';

part 'resident.g.dart';

// Result class for duplicate flat number check
class RestdentDuplicateCheckResult {
  final bool hasDuplicate;
  final Resident? conflictingResident;
  final List<Resident> existingFlats;

  RestdentDuplicateCheckResult({
    required this.hasDuplicate,
    this.conflictingResident,
    required this.existingFlats,
  });
}

@HiveType(typeId: 0)
class Resident extends HiveObject {
  @HiveField(0)
  int id; // S/N from CSV

  @HiveField(1)
  String houseAddress;

  @HiveField(2)
  String? zoneBlock;

  @HiveField(3)
  String? houseType;

  @HiveField(4)
  String? unitFlat;

  @HiveField(5)
  String occupancyStatus; // "Yes" = Occupied, "No" = Vacant

  @HiveField(6)
  String? recordStatus;

  @HiveField(7)
  int householdsCount;

  @HiveField(8)
  int monthlyDue;

  @HiveField(9)
  String? paymentStatus;

  @HiveField(10)
  String? lastPaymentDate;

  @HiveField(11)
  int adults;

  @HiveField(12)
  int children;

  @HiveField(13)
  int totalHeadcount;

  @HiveField(14)
  String? mainContactName;

  @HiveField(15)
  String? contactRole;

  @HiveField(16)
  String? phoneNumber;

  @HiveField(17)
  String? whatsappNumber;

  @HiveField(18)
  String? email;

  @HiveField(19)
  String? appRegistered;

  @HiveField(20)
  String? phoneType;

  @HiveField(21)
  String? notes;

  @HiveField(22)
  String? visitDate;

  @HiveField(23)
  String? visitedBy;

  @HiveField(24)
  String? dataVerified;

  @HiveField(25)
  String? followUpNeeded;

  @HiveField(26)
  String? followUpDate;

  @HiveField(27)
  bool isModified;

  @HiveField(28)
  DateTime updatedAt;

  // --- NEW FIELDS (matching final Excel sheet) ---

  @HiveField(29)
  int? totalFlatsInCompound; // Total flats in the compound

  @HiveField(30)
  String? dataSource; // "Preloaded" | "Field Added"

  @HiveField(31)
  String? verificationStatus; // "Verified" | "Unverified"

  @HiveField(32)
  String? firstVerifiedDate; // Auto-set on first verification

  @HiveField(33)
  String? lastUpdatedBy; // Auto-set to field agent name on every save

  @HiveField(34)
  String? avatarImagePath; // Path to house image/avatar

  Resident({
    required this.id,
    required this.houseAddress,
    this.zoneBlock,
    this.houseType,
    this.unitFlat,
    this.occupancyStatus = 'No',
    this.recordStatus,
    this.householdsCount = 0,
    this.monthlyDue = 0,
    this.paymentStatus,
    this.lastPaymentDate,
    this.adults = 0,
    this.children = 0,
    this.totalHeadcount = 0,
    this.mainContactName,
    this.contactRole,
    this.phoneNumber,
    this.whatsappNumber,
    this.email,
    this.appRegistered,
    this.phoneType,
    this.notes,
    this.visitDate,
    this.visitedBy,
    this.dataVerified,
    this.followUpNeeded,
    this.followUpDate,
    this.isModified = false,
    DateTime? updatedAt,
    this.totalFlatsInCompound,
    this.dataSource,
    this.verificationStatus,
    this.firstVerifiedDate,
    this.lastUpdatedBy,
    this.avatarImagePath,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // Helper methods
  bool get isOccupied => occupancyStatus.toLowerCase() == 'yes';
  bool get needsFollowUp => followUpNeeded?.toLowerCase() == 'yes';
  bool get isVerified => verificationStatus?.toLowerCase() == 'verified';

  // Calculate total headcount
  void calculateTotalHeadcount() {
    totalHeadcount = adults + children;
  }

  // Copy with method for creating updated instances
  Resident copyWith({
    int? id,
    String? houseAddress,
    String? zoneBlock,
    String? houseType,
    String? unitFlat,
    String? occupancyStatus,
    String? recordStatus,
    int? householdsCount,
    int? monthlyDue,
    String? paymentStatus,
    String? lastPaymentDate,
    int? adults,
    int? children,
    int? totalHeadcount,
    String? mainContactName,
    String? contactRole,
    String? phoneNumber,
    String? whatsappNumber,
    String? email,
    String? appRegistered,
    String? phoneType,
    String? notes,
    String? visitDate,
    String? visitedBy,
    String? dataVerified,
    String? followUpNeeded,
    String? followUpDate,
    bool? isModified,
    DateTime? updatedAt,
    int? totalFlatsInCompound,
    String? dataSource,
    String? verificationStatus,
    String? firstVerifiedDate,
    String? lastUpdatedBy,
    String? avatarImagePath,
  }) {
    return Resident(
      id: id ?? this.id,
      houseAddress: houseAddress ?? this.houseAddress,
      zoneBlock: zoneBlock ?? this.zoneBlock,
      houseType: houseType ?? this.houseType,
      unitFlat: unitFlat ?? this.unitFlat,
      occupancyStatus: occupancyStatus ?? this.occupancyStatus,
      recordStatus: recordStatus ?? this.recordStatus,
      householdsCount: householdsCount ?? this.householdsCount,
      monthlyDue: monthlyDue ?? this.monthlyDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      adults: adults ?? this.adults,
      children: children ?? this.children,
      totalHeadcount: totalHeadcount ?? this.totalHeadcount,
      mainContactName: mainContactName ?? this.mainContactName,
      contactRole: contactRole ?? this.contactRole,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      appRegistered: appRegistered ?? this.appRegistered,
      phoneType: phoneType ?? this.phoneType,
      notes: notes ?? this.notes,
      visitDate: visitDate ?? this.visitDate,
      visitedBy: visitedBy ?? this.visitedBy,
      dataVerified: dataVerified ?? this.dataVerified,
      followUpNeeded: followUpNeeded ?? this.followUpNeeded,
      followUpDate: followUpDate ?? this.followUpDate,
      isModified: isModified ?? this.isModified,
      updatedAt: updatedAt ?? DateTime.now(),
      totalFlatsInCompound: totalFlatsInCompound ?? this.totalFlatsInCompound,
      dataSource: dataSource ?? this.dataSource,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      firstVerifiedDate: firstVerifiedDate ?? this.firstVerifiedDate,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
    );
  }

  // Create from CSV row — 32-column format matching the final Excel sheet
  // Col:  0    1              2          3                      4          5          6
  //      S/N  HouseAddr  Zone/Block  TotalFlats  HouseType  Unit/Flat  Occupied?
  // Col:  7            8          9              10               11      12        13
  //      RecordStatus  #HH  MonthlyDue  PaymentStatus  LastPayDate  Adults  Children
  // Col:  14          15              16           17        18       19            20
  //      TotalHC  MainContact  ContactRole  Phone  WhatsApp  Email  AppRegistered?
  // Col:  21         22         23          24          25             26           27
  //      PhoneType  Notes  VisitDate  VisitedBy  DataVerified  FollowUp?  FollowUpDate
  // Col:  28          29                  30               31
  //      DataSource  VerificationStatus  FirstVerifiedDate  LastUpdatedBy
  factory Resident.fromCsvRow(List<dynamic> row) {
    int safeInt(dynamic value, [int defaultValue = 0]) {
      if (value == null || value.toString().trim().isEmpty) return defaultValue;
      try {
        return int.parse(value.toString().replaceAll(',', '').trim());
      } catch (e) {
        return defaultValue;
      }
    }

    String safeString(dynamic value) {
      return value?.toString().trim() ?? '';
    }

    String? safeNullString(dynamic value) {
      final s = value?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    int? safeNullInt(dynamic value) {
      if (value == null || value.toString().trim().isEmpty) return null;
      try {
        return int.parse(value.toString().replaceAll(',', '').trim());
      } catch (e) {
        return null;
      }
    }

    String normalizeYesNo(dynamic value, {String fallback = 'No'}) {
      final raw = value?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty) return fallback;
      if (raw == 'yes' || raw == 'y' || raw == 'occupied' || raw == 'true') {
        return 'Yes';
      }
      if (raw == 'no' || raw == 'n' || raw == 'vacant' || raw == 'false') {
        return 'No';
      }
      return fallback;
    }

    String? normalizeContactRole(dynamic value) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      final lower = raw.toLowerCase();
      if (lower == 'owner') return 'Owner';
      if (lower == 'tenant') return 'Tenant';
      if (lower == 'caretaker' || lower == 'care taker') return 'Caretaker';
      return raw;
    }

    // Normalise House Type casing from older data
    String? normaliseHouseType(dynamic value) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      // Normalise known variants
      final lower = raw.toLowerCase();
      if (lower == 'mini flat' || lower == 'mini-flat') return 'Mini flat';
      if (lower == '1 room') return '1 room';
      if (lower == '1 bedroom' || lower == '1 bedrooms') return '1 bedroom';
      if (lower == '2 bedroom' || lower == '2 bedrooms' || lower == '2-bedroom') return '2 bedroom';
      if (lower == '3 bedroom' || lower == '3 bedrooms' || lower == '3-bedroom') return '3 bedroom';
      if (lower == '4 bedroom' || lower == '4 bedrooms') return '4 bedroom';
      if (lower.contains('4 bedroom') && lower.contains('terrace')) return '4 bedroom terrace';
      if (lower == '5 bedroom' || lower == '5 bedrooms') return '5 bedroom';
      if (lower == 'bungalow') return 'Bungalow';
      if (lower == 'duplex') return 'Duplex';
      // Return as-is for anything else (or null for obvious garbage like "200", "300")
      if (double.tryParse(raw) != null) return null;
      return raw;
    }

    final adults = safeInt(row.length > 12 ? row[12] : null);
    final children = safeInt(row.length > 13 ? row[13] : null);
    final occupancyStatus = normalizeYesNo(row.length > 6 ? row[6] : 'No');
    final normalizedRecordStatus =
        occupancyStatus == 'Yes' ? 'Occupied' : 'Vacant';

    return Resident(
      id: safeInt(row.isNotEmpty ? row[0] : null, 0),
      houseAddress: safeString(row.length > 1 ? row[1] : null),
      zoneBlock: safeNullString(row.length > 2 ? row[2] : null),
      totalFlatsInCompound: safeNullInt(row.length > 3 ? row[3] : null),
      houseType: normaliseHouseType(row.length > 4 ? row[4] : null),
      unitFlat: safeNullString(row.length > 5 ? row[5] : null),
      occupancyStatus: occupancyStatus,
      recordStatus: normalizedRecordStatus,
      householdsCount: safeInt(row.length > 8 ? row[8] : null),
      monthlyDue: safeInt(row.length > 9 ? row[9] : null),
      paymentStatus: safeNullString(row.length > 10 ? row[10] : null),
      lastPaymentDate: safeNullString(row.length > 11 ? row[11] : null),
      adults: adults,
      children: children,
      totalHeadcount: adults + children,
      mainContactName: safeNullString(row.length > 15 ? row[15] : null),
      contactRole: normalizeContactRole(row.length > 16 ? row[16] : null),
      phoneNumber: safeNullString(row.length > 17 ? row[17] : null),
      whatsappNumber: safeNullString(row.length > 18 ? row[18] : null),
      email: safeNullString(row.length > 19 ? row[19] : null),
      appRegistered: normalizeYesNo(row.length > 20 ? row[20] : null),
      phoneType: safeNullString(row.length > 21 ? row[21] : null),
      notes: safeNullString(row.length > 22 ? row[22] : null),
      visitDate: safeNullString(row.length > 23 ? row[23] : null),
      visitedBy: safeNullString(row.length > 24 ? row[24] : null),
      dataVerified: normalizeYesNo(row.length > 25 ? row[25] : null),
      followUpNeeded: normalizeYesNo(row.length > 26 ? row[26] : null),
      followUpDate: safeNullString(row.length > 27 ? row[27] : null),
      dataSource: safeNullString(row.length > 28 ? row[28] : null) ?? 'Preloaded',
      verificationStatus: safeNullString(row.length > 29 ? row[29] : null) ?? 'Unverified',
      firstVerifiedDate: safeNullString(row.length > 30 ? row[30] : null),
      lastUpdatedBy: safeNullString(row.length > 31 ? row[31] : null),
      avatarImagePath: null,
    );
  }

  // Convert to CSV row — 32 columns, matching exact Excel column order
  List<String> toCsvRow() {
    final normalizedRecordStatus = isOccupied ? 'Occupied' : 'Vacant';
    return [
      id.toString(),                        // S/N
      houseAddress,                         // House Address
      zoneBlock ?? '',                      // Zone/Block
      totalFlatsInCompound?.toString() ?? '', // Total Flats in compound
      houseType ?? '',                      // House Type
      unitFlat ?? '',                       // Unit/Flat
      occupancyStatus,                      // Occupied?
      normalizedRecordStatus,               // Record Status
      householdsCount.toString(),           // # Households
      monthlyDue.toString(),                // Monthly Due
      paymentStatus ?? '',                  // Payment Status
      lastPaymentDate ?? '',                // Last Payment Date
      adults.toString(),                    // Adults
      children.toString(),                  // Children
      totalHeadcount.toString(),            // Total Headcount
      mainContactName ?? '',                // Main Contact Name
      contactRole ?? '',                    // Contact Role
      phoneNumber ?? '',                    // Phone Number
      whatsappNumber ?? '',                 // WhatsApp Number
      email ?? '',                          // Email
      appRegistered ?? '',                  // App Registered?
      phoneType ?? '',                      // Phone Type
      notes ?? '',                          // Notes/Issues
      visitDate ?? '',                      // Visit Date
      visitedBy ?? '',                      // Visited By
      dataVerified ?? '',                   // Data Verified?
      followUpNeeded ?? '',                 // Follow-up Needed?
      followUpDate ?? '',                   // Follow-up Date
      dataSource ?? 'Preloaded',            // Data Source
      verificationStatus ?? 'Unverified',   // Verification Status
      firstVerifiedDate ?? '',              // First Verified Date
      lastUpdatedBy ?? '',                  // Last Updated By
    ];
  }
}
