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

  // ---------------------------------------------------------------------------
  // Fuzzy matching helpers
  // ---------------------------------------------------------------------------

  double _calculateSimilarity(String str1, String str2) {
    str1 = str1.toLowerCase().trim();
    str2 = str2.toLowerCase().trim();
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;
    if (str1.contains(str2) || str2.contains(str1)) return 0.8;
    final longer = str1.length > str2.length ? str1.length : str2.length;
    final distance = _levenshteinDistance(str1, str2);
    return (longer - distance) / longer;
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.length < s2.length) return _levenshteinDistance(s2, s1);
    if (s2.isEmpty) return s1.length;
    List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    List<int> curr = List<int>.filled(s2.length + 1, 0);
    for (int i = 1; i <= s1.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= s2.length; j++) {
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + (s1[i - 1] == s2[j - 1] ? 0 : 1),
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev; prev = curr; curr = tmp;
    }
    return prev[s2.length];
  }

  String? _findBestMatchingAddress(String input) {
    if (input.trim().isEmpty) return null;
    final unique = DatabaseService.getAllResidents()
        .map((r) => r.houseAddress)
        .toSet()
        .toList();
    String? best;
    double bestScore = 0.85; // Require 85%+ similarity to match
    for (final addr in unique) {
      final score = _calculateSimilarity(input, addr);
      if (score > bestScore) {
        bestScore = score;
        best = addr;
      }
    }
    return best;
  }

  /// Get all preloaded address data for a given address
  Map<String, dynamic>? _getAddressData(String address) {
    try {
      final residents = DatabaseService.getAllResidents()
          .where((r) => r.houseAddress == address)
          .toList();
      
      if (residents.isEmpty) return null;
      
      // Get first resident for compound-level data
      final first = residents.first;
      return {
        'address': address,
        'zoneBlock': first.zoneBlock,
        'houseType': first.houseType,
        'totalFlatsInCompound': first.totalFlatsInCompound,
        'occupiedCount': residents.where((r) => r.occupancyStatus == 'Yes').length,
        'vacantCount': residents.where((r) => r.occupancyStatus == 'No').length,
        'totalResidents': residents.length,
      };
    } catch (e) {
      debugPrint('Error getting address data: $e');
      return null;
    }
  }

  /// Show search dialog to select correct address
  Future<String?> _showAddressSearchDialog(String attemptedAddress) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _AddressSearchDialog(
        initialSearch: attemptedAddress,
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Top-level parse entry
  // ---------------------------------------------------------------------------

  void _parseText() {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parsedRecords = [];
    });
    try {
      final raw = _pasteController.text.trim();
      if (raw.isEmpty) {
        setState(() {
          _errorMessage = 'Please paste some text first';
          _isParsing = false;
        });
        return;
      }
      final blocks = _splitRecords(raw);
      final records = <Map<String, dynamic>>[];
      for (final block in blocks) {
        final parsed = _parseRecord(block);
        if (parsed['name'] != null || parsed['address'] != null) {
          records.add(parsed);
        }
      }
      if (records.isEmpty) {
        setState(() {
          _errorMessage =
              'Could not parse any valid records. Make sure records are separated by blank lines, or use the "Name: ..." format.';
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

  // ---------------------------------------------------------------------------
  // Record splitting
  // ---------------------------------------------------------------------------

  /// Splits a multi-record paste into individual record strings.
  ///
  /// Boundaries are:
  ///  1. One or more blank lines.
  ///  2. A line that starts with "Name" followed by any separator
  ///     (handles  "Name: X",  "Name :: X",  "Name - X",  "Name = X").
  ///
  /// Template header lines ("Please share your details…") are stripped first.
  List<String> _splitRecords(String text) {
    // Remove WhatsApp template header lines
    text = text.replaceAll(
      RegExp(
        r'^\s*please\s+share\s+your\s+details.*$',
        multiLine: true,
        caseSensitive: false,
      ),
      '',
    );

    // Split on:
    //   (a) 1+ blank lines
    //   (b) Before a line that starts with "Name" + separator (lookahead)
    //       Separators:  ::  |  :  |  -  |  =  |  .  followed by non-whitespace
    final parts = text.split(RegExp(
      r'\n[ \t]*\n+|(?=[ \t]*\bName\s*(?:::|-+|:|\.|=)\s*\S)',
      caseSensitive: false,
    ));

    return parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Single-record parser
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _parseRecord(String recordText) {
    final lines = recordText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return {};

    String? name, address, flatNumber, houseType, phoneNumber;
    int? occupants;
    final processed = <int>{};

    // ------------------------------------------------------------------
    // PASS 1 – labeled fields
    // Matches any of:  "Label: value"  "Label :: value"
    //                  "Label - value" "Label = value"
    // ------------------------------------------------------------------
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Flexible label+separator+value regex
      final m = RegExp(r'^(.+?)\s*(?:::|-+|:|\.|=)\s*(.+)$').firstMatch(line);
      if (m == null) continue;

      final label = m.group(1)!.toLowerCase().trim();
      final value = m.group(2)!.trim();
      if (value.isEmpty) continue;

      if (_labelIs(label, ['name', 'full name', 'resident name', 'names'])) {
        name ??= value;
        processed.add(i);
      } else if (_labelIs(label, ['address', 'location', 'house address', 'addr'])) {
        address ??= value;
        processed.add(i);
      } else if (_labelIs(label, ['flat', 'flat number', 'flat no', 'flat #', 'unit', 'apt', 'apartment'])) {
        if (flatNumber == null && !_isHouseTypeValue(value)) {
          flatNumber = _extractFlatNumber(value);
          processed.add(i);
        }
      } else if (_labelIs(label, ['house type', 'type', 'house', 'housing type', 'accommodation'])) {
        houseType ??= value;
        processed.add(i);
      } else if (_labelIs(label, [
        'occupant', 'occupants', 'number of occupant', 'number of occupants',
        'no of occupant', 'no. of occupant', 'occ', 'persons', 'person',
        'people', 'number of people', 'number of persons', 'no of persons',
        'number', 'no',
      ])) {
        // Only treat as occupants if the label clearly references count
        // (avoid absorbing "No 19 Milestone" as occupants via label "no")
        if (_labelIs(label, [
          'occupant', 'occupants', 'number of occupant', 'number of occupants',
          'no of occupant', 'no. of occupant', 'occ', 'persons', 'person',
          'people', 'number of people', 'number of persons', 'no of persons',
        ])) {
          occupants ??= _parseOccupants(value);
          processed.add(i);
        }
      } else if (_labelIs(label, ['phone', 'tel', 'mobile', 'whatsapp', 'contact', 'contact number', 'number'])) {
        if (phoneNumber == null && _isValidPhoneNumber(value)) {
          phoneNumber = _normalizePhoneNumber(value);
          processed.add(i);
        }
      }
    }

    // ------------------------------------------------------------------
    // PASS 2 – content-based detection for unprocessed lines
    // Order matters: most-specific checks first, catch-alls last.
    // ------------------------------------------------------------------
    for (int i = 0; i < lines.length; i++) {
      if (processed.contains(i)) continue;
      final line = lines[i];

      if (flatNumber == null && _looksLikeFlat(line)) {
        flatNumber = _extractFlatNumber(_stripLabelPrefix(line));
        processed.add(i);
      } else if (houseType == null && _looksLikeHouseType(line)) {
        houseType = line;
        processed.add(i);
      } else if (occupants == null && _looksLikeOccupants(line)) {
        occupants = _parseOccupants(line);
        processed.add(i);
      } else if (phoneNumber == null && _isValidPhoneNumber(line)) {
        phoneNumber = _normalizePhoneNumber(line);
        processed.add(i);
      } else if (address == null && _looksLikeAddress(line)) {
        // Explicit address-keyword lines get captured here
        address = line;
        processed.add(i);
        // Absorb continuation lines (e.g. "Ajah, Lagos State" on the next line)
        int j = i + 1;
        while (j < lines.length &&
            !processed.contains(j) &&
            !_looksLikeFlat(lines[j]) &&
            !_looksLikeHouseType(lines[j]) &&
            !_looksLikeOccupants(lines[j]) &&
            !_isValidPhoneNumber(lines[j])) {
          address = '$address, ${lines[j]}';
          processed.add(j);
          j++;
        }
      } else if (name == null && _looksLikeName(line)) {
        // First line that isn't anything specific → name
        name = line;
        processed.add(i);
      }
    }

    // ------------------------------------------------------------------
    // PASS 3 – positional fallback for fully unlabeled records
    // Any remaining unprocessed lines fill name → address in order.
    // ------------------------------------------------------------------
    for (int i = 0; i < lines.length; i++) {
      if (processed.contains(i)) continue;
      final line = lines[i];
      if (name == null) {
        name = line;
        processed.add(i);
      } else if (address == null) {
        address = line;
        processed.add(i);
        // Absorb continuation
        int j = i + 1;
        while (j < lines.length &&
            !processed.contains(j) &&
            !_looksLikeFlat(lines[j]) &&
            !_looksLikeHouseType(lines[j]) &&
            !_looksLikeOccupants(lines[j]) &&
            !_isValidPhoneNumber(lines[j])) {
          address = '$address, ${lines[j]}';
          processed.add(j);
          j++;
        }
      }
    }

    // Match address against database
    // Only use addresses that exist in preloaded data (85%+ match)
    String? matchedAddress;
    Map<String, dynamic>? addressData;
    if (address != null) {
      matchedAddress = _findBestMatchingAddress(address);
      // Do NOT fall back to raw address - only use preloaded addresses
      if (matchedAddress != null) {
        addressData = _getAddressData(matchedAddress);
      }
    }

    return {
      'name': name,
      'address': matchedAddress,
      'rawAddress': address,
      'flatNumber': flatNumber,
      'houseType': houseType ?? addressData?['houseType'],
      'occupants': occupants ?? 0,
      'phoneNumber': phoneNumber,
      'matched': matchedAddress != null && matchedAddress != address,
      'unmatchedAddress': matchedAddress == null && address != null,
      'addressData': addressData,
      'zoneBlock': addressData?['zoneBlock'],
      'totalFlatsInCompound': addressData?['totalFlatsInCompound'],
    };
  }

  // ---------------------------------------------------------------------------
  // Detection helpers
  // ---------------------------------------------------------------------------

  /// Returns true if the label contains ANY of the given keywords.
  bool _labelIs(String label, List<String> keywords) {
    for (final k in keywords) {
      if (label.contains(k)) return true;
    }
    return false;
  }

  /// Returns true if a house-type value should NOT be treated as a flat number.
  bool _isHouseTypeValue(String value) {
    final v = value.toLowerCase();
    return v.contains('bedroom') || v.contains(' room') ||
        v.contains('duplex') || v.contains('bungalow') ||
        v.contains('studio') || v.contains('self contain') ||
        v.contains('miniflat') || v.contains('mini flat');
  }

  bool _looksLikeAddress(String line) {
    final l = line.toLowerCase();
    const keywords = [
      'street', 'avenue', 'ave', 'close', 'road', 'estate',
      'apartment', 'floor', 'building', 'compound', 'complex',
      'lane', 'drive', 'plaza', 'court', 'crescent', 'way',
      'infinity', 'milestone', 'junction',
    ];
    // "No 19 …" / "No. 19 …" / "House 4 …"
    if (RegExp(r'^(?:no\.?\s*\d|house\s*\d|\d+[a-z]?\s)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    return keywords.any((k) => l.contains(k));
  }

  bool _looksLikeFlat(String line) {
    final l = line.toLowerCase();
    return (l.contains('flat') || l.contains('unit') ||
            l.contains('apt') || l.contains('apartment')) &&
        !l.contains('bedroom') &&
        !l.contains(' room') &&
        !l.contains('self contain') &&
        !l.contains('miniflat') &&
        !l.contains('mini flat');
  }

  bool _looksLikeHouseType(String line) {
    final l = line.toLowerCase();
    const keywords = [
      'bedroom', 'duplex', 'bungalow', 'studio', 'penthouse',
      'self contain', 'self-contain', 'miniflat', 'mini flat', 'mini-flat',
      '1 room', '2 room', '3 room', 'a room', 'room and parlour',
    ];
    if (keywords.any((k) => l.contains(k))) return true;
    // "2bedroom", "3bedroom" with no space
    if (RegExp(r'^\d+\s*bedroom').hasMatch(l)) return true;
    return false;
  }

  bool _looksLikeOccupants(String line) {
    final l = line.toLowerCase().trim();

    // Pure integer: "2", "6"
    if (RegExp(r'^\d+$').hasMatch(l)) return true;

    // Digit + occupant word (with or without space): "2occupants", "3 people"
    if (RegExp(r'^\d+\s*(occupant|person|people|occ)\w*$').hasMatch(l)) return true;

    // Word number alone: "six", "three"
    if (_numberWordValue(l) != null && !l.contains(' ')) return true;

    // Word number + occupant noun: "six occupants", "three people"
    final wordOccupant = RegExp(
      r'^(one|two|three|four|five|six|seven|eight|nine|ten)\s+(occupant|person|people|occ)\w*$',
    );
    if (wordOccupant.hasMatch(l)) return true;

    return false;
  }

  bool _looksLikeName(String line) {
    return !_looksLikeAddress(line) &&
        !_looksLikeFlat(line) &&
        !_looksLikeHouseType(line) &&
        !_looksLikeOccupants(line) &&
        !_isValidPhoneNumber(line) &&
        !RegExp(r'^\d+$').hasMatch(line.trim());
  }

  // ---------------------------------------------------------------------------
  // Value extraction helpers
  // ---------------------------------------------------------------------------

  /// Strips a "Label: " or "Label - " prefix from a line, returning just the value.
  /// Falls back to the full line if no separator is found.
  String _stripLabelPrefix(String line) {
    final m = RegExp(r'^.+?\s*(?:::|-+|:|\.|=)\s*(.+)$').firstMatch(line);
    return m?.group(1)?.trim() ?? line.trim();
  }

  /// Extracts just the number from strings like "Flat 10", "flat 3", "10", "Flat number 1".
  String _extractFlatNumber(String value) {
    value = value.trim();
    // "flat 10", "flat number 3", "unit 5", "apt 7"
    final prefixMatch = RegExp(
      r'^(?:flat\s*(?:number\s*)?|unit\s*|apt\s*|apartment\s*)(\w+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (prefixMatch != null) return prefixMatch.group(1)!;
    // Pure number or alphanumeric like "10", "108", "A1"
    final numMatch = RegExp(r'[\dA-Za-z]+').firstMatch(value);
    return numMatch?.group(0) ?? value;
  }

  int? _parseOccupants(String text) {
    final t = text.toLowerCase().trim();
    // Try numeric first
    final numMatch = RegExp(r'\d+').firstMatch(t);
    if (numMatch != null) return int.tryParse(numMatch.group(0)!);
    // Word numbers
    return _numberWordValue(t);
  }

  int? _numberWordValue(String text) {
    const map = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    };
    for (final e in map.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return null;
  }

  bool _isValidPhoneNumber(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
    final digits = cleaned.replaceAll('+', '').length;
    return digits >= 10 && RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(text);
  }

  String _normalizePhoneNumber(String phone) {
    String c = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (c.startsWith('+234')) return c;
    if (c.startsWith('0')) return '+234${c.substring(1)}';
    if (c.startsWith('234')) return '+$c';
    return c;
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _saveRecords() async {
    try {
      int saved = 0;
      int skipped = 0;

      for (final record in _parsedRecords) {
        final address = record['address'];
        
        // Skip records without matched address (preloaded address)
        if ((address ?? '').isEmpty) {
          if (record['unmatchedAddress'] == true) {
            skipped++;
          }
          continue;
        }

        final resident = Resident(
          id: 0,
          houseAddress: address,
          zoneBlock: record['zoneBlock'],
          unitFlat: record['flatNumber'],
          houseType: record['houseType'],
          occupancyStatus: 'Yes',
          householdsCount: 1,
          monthlyDue: 0,
          adults: record['occupants'] ?? 0,
          children: 0,
          mainContactName: record['name'],
          phoneNumber: record['phoneNumber'],
          whatsappNumber: record['phoneNumber'],
          dataSource: 'WhatsApp Import',
          verificationStatus: 'Verified',
          isModified: true,
          totalFlatsInCompound: record['totalFlatsInCompound'],
        );
        await DatabaseService.addResident(resident);
        saved++;
      }

      if (mounted) {
        String msg = 'Successfully imported $saved resident${saved == 1 ? "" : "s"}';
        if (skipped > 0) {
          msg += '\n($skipped address${skipped == 1 ? "" : "es"} did not match preloaded units - skipped)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: skipped > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        _pasteController.clear();
        setState(() => _parsedRecords = []);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
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

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import from WhatsApp'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions card
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
                              'Paste one or many WhatsApp responses. Supports labeled and unlabeled formats.',
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
                            Text('• Separate multiple records with a blank line'),
                            Text('• Works with  Name: / Name :: / Name -  formats'),
                            Text('• Also works with no labels at all'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Input
              TextField(
                controller: _pasteController,
                decoration: InputDecoration(
                  labelText: 'Paste WhatsApp messages',
                  hintText: 'Copy responses from WhatsApp and paste here…',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 10,
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
                  label: Text(_isParsing ? 'Parsing…' : 'Parse & Preview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Error
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

              // Preview
              if (_parsedRecords.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'Found Records',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    final r = _parsedRecords[index];
                    final unmatched = r['unmatchedAddress'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: unmatched ? Colors.orange.shade50 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (unmatched) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  border: Border.all(color: Colors.orange.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber,
                                            color: Colors.orange.shade700, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Address not in preloaded data',
                                                style: TextStyle(
                                                  color: Colors.orange.shade700,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                'Tried: ${r['rawAddress']}',
                                                style: TextStyle(
                                                  color: Colors.orange.shade600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final selected =
                                              await _showAddressSearchDialog(
                                                  r['rawAddress'] ?? '');
                                          if (selected != null) {
                                            setState(() {
                                              _parsedRecords[index]['address'] =
                                                  selected;
                                              _parsedRecords[index]
                                                  ['unmatchedAddress'] = false;
                                              _parsedRecords[index]['matched'] = true;
                                              final data =
                                                  _getAddressData(selected);
                                              if (data != null) {
                                                _parsedRecords[index]
                                                    ['addressData'] = data;
                                                _parsedRecords[index]
                                                    ['zoneBlock'] = data['zoneBlock'];
                                                _parsedRecords[index][
                                                        'totalFlatsInCompound'] =
                                                    data['totalFlatsInCompound'];
                                                if (_parsedRecords[index]
                                                        ['houseType'] ==
                                                    null) {
                                                  _parsedRecords[index]
                                                      ['houseType'] = data[
                                                      'houseType'];
                                                }
                                              }
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.search, size: 18),
                                        label: const Text('Search Address'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 12),
                            ],
                            _row('Name', r['name'] ?? '—', Icons.person),
                            const Divider(height: 10),
                            _row(
                              'Address',
                              r['address'] ?? '—',
                              Icons.location_on,
                              warning: r['matched'] == true,
                              subtitle: r['matched'] == true
                                  ? 'Matched from: ${r['rawAddress']}'
                                  : null,
                            ),
                            const Divider(height: 10),
                            if (r['zoneBlock'] != null)
                              _row('Zone/Block', r['zoneBlock'] ?? '—', Icons.location_city),
                            if (r['zoneBlock'] != null) const Divider(height: 10),
                            if (r['totalFlatsInCompound'] != null)
                              _row('Total Flats', '${r['totalFlatsInCompound']}', Icons.apartment),
                            if (r['totalFlatsInCompound'] != null) const Divider(height: 10),
                            _row('Flat #', r['flatNumber'] ?? '—', Icons.door_sliding),
                            const Divider(height: 10),
                            _row('Type', r['houseType'] ?? '—', Icons.home),
                            const Divider(height: 10),
                            _row('Occupants', '${r['occupants']}', Icons.people),
                            const Divider(height: 10),
                            _row('Phone', r['phoneNumber'] ?? '—', Icons.phone_outlined),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Summary banners
                if (_parsedRecords.any((r) => r['unmatchedAddress'] == true)) ...[
                  const SizedBox(height: 8),
                  _banner(
                    '${_parsedRecords.where((r) => r['unmatchedAddress'] == true).length} address(es) not found in preloaded data — will not be saved',
                    Colors.red,
                    Icons.error_outline,
                  ),
                ],
                if (_parsedRecords.any((r) => r['matched'] == true)) ...[
                  const SizedBox(height: 8),
                  _banner(
                    'Some addresses were fuzzy-matched to existing database addresses.',
                    Colors.orange,
                    Icons.warning_amber,
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveRecords,
                    icon: const Icon(Icons.save),
                    label: Text(
                      'Save ${_parsedRecords.length} Record${_parsedRecords.length == 1 ? "" : "s"}',
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
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    IconData icon, {
    bool warning = false,
    String? subtitle,
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
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      color: warning ? Colors.orange.shade700 : Colors.black87,
                      fontWeight: FontWeight.w500)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade600,
                        fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        if (warning)
          Icon(Icons.info_outline, size: 15, color: Colors.orange.shade700),
      ],
    );
  }

  Widget _banner(String text, MaterialColor color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color.shade700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Address Search Dialog
// ============================================================================

class _AddressSearchDialog extends StatefulWidget {
  final String initialSearch;

  const _AddressSearchDialog({required this.initialSearch});

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAddresses = DatabaseService.getAllResidents()
        .map((r) => r.houseAddress)
        .toSet()
        .toList();

    final filtered = allAddresses
        .where((addr) =>
            addr.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Search for Address'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Type to search addresses...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Start typing to search...'
                            : 'No addresses found',
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final addr = filtered[index];
                        return ListTile(
                          title: Text(addr),
                          onTap: () {
                            Navigator.pop(context, addr);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
