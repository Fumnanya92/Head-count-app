import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/resident.dart';

class QuickUpdateScreen extends StatefulWidget {
  final Resident resident;

  const QuickUpdateScreen({
    super.key,
    required this.resident,
  });

  @override
  State<QuickUpdateScreen> createState() => _QuickUpdateScreenState();
}

class _QuickUpdateScreenState extends State<QuickUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  
  // Essential fields only for door-to-door speed
  late String _occupancyStatus;
  late int _totalFlats;
  late int _households;
  late int _adults;
  late int _children;
  late String _mainContactName;
  late String _contactRole;
  late String _phoneNumber;
  late String _whatsappNumber;
  late String _notes;
  late bool _followUpNeeded;
  late bool _visited;
  late String? _avatarImagePath;
  
  int get _totalHeadcount => _adults + _children;
  bool get _isOccupied => _occupancyStatus.toLowerCase() == 'yes' || 
                         _occupancyStatus.toLowerCase() == 'occupied';

  @override
  void initState() {
    super.initState();
    _loadResidentData();
  }

  void _loadResidentData() {
    final resident = widget.resident;
    _occupancyStatus = resident.occupancyStatus;
    _totalFlats = resident.totalFlatsInCompound ?? 0;
    _households = resident.householdsCount;
    _adults = resident.adults;
    _children = resident.children;
    _mainContactName = resident.mainContactName ?? '';
    _contactRole = resident.contactRole ?? '';
    _phoneNumber = resident.phoneNumber ?? '';
    _whatsappNumber = resident.whatsappNumber ?? '';
    _notes = resident.notes ?? '';
    _followUpNeeded = resident.needsFollowUp;
    _visited = resident.visitDate != null && resident.visitDate!.isNotEmpty;
    _avatarImagePath = resident.avatarImagePath;
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
        final savedImage = await File(image.path).copy(
          '${appDir.path}/$fileName',
        );

        if (mounted) {
          setState(() {
            _avatarImagePath = savedImage.path;
            widget.resident.avatarImagePath = savedImage.path;
          });
        }
      }
    } on PlatformException catch (e) {
      String errorMessage = 'Error accessing camera: ';
      switch (e.code) {
        case 'camera_access_denied':
          errorMessage += 'Camera access denied. Please enable camera permission in Settings.';
          break;
        case 'camera_access_restricted':
          errorMessage += 'Camera access restricted.';
          break;
        case 'capture_cancelled':
          // User cancelled, no need to show error
          return;
        default:
          errorMessage += 'Unknown error occurred.';
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
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

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        // Copy to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(image.path).copy(
          '${appDir.path}/$fileName',
        );

        if (mounted) {
          setState(() {
            _avatarImagePath = savedImage.path;
            widget.resident.avatarImagePath = savedImage.path;
          });
        }
      }
    } on PlatformException catch (e) {
      String errorMessage = 'Error accessing gallery: ';
      switch (e.code) {
        case 'photo_access_denied':
          errorMessage += 'Gallery access denied. Please enable photo library permission in Settings.';
          break;
        case 'photo_access_restricted':
          errorMessage += 'Gallery access restricted.';
          break;
        case 'picker_cancelled':
          // User cancelled, no need to show error
          return;
        default:
          errorMessage += 'Unknown error occurred.';
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image from gallery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateOccupancyStatus(String status) {
    setState(() {
      _occupancyStatus = status;
      if (!_isOccupied) {
        // Auto-clear fields for vacant houses
        _adults = 0;
        _children = 0;
        _households = 0;
        _mainContactName = '';
        _contactRole = '';
        _phoneNumber = '';
        _whatsappNumber = '';
      }
    });
  }

  Future<void> _makeCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _saveAndFinish({bool moveToNext = false}) {
    if (!_formKey.currentState!.validate()) return;

    // Update the resident object
    widget.resident.occupancyStatus = _occupancyStatus;
    // Keep recordStatus in sync with occupancy
    widget.resident.recordStatus = _isOccupied ? 'Occupied' : 'Vacant';
    widget.resident.totalFlatsInCompound = _totalFlats > 0 ? _totalFlats : null;
    widget.resident.householdsCount = _households;
    widget.resident.adults = _adults;
    widget.resident.children = _children;
    widget.resident.totalHeadcount = _totalHeadcount;
    widget.resident.mainContactName = _mainContactName;
    widget.resident.contactRole = _contactRole;
    widget.resident.phoneNumber = _phoneNumber;
    widget.resident.whatsappNumber = _whatsappNumber;
    widget.resident.notes = _notes;
    widget.resident.followUpNeeded = _followUpNeeded ? 'Yes' : 'No';
    widget.resident.avatarImagePath = _avatarImagePath;
    widget.resident.visitDate = _visited ? DateTime.now().toString().split(' ')[0] : '';
    widget.resident.isModified = true;
    widget.resident.updatedAt = DateTime.now();

    // Save to database
    widget.resident.save();

    final message = moveToNext 
      ? 'House updated! Moving to next...'
      : 'House updated successfully';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Update'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => _saveAndFinish(),
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar Section ───────────────────────────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue, width: 2),
                          color: Colors.grey.shade100,
                        ),
                        child: _avatarImagePath != null && 
                               _avatarImagePath!.isNotEmpty &&
                               File(_avatarImagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_avatarImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 40,
                                        color: Colors.grey.shade400,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickImageFromGallery,
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (_avatarImagePath != null && _avatarImagePath!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _avatarImagePath = null;
                                widget.resident.avatarImagePath = null;
                              });
                            },
                            child: const Text('Remove Photo'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // House Address (Read-only)
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.home, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.resident.houseAddress,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.resident.zoneBlock ?? 'Unknown Zone'} • ${widget.resident.houseType ?? 'Unknown Type'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick Action Buttons
              Row(
                children: [
                  _buildQuickActionButton(
                    label: 'Occupied',
                    icon: Icons.home,
                    color: _isOccupied ? Colors.green : Colors.grey,
                    onPressed: () => _updateOccupancyStatus('Yes'),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionButton(
                    label: 'Vacant',
                    icon: Icons.home_outlined,
                    color: !_isOccupied ? Colors.orange : Colors.grey,
                    onPressed: () => _updateOccupancyStatus('No'),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionButton(
                    label: 'Visited',
                    icon: Icons.check_circle,
                    color: _visited ? Colors.blue : Colors.grey,
                    onPressed: () {
                      setState(() {
                        _visited = !_visited;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section A: Quick Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total flats in compound
                      TextFormField(
                        initialValue: _totalFlats > 0 ? _totalFlats.toString() : '',
                        decoration: const InputDecoration(
                          labelText: 'Total Flats in Compound',
                          hintText: 'Ask caretaker',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _totalFlats = int.tryParse(value) ?? 0;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Households
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _households.toString(),
                              decoration: const InputDecoration(
                                labelText: '# Households',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _households = int.tryParse(value) ?? 0;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Adults and Children
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _adults.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Adults',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _adults = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _children.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Children',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _children = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Auto-calculated Total
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Total Headcount: $_totalHeadcount people',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section B: Contact (Only if Occupied)
              if (_isOccupied) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Info',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Main Contact Name
                        TextFormField(
                          initialValue: _mainContactName,
                          decoration: const InputDecoration(
                            labelText: 'Main Contact Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            _mainContactName = value;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Contact Role
                        TextFormField(
                          initialValue: _contactRole,
                          decoration: const InputDecoration(
                            labelText: 'Contact Role (Owner/Tenant/Caretaker)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            _contactRole = value;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Phone Number
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                initialValue: _phoneNumber,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                                onChanged: (value) {
                                  _phoneNumber = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _makeCall(_phoneNumber),
                              icon: const Icon(Icons.call),
                              color: Colors.green,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // WhatsApp Number
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                initialValue: _whatsappNumber,
                                decoration: const InputDecoration(
                                  labelText: 'WhatsApp (optional)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                                onChanged: (value) {
                                  _whatsappNumber = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _openWhatsApp(_whatsappNumber),
                              icon: const Icon(Icons.chat),
                              color: Colors.green,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Section C: Notes
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes & Follow-up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        initialValue: _notes,
                        decoration: const InputDecoration(
                          labelText: 'Notes/Issues (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          _notes = value;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Follow-up needed
                      CheckboxListTile(
                        title: const Text('Follow-up Needed'),
                        subtitle: const Text('Mark if this house requires another visit'),
                        value: _followUpNeeded,
                        onChanged: (value) {
                          setState(() {
                            _followUpNeeded = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Save & Next Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _saveAndFinish(moveToNext: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SAVE & NEXT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}