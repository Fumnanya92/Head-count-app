import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/resident.dart';
import '../services/database_service.dart';
import 'resident_detail_screen.dart' show kHouseTypes;

class AddHouseScreen extends StatefulWidget {
  const AddHouseScreen({super.key});

  @override
  State<AddHouseScreen> createState() => _AddHouseScreenState();
}

class _AddHouseScreenState extends State<AddHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _zoneController = TextEditingController();
  final _totalFlatsController = TextEditingController();
  final _unitFlatController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  String? _houseType;
  String? _selectedAvatarPath;
  XFile? _selectedImageFile;
  List<String> _existingFlats = [];
  bool _useFlatDropdown = true;
  List<String> _allAddresses = [];

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    _loadAllAddresses();
  }

  void _loadAllAddresses() {
    final residents = DatabaseService.getAllResidents();
    final uniqueAddresses = residents.map((r) => r.houseAddress).toSet().toList();
    uniqueAddresses.sort();
    setState(() {
      _allAddresses = uniqueAddresses;
    });
  }

  void _onAddressChanged() {
    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      final flats = DatabaseService.getExistingFlatsForAddress(address);
      setState(() {
        _existingFlats = flats;
      });
    } else {
      setState(() {
        _existingFlats = [];
      });
    }
  }

  void _duplicateAddressData(String address) {
    final template = DatabaseService.getAddressTemplate(address);
    if (template != null) {
      setState(() {
        _addressController.text = template.houseAddress;
        _zoneController.text = template.zoneBlock ?? '';
        _totalFlatsController.text = template.totalFlatsInCompound?.toString() ?? '';
        _houseType = template.houseType;
        _unitFlatController.clear();
        _selectedImageFile = null;
        _selectedAvatarPath = null;
        _onAddressChanged();
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        // Copy to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File savedImage = await File(image.path).copy(
          '${appDir.path}/$fileName',
        );

        setState(() {
          _selectedImageFile = image;
          _selectedAvatarPath = savedImage.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveHouse() async {
    if (!_formKey.currentState!.validate()) return;

    final address = _addressController.text.trim();
    final flatNumber = _unitFlatController.text.trim();

    // Check for duplicate flat number
    if (flatNumber.isNotEmpty && _existingFlats.contains(flatNumber)) {
      final result = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Duplicate Flat Number ⚠️'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flat $flatNumber already exists at "$address".\n\nWould you like to continue anyway?',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Note: This will NOT overwrite the existing entry. It will just add a new record.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
                child: const Text('Continue Anyway', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (result != true) return;
    }

    try {
      final newResident = Resident(
        id: 0, // Auto-assigned
        houseAddress: address,
        zoneBlock: _zoneController.text.trim(),
        houseType: _houseType,
        unitFlat: flatNumber,
        totalFlatsInCompound: int.tryParse(_totalFlatsController.text.trim()),
        occupancyStatus: 'No', // Default vacant
        householdsCount: 0,
        adults: 0,
        children: 0,
        totalHeadcount: 0,
        dataSource: 'Field Added',
        verificationStatus: 'Unverified',
        isModified: true,
        avatarImagePath: _selectedAvatarPath,
      );

      final newId = await DatabaseService.addResident(newResident);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('House #$flatNumber added successfully (ID: $newId)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add house: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _zoneController.dispose();
    _totalFlatsController.dispose();
    _unitFlatController.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, {String? hint, String? helperText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add New House'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveHouse,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ═══ IMAGE UPLOAD SECTION ═══
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.image, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'House Avatar (Photo)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Center(
                        child: Column(
                          children: [
                            if (_selectedAvatarPath != null || _selectedImageFile != null)
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue, width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_selectedAvatarPath ?? _selectedImageFile!.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                            if (_selectedImageFile != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImageFile = null;
                                      _selectedAvatarPath = null;
                                    });
                                  },
                                  child: const Text('Remove Photo'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ═══ HOUSE INFORMATION SECTION ═══
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.home, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'House Information',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      
                      // Address field with duplication option
                      TextFormField(
                        controller: _addressController,
                        decoration: _inputDeco(
                          'House Address *',
                          hint: 'e.g., 4, FAMUYIWA Obodo St.',
                        ),
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                        maxLines: 2,
                      ),
                      
                      // Show duplicate option if address exists
                      if (_allAddresses.contains(_addressController.text.trim()) && _addressController.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This address already exists.',
                                    style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _duplicateAddressData(_addressController.text.trim()),
                                  child: const Text('Copy Fields'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _zoneController,
                        decoration: _inputDeco(
                          'Zone / Block / Compound',
                          hint: "e.g., IBE'S COMPOUND",
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _totalFlatsController,
                              decoration: _inputDeco(
                                'Total Flats in Compound',
                                hint: 'e.g. 12',
                                helperText: 'Ask compound caretaker',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _houseType,
                              decoration: _inputDeco('House Type'),
                              isExpanded: true,
                              items: kHouseTypes
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) => setState(() => _houseType = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Flat number section with dropdown or manual input
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Unit / Flat No. *',
                                  style: Theme.of(context).inputDecorationTheme.labelStyle,
                                ),
                              ),
                              if (_existingFlats.isNotEmpty)
                                Tooltip(
                                  message: 'Toggle between dropdown and manual input',
                                  child: IconButton(
                                    icon: Icon(
                                      _useFlatDropdown ? Icons.edit : Icons.list,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _useFlatDropdown = !_useFlatDropdown;
                                        if (_useFlatDropdown) {
                                          _unitFlatController.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                          if (_useFlatDropdown && _existingFlats.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  decoration: _inputDeco(
                                    'Select Flat',
                                    helperText: 'Existing flats at this address',
                                  ),
                                  items: _existingFlats
                                      .map((flat) => DropdownMenuItem(
                                            value: flat,
                                            child: Text('Flat $flat'),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _unitFlatController.text = value;
                                      });
                                    }
                                  },
                                  validator: (v) => _unitFlatController.text.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Or type new flat number below:',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          TextFormField(
                            controller: _unitFlatController,
                            decoration: _inputDeco(
                              'Flat Number',
                              hint: 'e.g. B2, Apt 5, 3rd Floor',
                            ),
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Flat number required' : null,
                          ),
                          if (_existingFlats.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  border: Border.all(color: Colors.purple.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.purple.shade700, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Existing flats at this address:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      children: _existingFlats
                                          .map((flat) => Chip(
                                            label: Text(flat, style: const TextStyle(fontSize: 12)),
                                            backgroundColor: Colors.purple.shade200,
                                            deleteIcon: null,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ═══ INFO BOX ═══
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'House will be marked Vacant by default. You can update occupancy details later.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ═══ SAVE BUTTON ═══
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveHouse,
                  icon: const Icon(Icons.add_home),
                  label: const Text('ADD HOUSE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
