import 'package:flutter/material.dart';
import '../models/resident.dart';
import '../services/database_service.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final TextEditingController _pasteController = TextEditingController();
  List<Map<String, dynamic>> _parsedRecords = [];
  bool _isParsing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  /// Fuzzy string matching to find similar addresses
  double _calculateSimilarity(String str1, String str2) {
    str1 = str1.toLowerCase().trim();
    str2 = str2.toLowerCase().trim();

    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    // Check if one contains the other
    if (str1.contains(str2) || str2.contains(str1)) {
      return 0.8;
    }

    // Levenshtein distance for fuzzy matching
    int longer = str1.length > str2.length ? str1.length : str2.length;
    if (longer == 0) return 1.0;

    int distance = _levenshteinDistance(str1, str2);
    return (longer - distance) / longer;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1.length < s2.length) {
      return _levenshteinDistance(s2, s1);
    }

    if (s2.isEmpty) {
      return s1.length;
    }

    List<int> previous = List<int>.filled(s2.length + 1, 0);
    List<int> current = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i <= s2.length; i++) {
      previous[i] = i;
    }

    for (int i = 1; i <= s1.length; i++) {
      current[0] = i;
      for (int j = 1; j <= s2.length; j++) {
        int insertions = previous[j] + 1;
        int deletions = current[j - 1] + 1;
        int substitutions = previous[j - 1] +
            (s1[i - 1] == s2[j - 1] ? 0 : 1);
        current[j] =
            [insertions, deletions, substitutions].reduce((a, b) => a < b ? a : b);
      }
      List<int> temp = previous;
      previous = current;
      current = temp;
    }

    return previous[s2.length];
  }

  /// Find the best matching address from database
  String? _findBestMatchingAddress(String inputAddress) {
    if (inputAddress.trim().isEmpty) return null;

    final allResidents = DatabaseService.getAllResidents();
    final uniqueAddresses =
        allResidents.map((r) => r.houseAddress).toSet().toList();

    String? bestMatch;
    double bestScore = 0.4; // Minimum threshold for matching

    for (final address in uniqueAddresses) {
      final score = _calculateSimilarity(inputAddress, address);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = address;
      }
    }

    return bestMatch;
  }

  /// Check if a resident with the same address + flat/name already exists
  /// Multiple residents can live at same address (different flats)
  /// Only mark as duplicate if address matches AND (flat number OR name also match)
  Map<String, dynamic>? _checkForDuplicate(
    String address, {
    String? name,
    String? flatNumber,
  }) {
    if (address.trim().isEmpty) return null;

    final allResidents = DatabaseService.getAllResidents();
    
    for (final resident in allResidents) {
      // Check for address match (fuzzy)
      final addressSimilarity = _calculateSimilarity(address, resident.houseAddress);
      if (addressSimilarity > 0.7) {
        // Address matches - now check if flat number or name also matches
        bool flatMatch = false;
        bool nameMatch = false;

        // Check flat number match
        if (flatNumber != null && resident.unitFlat != null) {
          flatMatch = _calculateSimilarity(flatNumber.toLowerCase().trim(),
                  resident.unitFlat!.toLowerCase().trim()) >
              0.7;
        }

        // Check name match
        if (name != null && resident.mainContactName != null) {
          nameMatch = _calculateSimilarity(name.toLowerCase().trim(),
                  resident.mainContactName!.toLowerCase().trim()) >
              0.7;
        }

        // Only mark as duplicate if address matches AND (flat matches OR name matches)
        if (flatMatch || nameMatch) {
          return {
            'isDuplicate': true,
            'existingResident': resident,
            'similarity': addressSimilarity,
            'reason': flatMatch ? 'Same flat number' : 'Same contact name',
          };
        }
      }
    }
    return null;
  }

  /// Parse the pasted text to extract resident details
  void _parseText() {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parsedRecords = [];
    });

    try {
      final text = _pasteController.text.trim();
      if (text.isEmpty) {
        setState(() {
          _errorMessage = 'Please paste some text first';
          _isParsing = false;
        });
        return;
      }

      // Split by double newlines or patterns that suggest new record
      final recordStrings = _splitRecords(text);
      final records = <Map<String, dynamic>>[];

      for (final recordText in recordStrings) {
        final parsed = _parseRecord(recordText);
        if (parsed['name'] != null && parsed['address'] != null) {
          records.add(parsed);
        }
      }

      if (records.isEmpty) {
        setState(() {
          _errorMessage = 'Could not parse any valid records. Please check the format.';
          _isParsing = false;
        });
        return;
      }

      setState(() {
        _parsedRecords = records;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error parsing text: $e';
        _isParsing = false;
      });
    }
  }

  /// Split text into individual records
  List<String> _splitRecords(String text) {
    // Split by double newlines or "Name" keywords
    final patterns = RegExp(r'\n\s*\n|(?=Name\s*[.;:])', multiLine: true);
    return text.split(patterns).where((s) => s.trim().isNotEmpty).toList();
  }

  /// Parse a single record text
  Map<String, dynamic> _parseRecord(String recordText) {
    final lines =
        recordText.split('\n').map((l) => l.trim()).toList();

    String? name;
    String? address;
    String? flatNumber;
    String? houseType;
    int? occupants;
    String? phoneNumber;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Extract Name
      if (_matchesPattern(line, ['name'])) {
        name = _extractValue(line);
      }

      // Extract Address
      if (_matchesPattern(line, ['address'])) {
        address = _extractValue(line);
        // Continue collecting address lines if next lines don't have keywords
        int j = i + 1;
        while (j < lines.length &&
            !_hasKeyword(lines[j]) &&
            lines[j].isNotEmpty) {
          address = '$address, ${lines[j]}';
          j++;
        }
      }
      // Handle lines starting with "No" followed by number (e.g., "No 10 Famuyiwa Street")
      // Only if it doesn't have other keywords and comes as standalone line
      else if (address == null &&
          !_matchesPattern(line, ['flat', 'type', 'occupant', 'name', 'house']) &&
          line.isNotEmpty &&
          RegExp(r'^[Nn]o\.?\s+\d').hasMatch(line.trim())) {
        address = line;
      }

      // Extract Flat Number - use more specific patterns to avoid matching "mini flat"
      if (_matchesPattern(line, ['flat number', 'flat no', 'flat:', 'flat #', 'unit', 'apartment', 'apt']) ||
          (line.toLowerCase().startsWith('flat') && 
           !line.toLowerCase().contains('bedroom') && 
           !line.toLowerCase().contains('room'))) {
        final value = _extractValue(line);
        if (value != null && 
            value.toLowerCase() != 'nill' && 
            value != 'nil' &&
            !value.toLowerCase().contains('bedroom') &&
            !value.toLowerCase().contains('room')) {
          flatNumber = value;
        }
      }

      // Extract House Type
      if (_matchesPattern(line, ['type', 'bedroom', 'room', 'duplex', 'mini flat'])) {
        final value = _extractValue(line);
        if (value != null && !value.contains('occ') && !value.contains('occupant')) {
          houseType = value;
        }
      }

      // Extract Number of Occupants
      if (_matchesPattern(line, ['occ', 'occupant', 'occupants', 'persons', 'people'])) {
        final value = _extractValue(line);
        if (value != null) {
          // Try to extract number
          final match = RegExp(r'\d+').firstMatch(value);
          if (match != null) {
            occupants = int.parse(match.group(0)!);
          }
        }
      }

      // Extract Phone Number
      if (_matchesPattern(line, ['phone', 'number', 'tel', 'contact', 'mobile', 'call', 'whatsapp'])) {
        final value = _extractValue(line);
        if (value != null && _isValidPhoneNumber(value)) {
          phoneNumber = _normalizePhoneNumber(value);
        }
      }
      // Also check for phone numbers in standalone lines (e.g., "0801234567" or "+2341234567")
      else if (phoneNumber == null && 
               _isValidPhoneNumber(line) &&
               !_hasKeyword(line)) {
        phoneNumber = _normalizePhoneNumber(line);
      }

      // Handle "Only me" pattern
      if (line.toLowerCase().contains('only me')) {
        occupants = 1;
      }
    }

    // Try to find best matching address
    String? matchedAddress;
    if (address != null) {
      matchedAddress = _findBestMatchingAddress(address);
      // If no match found, use the original address
      matchedAddress ??= address;
    }

    // Check if this address + flat/name already exists (duplicate detection)
    // Multiple residents can live at same address, so we check flat number and name too
    final duplicateInfo = matchedAddress != null
        ? _checkForDuplicate(
            matchedAddress,
            name: name,
            flatNumber: flatNumber,
          )
        : null;

    return {
      'name': name,
      'address': matchedAddress,
      'rawAddress': address,
      'flatNumber': flatNumber,
      'houseType': houseType,
      'occupants': occupants ?? 0,
      'phoneNumber': phoneNumber,
      'matched': matchedAddress != address,
      'isDuplicate': duplicateInfo != null,
      'existingResident': duplicateInfo?['existingResident'],
      'duplicateReason': duplicateInfo?['reason'],
    };
  }

  /// Check if a string is a valid phone number
  /// Accepts formats: +234XXXXXXXXXX, 0801234567, 0901234567, etc.
  bool _isValidPhoneNumber(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
    // Must have at least 10 digits (Nigerian numbers)
    final digitCount = cleaned.replaceAll('+', '').length;
    return digitCount >= 10 && RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(text);
  }

  /// Normalize phone number to standard format
  /// Converts 080... or 090... to international format +234...
  String _normalizePhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // If it starts with +234, keep it
    if (cleaned.startsWith('+234')) {
      return cleaned;
    }

    // Convert local format to international
    if (cleaned.startsWith('0')) {
      // Remove leading 0 and add +234
      return '+234${cleaned.substring(1)}';
    }

    // If it starts with 234 but no +, add it
    if (cleaned.startsWith('234')) {
      return '+$cleaned';
    }

    // Default: return as-is
    return cleaned;
  }

  /// Check if line matches any of the keywords
  bool _matchesPattern(String line, List<String> keywords) {
    final lowerLine = line.toLowerCase();
    for (final keyword in keywords) {
      if (lowerLine.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Check if line contains any keyword
  bool _hasKeyword(String line) {
    final keywords = [
      'name',
      'address',
      'flat',
      'type',
      'occupant',
      'occ',
      'apartment',
      'unit'
    ];
    return _matchesPattern(line, keywords);
  }

  /// Extract value from a line (text after : . , or =)
  String? _extractValue(String line) {
    final patterns = [':','.', ',', '=', '..', '...'];
    for (final pattern in patterns) {
      final parts = line.split(pattern);
      if (parts.length > 1) {
        return parts.sublist(1).join(pattern).trim();
      }
    }
    return line;
  }

  /// Save parsed records to database
  Future<void> _saveRecords() async {
    try {
      int saved = 0;
      int skipped = 0;
      final duplicateAddresses = <String>[];

      for (final record in _parsedRecords) {
        final address = record['address'];
        if ((address ?? '').isEmpty) continue;

        // Skip if duplicate
        if (record['isDuplicate'] == true) {
          skipped++;
          duplicateAddresses.add(address);
          continue;
        }

        // Try to find or create resident
        final resident = Resident(
          id: 0,
          houseAddress: address,
          unitFlat: record['flatNumber'],
          houseType: record['houseType'],
          occupancyStatus: 'Yes',
          householdsCount: 1,
          adults: record['occupants'] ?? 0,
          children: 0,
          mainContactName: record['name'],
          phoneNumber: record['phoneNumber'],
          whatsappNumber: record['phoneNumber'],
          dataSource: 'WhatsApp Import',
          verificationStatus: 'Verified',
          isModified: true,
        );

        await DatabaseService.addResident(resident);
        saved++;
      }

      if (mounted) {
        String message = 'Successfully imported $saved residents';
        if (skipped > 0) {
          message += ' ($skipped duplicates skipped)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: skipped > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear form and go back
        _pasteController.clear();
        setState(() {
          _parsedRecords = [];
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import from WhatsApp'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Paste WhatsApp responses here. The app will auto-parse:',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('• Name'),
                          Text('• Address'),
                          Text('• Flat number'),
                          Text('• House type'),
                          Text('• Number of occupants'),
                          Text('• Phone number (optional)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Input field
            TextField(
              controller: _pasteController,
              decoration: InputDecoration(
                labelText: 'Paste WhatsApp message',
                hintText: 'Copy responses from WhatsApp and paste here...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 8,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),

            // Parse button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isParsing ? null : _parseText,
                icon: _isParsing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isParsing ? 'Parsing...' : 'Parse & Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview of parsed records
            if (_parsedRecords.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Found Records',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_parsedRecords.length}'),
                    backgroundColor: Colors.blue,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _parsedRecords.length,
                itemBuilder: (context, index) {
                  final record = _parsedRecords[index];
                  final isDuplicate = record['isDuplicate'] == true;
                  final existingResident = record['existingResident'] as Resident?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isDuplicate ? Colors.red.shade50 : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Duplicate warning banner
                          if (isDuplicate) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      color: Colors.red.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'DUPLICATE: Information already exists',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (existingResident != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Existing contact: ${existingResident.mainContactName ?? "Unknown"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade600,
                                ),
                              ),
                              if (existingResident.unitFlat != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Flat: ${existingResident.unitFlat}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              if (record['duplicateReason'] != null)
                                Text(
                                  'Reason: ${record['duplicateReason']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                            const Divider(height: 12),
                          ],
                          // Name
                          _buildDetailRow(
                            'Name',
                            record['name'] ?? 'N/A',
                            Icons.person,
                          ),
                          const Divider(height: 12),
                          // Address
                          _buildDetailRow(
                            'Address',
                            record['address'] ?? 'N/A',
                            Icons.location_on,
                            warning: record['matched'] == true,
                          ),
                          const Divider(height: 12),
                          // Flat number
                          _buildDetailRow(
                            'Flat #',
                            record['flatNumber'] ?? '—',
                            Icons.door_sliding,
                          ),
                          const Divider(height: 12),
                          // House type
                          _buildDetailRow(
                            'Type',
                            record['houseType'] ?? 'Unknown',
                            Icons.home,
                          ),
                          const Divider(height: 12),
                          // Occupants
                          _buildDetailRow(
                            'Occupants',
                            '${record['occupants']} person(s)',
                            Icons.people,
                          ),
                          const Divider(height: 12),
                          // Phone Number
                          _buildDetailRow(
                            'Phone',
                            record['phoneNumber'] ?? '—',
                            Icons.phone_outlined,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Show warnings for duplicates and fuzzy matches
              if (_parsedRecords.any((r) => r['isDuplicate'] == true))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_parsedRecords.where((r) => r['isDuplicate'] == true).length} duplicate record(s) found — these will be skipped on save.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_parsedRecords.any((r) => r['matched'] == true) &&
                  !_parsedRecords.any((r) => r['isDuplicate'] == true))
                const SizedBox(height: 12),
              if (_parsedRecords.any((r) => r['matched'] == true))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some addresses were fuzzy-matched to existing addresses.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveRecords,
                  icon: const Icon(Icons.save),
                  label: Text(
                    () {
                      final total = _parsedRecords.length;
                      final duplicates = _parsedRecords.where((r) => r['isDuplicate'] == true).length;
                      final toSave = total - duplicates;
                      return duplicates > 0
                          ? 'Save $toSave Records (Skip $duplicates Duplicates)'
                          : 'Save $toSave Records';
                    }(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool warning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: warning ? Colors.orange.shade700 : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (warning)
          Icon(Icons.info, size: 16, color: Colors.orange.shade700),
      ],
    );
  }
}
