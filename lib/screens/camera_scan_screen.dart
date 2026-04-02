import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import '../models/resident.dart';
import '../services/database_service.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final textRecognizer = TextRecognizer();
  
  bool _isProcessing = false;
  String? _scannedText;
  Map<String, dynamic>? _parsedRecord;
  File? _selectedImage;
  String? _errorMessage;

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
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

  double _calculateSimilarity(String str1, String str2) {
    str1 = str1.toLowerCase().trim();
    str2 = str2.toLowerCase().trim();

    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    if (str1.contains(str2) || str2.contains(str1)) {
      return 0.8;
    }

    int longer = str1.length > str2.length ? str1.length : str2.length;
    if (longer == 0) return 1.0;

    int distance = _levenshteinDistance(str1, str2);
    return (longer - distance) / longer;
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.length < s2.length) {
      return _levenshteinDistance(s2, s1);
    }
    if (s2.isEmpty) return s1.length;

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
        int substitutions = previous[j - 1] + (s1[i - 1] == s2[j - 1] ? 0 : 1);
        current[j] = [insertions, deletions, substitutions].reduce((a, b) => a < b ? a : b);
      }
      List<int> temp = previous;
      previous = current;
      current = temp;
    }
    return previous[s2.length];
  }

  String? _findBestMatchingAddress(String inputAddress) {
    if (inputAddress.trim().isEmpty) return null;

    final allResidents = DatabaseService.getAllResidents();
    final uniqueAddresses = allResidents.map((r) => r.houseAddress).toSet().toList();

    String? bestMatch;
    double bestScore = 0.85; // Require 85%+ similarity to match

    for (final address in uniqueAddresses) {
      final score = _calculateSimilarity(inputAddress, address);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = address;
      }
    }

    return bestMatch;
  }
  Future<void> _captureFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gallery error: $e');
    }
  }

  /// Process image with OCR
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _selectedImage = imageFile;
    });

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text;
      debugPrint('OCR Extracted text:\n$extractedText');

      if (extractedText.isEmpty) {
        setState(() {
          _errorMessage = 'No text detected in image. Please ensure the text is clear.';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _scannedText = extractedText;
      });

      // Parse the extracted text using the same logic as bulk import
      _parseScannedText(extractedText);
    } catch (e) {
      setState(() {
        _errorMessage = 'OCR processing error: $e';
        _isProcessing = false;
      });
      debugPrint('Error during OCR: $e');
    }
  }

  /// Parse scanned text using same logic as bulk import
  void _parseScannedText(String text) {
    try {
      final lines = text.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      String? name;
      String? address;
      String? flatNumber;
      String? houseType;
      int? occupants;
      String? phoneNumber;
      
      Set<int> processedLines = {};

      // First pass: Look for explicitly labeled fields
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Extract explicitly labeled fields
        if (_matchesPattern(line, ['name'])) {
          name = _extractValue(line);
          processedLines.add(i);
        } else if (_matchesPattern(line, ['address', 'street', 'ave', 'road'])) {
          address = _extractValue(line);
          processedLines.add(i);
        } else if (_matchesPattern(line, ['flat', 'flat number', 'unit'])) {
          final value = _extractValue(line);
          if (value != null && !value.toLowerCase().contains('bedroom')) {
            flatNumber = value;
            processedLines.add(i);
          }
        } else if (_matchesPattern(line, ['type', 'house type'])) {
          final value = _extractValue(line);
          if (value != null) {
            houseType = value;
            processedLines.add(i);
          }
        } else if (_matchesPattern(line, ['occ', 'occupant', 'occupants', 'persons'])) {
          final value = _extractValue(line);
          if (value != null) {
            occupants = _parseOccupants(value);
            processedLines.add(i);
          }
        } else if (_matchesPattern(line, ['phone', 'tel', 'contact', 'mobile'])) {
          final value = _extractValue(line);
          if (value != null && _isValidPhoneNumber(value)) {
            phoneNumber = _normalizePhoneNumber(value);
            processedLines.add(i);
          }
        }
      }

      // Second pass: Smart detection for unlabeled fields
      for (int i = 0; i < lines.length; i++) {
        if (processedLines.contains(i)) continue;
        
        final line = lines[i];

        // Smart name detection
        if (name == null &&
            !_looksLikeAddress(line) &&
            !_looksLikeFlat(line) &&
            !_looksLikeHouseType(line) &&
            !_looksLikeOccupants(line) &&
            !_isValidPhoneNumber(line)) {
          name = line;
          processedLines.add(i);
        }
        // Smart flat detection
        else if (flatNumber == null && _looksLikeFlat(line)) {
          final value = _extractValue(line);
          if (value != null) {
            flatNumber = _extractFlatNumber(value);
            processedLines.add(i);
          }
        }
        // Smart house type detection
        else if (houseType == null && _looksLikeHouseType(line)) {
          houseType = line;
          processedLines.add(i);
        }
        // Smart occupants detection
        else if (occupants == null && _looksLikeOccupants(line)) {
          occupants = _parseOccupants(line);
          processedLines.add(i);
        }
        // Phone number detection
        else if (phoneNumber == null && _isValidPhoneNumber(line)) {
          phoneNumber = _normalizePhoneNumber(line);
          processedLines.add(i);
        }
        // Smart address detection: Catch-all for remaining lines
        else if (address == null) {
          address = line;
          processedLines.add(i);
          // Collect following lines
          int j = i + 1;
          while (j < lines.length && 
                 !_looksLikeFlat(lines[j]) &&
                 !_looksLikeHouseType(lines[j]) &&
                 !_looksLikeOccupants(lines[j]) &&
                 !_matchesPattern(lines[j], ['occupant', 'phone', 'name']) &&
                 !_isValidPhoneNumber(lines[j])) {
            address = '$address, ${lines[j]}';
            processedLines.add(j);
            j++;
          }
        }
      }

      // Try to find matching address
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

      final parsed = {
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

      setState(() {
        _parsedRecord = parsed;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Parsing error: $e';
        _isProcessing = false;
      });
    }
  }

  /// Check if line looks like an address
  bool _looksLikeAddress(String line) {
    final lowerLine = line.toLowerCase();
    final addressKeywords = [
      'address', 'no.', 'no ', 'street', 'avenue', 'ave', 'close', 'road',
      'estate', 'house', 'apartment', 'apt', 'floor', 'building', 'complex'
    ];
    return addressKeywords.any((keyword) => lowerLine.contains(keyword));
  }

  /// Check if line looks like flat/unit
  bool _looksLikeFlat(String line) {
    final lowerLine = line.toLowerCase();
    return (lowerLine.contains('flat') || 
            lowerLine.contains('unit') || 
            lowerLine.contains('apt')) &&
        !lowerLine.contains('bedroom') &&
        !lowerLine.contains('room');
  }

  /// Check if line looks like house type
  bool _looksLikeHouseType(String line) {
    return _matchesPattern(line, [
      'bedroom', 'room', 'duplex', 'bungalow', 'flat', 'studio',
      'self contain', 'miniflat', 'mini flat', 'apartment', 'penthouse',
      '1 room', '2 room', '3 room'
    ]);
  }

  /// Check if line looks like occupants
  bool _looksLikeOccupants(String line) {
    final lowerLine = line.toLowerCase();
    // Just a number or starts with number
    if (RegExp(r'^\d+').hasMatch(line.trim())) {
      // If it's JUST a number
      if (RegExp(r'^\d+$').hasMatch(line.trim())) return true;
      // "2occupants", "3people" (no spaces)
      if (RegExp(r'^\d+(occupant|person|people)').hasMatch(lowerLine)) return true;
    }
    const occupantWords = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];
    if (occupantWords.contains(lowerLine)) return true;
    // "2 occupants", etc (with spaces)
    if (RegExp(r'^\d+\s+(occupant|person|people)').hasMatch(lowerLine)) return true;
    return false;
  }

  /// Parse occupants from various formats
  int? _parseOccupants(String text) {
    final numberMatch = RegExp(r'\d+').firstMatch(text);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(0)!);
    }

    final occupantWords = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    };

    final lowText = text.toLowerCase();
    for (final entry in occupantWords.entries) {
      if (lowText.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  bool _isValidPhoneNumber(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
    final digitCount = cleaned.replaceAll('+', '').length;
    return digitCount >= 10 && RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(text);
  }

  String _normalizePhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+234')) {
      return cleaned;
    }

    if (cleaned.startsWith('0')) {
      return '+234${cleaned.substring(1)}';
    }

    if (cleaned.startsWith('234')) {
      return '+$cleaned';
    }

    return cleaned;
  }

  bool _matchesPattern(String line, List<String> keywords) {
    final lowerLine = line.toLowerCase();
    for (final keyword in keywords) {
      if (lowerLine.contains(keyword)) {
        return true;
      }
    }
    return false;
  }



  String? _extractValue(String line) {
    final patterns = ['...', '..', '::', ':', '-', '.', ',', '='];
    for (final pattern in patterns) {
      if (line.contains(pattern)) {
        final parts = line.split(pattern);
        if (parts.length > 1) {
          String value = parts.sublist(1).join(pattern).trim();
          // Clean up extra spaces from separators like " - "
          value = value.replaceAll(RegExp(r'^\s*[-:]\s*'), '').trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return line.isNotEmpty ? line : null;
  }

  /// Extract flat number from strings like "Flat 10", "flat 3", "108", etc.
  String _extractFlatNumber(String value) {
    value = value.trim();
    // If it starts with "flat" or "unit", extract just the number part
    if (value.toLowerCase().startsWith('flat') || 
        value.toLowerCase().startsWith('unit') || 
        value.toLowerCase().startsWith('apt')) {
      final match = RegExp(r'[\d]+').firstMatch(value);
      if (match != null) {
        return match.group(0)!;
      }
    }
    // Otherwise return as-is (might be just a number like "10" or "108")
    return value;
  }

  /// Save the scanned record
  Future<void> _saveRecord() async {
    if (_parsedRecord == null) return;

    try {
      final address = _parsedRecord!['address'];
      if ((address ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _parsedRecord!['unmatchedAddress'] == true
                  ? 'Address does not match any preloaded units. Please verify the address.'
                  : 'Address is required',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      debugPrint('📸 [CameraScan] Creating resident object from parsed data...');
      final resident = Resident(
        id: 0,
        houseAddress: address,
        zoneBlock: _parsedRecord!['zoneBlock'],
        unitFlat: _parsedRecord!['flatNumber'],
        houseType: _parsedRecord!['houseType'],
        occupancyStatus: 'Yes',
        householdsCount: 1,
        monthlyDue: 0,
        adults: _parsedRecord!['occupants'] ?? 0,
        children: 0,
        mainContactName: _parsedRecord!['name'],
        phoneNumber: _parsedRecord!['phoneNumber'],
        whatsappNumber: _parsedRecord!['phoneNumber'],
        dataSource: 'Camera Scan',
        verificationStatus: 'Verified',
        isModified: true,
        totalFlatsInCompound: _parsedRecord!['totalFlatsInCompound'],
      );

      debugPrint('📸 [CameraScan] Resident object created. Calling DatabaseService.addResident....');
      debugPrint('📸 [CameraScan] Resident data: name=${resident.mainContactName}, address=$address, flat=${resident.unitFlat}');
      
      final savedId = await DatabaseService.addResident(resident);
      debugPrint('📸 [CameraScan] ✅ Resident saved with ID: $savedId');

      // Verify it was actually saved
      final verifyResident = DatabaseService.getResident(savedId);
      if (verifyResident != null) {
        debugPrint('📸 [CameraScan] ✅ Verification: Resident #$savedId retrieved from database successfully');
      } else {
        debugPrint('📸 [CameraScan] ⚠️ WARNING: Resident #$savedId not found in database after save!');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resident saved successfully (ID: $savedId)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Pop back to house_list_screen and trigger provider refresh
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e, stackTrace) {
      debugPrint('📸 [CameraScan] ❌ ERROR saving resident: $e');
      debugPrint('📸 [CameraScan] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
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
        title: const Text('Camera Scan'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (_selectedImage != null) ...[
              // Preview of scanned image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Error message
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Camera buttons
            if (_scannedText == null) ...[
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _captureFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture from Camera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFromGallery,
                icon: const Icon(Icons.image),
                label: const Text('Pick from Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_isProcessing)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text('Processing image with OCR...'),
                    ],
                  ),
                ),
            ],
            // Display scanned and parsed data
            if (_scannedText != null && _parsedRecord != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      if (_parsedRecord!['unmatchedAddress'] == true) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            border: Border.all(color: Colors.orange.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                          'Tried: ${_parsedRecord!['rawAddress']}',
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
                                            _parsedRecord!['rawAddress'] ?? '');
                                    if (selected != null) {
                                      setState(() {
                                        _parsedRecord!['address'] = selected;
                                        _parsedRecord!['unmatchedAddress'] = false;
                                        _parsedRecord!['matched'] = true;
                                        final data = _getAddressData(selected);
                                        if (data != null) {
                                          _parsedRecord!['addressData'] = data;
                                          _parsedRecord!['zoneBlock'] =
                                              data['zoneBlock'];
                                          _parsedRecord!['totalFlatsInCompound'] =
                                              data['totalFlatsInCompound'];
                                          if (_parsedRecord!['houseType'] ==
                                              null) {
                                            _parsedRecord!['houseType'] =
                                                data['houseType'];
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
                        const Divider(),
                      ],
                      _buildDetailRow('Name', _parsedRecord!['name']),
                      _buildDetailRow('Address', _parsedRecord!['address']),
                      if (_parsedRecord!['zoneBlock'] != null)
                        _buildDetailRow('Zone/Block', _parsedRecord!['zoneBlock']),
                      if (_parsedRecord!['totalFlatsInCompound'] != null)
                        _buildDetailRow('Total Flats', _parsedRecord!['totalFlatsInCompound']?.toString()),
                      _buildDetailRow('Flat Number', _parsedRecord!['flatNumber']),
                      _buildDetailRow('House Type', _parsedRecord!['houseType']),
                      _buildDetailRow('Occupants', _parsedRecord!['occupants']?.toString()),
                      _buildDetailRow('Phone', _parsedRecord!['phoneNumber']),
                      if (_parsedRecord!['matched'] == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '✓ Address matched to existing record',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saveRecord,
                icon: const Icon(Icons.save),
                label: const Text('Save Resident'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _scannedText = null;
                    _parsedRecord = null;
                    _selectedImage = null;
                  });
                },
                child: const Text('Scan Another'),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '—',
              style: TextStyle(
                color: value == null ? Colors.grey : Colors.black87,
              ),
            ),
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
