import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/resident.dart';
import '../services/database_service.dart';

// Standardised house type options matching the final Excel sheet
const List<String> kHouseTypes = [
  '1 room',
  'Mini flat',
  '1 bedroom',
  '2 bedroom',
  '3 bedroom',
  '4 bedroom',
  '4 bedroom terrace',
  '5 bedroom',
  'Bungalow',
  'Duplex',
];

class ResidentDetailScreen extends ConsumerStatefulWidget {
  final int residentId;

  const ResidentDetailScreen({super.key, required this.residentId});

  @override
  ConsumerState<ResidentDetailScreen> createState() =>
      _ResidentDetailScreenState();
}

class _ResidentDetailScreenState extends ConsumerState<ResidentDetailScreen> {
  late Resident _resident;
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  String? _selectedAvatarPath;

  // Controllers
  late TextEditingController _addressController;
  late TextEditingController _zoneController;
  late TextEditingController _totalFlatsController;
  late TextEditingController _unitFlatController;
  late TextEditingController _householdsController;
  late TextEditingController _adultsController;
  late TextEditingController _childrenController;
  late TextEditingController _contactNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late TextEditingController _monthlyDueController;

  // Dropdown state
  String _occupancyStatus = 'No';
  String? _houseType;
  String? _contactRole;
  String? _phoneType;
  String? _appRegistered;
  String? _followUpNeeded;
  String? _verificationStatus;
  bool _whatsappSameAsPhone = true;
  late TextEditingController _whatsappController;
  DateTime? _followUpDate;

  String? _normalizeToOptions(String? value, List<String> options) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    for (final option in options) {
      if (option.toLowerCase() == trimmed.toLowerCase()) {
        return option;
      }
    }
    return null;
  }

  String _normalizeOccupancy(String? value) {
    final raw = value?.trim().toLowerCase() ?? '';
    if (raw == 'yes' || raw == 'occupied' || raw == 'y' || raw == 'true') {
      return 'Yes';
    }
    return 'No';
  }

  @override
  void initState() {
    super.initState();
    _loadResident();
  }

  void _loadResident() {
    final resident = DatabaseService.getResident(widget.residentId);
    if (resident == null) {
      Navigator.pop(context);
      return;
    }

    _resident = resident;

    _selectedAvatarPath = _resident.avatarImagePath;

    _addressController = TextEditingController(text: _resident.houseAddress);
    _zoneController = TextEditingController(text: _resident.zoneBlock ?? '');
    _totalFlatsController = TextEditingController(
        text: _resident.totalFlatsInCompound?.toString() ?? '');
    _unitFlatController = TextEditingController(text: _resident.unitFlat ?? '');
    _householdsController =
        TextEditingController(text: _resident.householdsCount.toString());
    _adultsController = TextEditingController(text: _resident.adults.toString());
    _childrenController =
        TextEditingController(text: _resident.children.toString());
    _contactNameController =
        TextEditingController(text: _resident.mainContactName ?? '');
    _phoneController = TextEditingController(text: _resident.phoneNumber ?? '');
    _whatsappController =
        TextEditingController(text: _resident.whatsappNumber ?? '');
    _emailController = TextEditingController(text: _resident.email ?? '');
    _notesController = TextEditingController(text: _resident.notes ?? '');
    _monthlyDueController =
        TextEditingController(text: _resident.monthlyDue > 0 ? _resident.monthlyDue.toString() : '');

    _occupancyStatus = _normalizeOccupancy(_resident.occupancyStatus);
    _houseType = _normalizeToOptions(_resident.houseType, kHouseTypes);
    _contactRole = _normalizeToOptions(
      _resident.contactRole,
      const ['Owner', 'Tenant', 'Caretaker'],
    );
    _phoneType = _normalizeToOptions(
      _resident.phoneType,
      const ['Android', 'iPhone', 'Other'],
    );
    _appRegistered = _normalizeToOptions(
      _resident.appRegistered,
      const ['Yes', 'No'],
    );
    _followUpNeeded = _normalizeToOptions(
      _resident.followUpNeeded,
      const ['Yes', 'No'],
    );
    _verificationStatus = _normalizeToOptions(
          _resident.verificationStatus,
          const ['Unverified', 'Verified'],
        ) ??
        'Unverified';

    if (_resident.followUpDate != null && _resident.followUpDate!.isNotEmpty) {
      try {
        _followUpDate = DateTime.parse(_resident.followUpDate!);
      } catch (_) {}
    }

    _whatsappSameAsPhone = _resident.whatsappNumber == null ||
        _resident.whatsappNumber!.isEmpty ||
        _resident.whatsappNumber == _resident.phoneNumber;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _zoneController.dispose();
    _totalFlatsController.dispose();
    _unitFlatController.dispose();
    _householdsController.dispose();
    _adultsController.dispose();
    _childrenController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _monthlyDueController.dispose();
    super.dispose();
  }

  int get _totalHeadcount {
    final adults = int.tryParse(_adultsController.text) ?? 0;
    final children = int.tryParse(_childrenController.text) ?? 0;
    return adults + children;
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
          _selectedAvatarPath = savedImage.path;
          _resident.avatarImagePath = savedImage.path;
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

  Future<void> _saveResident({bool saveAndNext = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final wasVerified = _resident.isVerified;

    _resident.houseAddress = _addressController.text.trim();
    _resident.zoneBlock = _zoneController.text.trim();
    _resident.totalFlatsInCompound =
        int.tryParse(_totalFlatsController.text.trim());
    _resident.unitFlat = _unitFlatController.text.trim();
    _resident.occupancyStatus = _occupancyStatus;
    _resident.avatarImagePath = _selectedAvatarPath;
    // Keep recordStatus in sync with occupancy
    _resident.recordStatus = _resident.isOccupied ? 'Occupied' : 'Vacant';
    _resident.houseType = _houseType;
    _resident.householdsCount = int.tryParse(_householdsController.text) ?? 0;
    _resident.monthlyDue = int.tryParse(_monthlyDueController.text) ?? 0;
    _resident.adults = int.tryParse(_adultsController.text) ?? 0;
    _resident.children = int.tryParse(_childrenController.text) ?? 0;
    _resident.calculateTotalHeadcount();
    _resident.mainContactName = _contactNameController.text.trim();
    _resident.contactRole = _contactRole;
    _resident.phoneNumber = _phoneController.text.trim();
    _resident.whatsappNumber = _whatsappSameAsPhone
        ? _phoneController.text.trim()
        : _whatsappController.text.trim();
    _resident.email = _emailController.text.trim();
    _resident.phoneType = _phoneType;
    _resident.appRegistered = _appRegistered;
    _resident.notes = _notesController.text.trim();
    _resident.followUpNeeded = _followUpNeeded;
    _resident.followUpDate =
        _followUpDate != null ? DateFormat('yyyy-MM-dd').format(_followUpDate!) : null;
    _resident.verificationStatus = _verificationStatus;
    _resident.visitDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _resident.visitedBy = 'Field Agent';

    // Auto-set firstVerifiedDate the first time a record is verified
    if (!wasVerified && _verificationStatus == 'Verified') {
      _resident.firstVerifiedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // Clear headcount data for vacant units
    if (!_resident.isOccupied) {
      _resident.adults = 0;
      _resident.children = 0;
      _resident.totalHeadcount = 0;
      _resident.householdsCount = 0;
    }

    await DatabaseService.saveResident(_resident);

    // Propagate totalFlatsInCompound to all other flats at the same address
    final totalFlats = _resident.totalFlatsInCompound;
    if (totalFlats != null && totalFlats > 0) {
      await DatabaseService.propagateCompoundData(
          _resident.houseAddress, totalFlats);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saveAndNext ? 'Saved! Moving to next...' : 'Saved successfully'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    if (saveAndNext) {
      final allResidents = DatabaseService.getAllResidents()
        ..sort((a, b) => a.id.compareTo(b.id));
      final currentIndex = allResidents.indexWhere((r) => r.id == _resident.id);
      if (currentIndex >= 0 && currentIndex < allResidents.length - 1) {
        final nextResident = allResidents[currentIndex + 1];
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResidentDetailScreen(residentId: nextResident.id),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _callPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number entered')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cannot make call')));
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number entered')),
      );
      return;
    }
    String formatted = phone;
    if (phone.startsWith('0')) {
      formatted = '234${phone.substring(1)}';
    } else if (!phone.startsWith('234')) {
      formatted = '234$phone';
    }
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cannot open WhatsApp')));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Delete "${_resident.houseAddress}"\n(Unit: ${_resident.unitFlat ?? "—"})\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.deleteResident(_resident.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record deleted'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context, true); // signal list to refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('House Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('ID: ${_resident.id}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_phoneController.text.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: _callPhone,
              tooltip: 'Call',
            ),
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: _openWhatsApp,
              tooltip: 'WhatsApp',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
            tooltip: 'Delete record',
            color: Colors.white,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
            // ── Avatar Section ─────────────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 2),
                        color: Colors.grey.shade100,
                      ),
                      child: _selectedAvatarPath != null && 
                             _selectedAvatarPath!.isNotEmpty &&
                             File(_selectedAvatarPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(_selectedAvatarPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 50,
                                      color: Colors.grey.shade400,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 50,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Update Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    if (_selectedAvatarPath != null && _selectedAvatarPath!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedAvatarPath = null;
                              _resident.avatarImagePath = null;
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

            // ── Section A: House Information ──────────────────────────────
            _SectionCard(
              icon: Icons.home,
              title: 'House Information',
              children: [
                _field(
                  controller: _addressController,
                  label: 'House Address *',
                  maxLines: 2,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                _field(
                    controller: _zoneController, label: 'Zone / Block / Compound'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _field(
                        controller: _totalFlatsController,
                        label: 'Total Flats in Compound',
                        hint: 'e.g. 12',
                        keyboardType: TextInputType.number,
                        helperText: 'Ask the compound caretaker',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _field(
                          controller: _unitFlatController,
                          label: 'Unit / Flat No.',
                          hint: 'e.g. B2'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _houseType,
                  decoration: _inputDeco('House Type'),
                  isExpanded: true,
                  items: kHouseTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _houseType = v),
                ),
                const SizedBox(height: 4),
                _field(
                  controller: _monthlyDueController,
                  label: 'Monthly Due (₦)',
                  hint: 'e.g. 1500',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section B: Occupancy & Headcount ─────────────────────────
            _SectionCard(
              icon: Icons.people,
              title: 'Occupancy & Headcount',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _occupancyStatus,
                  decoration: _inputDeco('Occupancy Status *'),
                  items: const [
                    DropdownMenuItem(value: 'Yes', child: Text('Occupied')),
                    DropdownMenuItem(value: 'No', child: Text('Vacant')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _occupancyStatus = v!;
                      if (v == 'No') {
                        _adultsController.text = '0';
                        _childrenController.text = '0';
                        _householdsController.text = '0';
                      }
                    });
                  },
                ),
                if (_occupancyStatus == 'Yes') ...[
                  const SizedBox(height: 12),
                  _field(
                    controller: _householdsController,
                    label: '# Households',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _adultsController,
                          label: 'Adults',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _childrenController,
                          label: 'Children',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people,
                                color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Text('Total Headcount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onPrimaryContainer,
                                )),
                          ],
                        ),
                        Text(
                          _totalHeadcount.toString(),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Section C: Contact Information ────────────────────────────
            _SectionCard(
              icon: Icons.contact_phone,
              title: 'Contact Information',
              children: [
                _field(
                    controller: _contactNameController,
                    label: 'Main Contact Name'),
                DropdownButtonFormField<String>(
                  initialValue: _contactRole,
                  decoration: _inputDeco('Contact Role'),
                  items: ['Owner', 'Tenant', 'Caretaker']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _contactRole = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: _inputDeco('Phone Number', hint: '08012345678 or +234...'),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final trimmed = v.trim();
                    // Accept 080... + 9 digits = 11 total
                    if (trimmed.startsWith('0') && trimmed.length == 11) {
                      return null;
                    }
                    // Accept +234 + 10 digits = 13 total
                    if (trimmed.startsWith('+234') && trimmed.length == 13) {
                      return null;
                    }
                    // Accept 234 + 10 digits = 13 total
                    if (trimmed.startsWith('234') && trimmed.length == 13) {
                      return null;
                    }
                    return 'Phone: 080... (11 digits) or +234... (13 chars)';
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('WhatsApp same as phone'),
                  value: _whatsappSameAsPhone,
                  onChanged: (v) => setState(() => _whatsappSameAsPhone = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (!_whatsappSameAsPhone) ...[
                  const SizedBox(height: 8),
                  _field(
                    controller: _whatsappController,
                    label: 'WhatsApp Number',
                    hint: '08012345678',
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 12),
                _field(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'example@mail.com',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _phoneType,
                  decoration: _inputDeco('Phone Type'),
                  items: ['Android', 'iPhone', 'Other']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _phoneType = v),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section D: App Registration ───────────────────────────────
            _SectionCard(
              icon: Icons.app_registration,
              title: 'App Registration',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _appRegistered,
                  decoration: _inputDeco('Registered on AccessCode app?'),
                  items: const [
                    DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                    DropdownMenuItem(value: 'No', child: Text('No')),
                  ],
                  onChanged: (v) => setState(() => _appRegistered = v),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section E: Notes & Follow-up ──────────────────────────────
            _SectionCard(
              icon: Icons.note_alt,
              title: 'Notes & Follow-up',
              children: [
                _field(
                  controller: _notesController,
                  label: 'Notes / Issues',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _followUpNeeded,
                  decoration: _inputDeco('Follow-up Needed?'),
                  items: const [
                    DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                    DropdownMenuItem(value: 'No', child: Text('No')),
                  ],
                  onChanged: (v) => setState(() => _followUpNeeded = v),
                ),
                if (_followUpNeeded == 'Yes') ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _followUpDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _followUpDate = date);
                    },
                    child: InputDecorator(
                      decoration: _inputDeco('Follow-up Date'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _followUpDate == null
                                ? 'Tap to select date'
                                : DateFormat('d MMM yyyy').format(_followUpDate!),
                            style: TextStyle(
                              color: _followUpDate == null
                                  ? Colors.grey.shade500
                                  : Colors.black87,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Section F: Data & Verification ───────────────────────────
            _SectionCard(
              icon: Icons.verified_user,
              title: 'Data & Verification',
              children: [
                // Data Source — display only
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Data Source',
                          style: TextStyle(color: Colors.grey.shade600)),
                      _SourceBadge(_resident.dataSource ?? 'Preloaded'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _verificationStatus,
                  decoration: _inputDeco('Verification Status'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Unverified', child: Text('Unverified')),
                    DropdownMenuItem(value: 'Verified', child: Text('Verified')),
                  ],
                  onChanged: (v) => setState(() => _verificationStatus = v),
                ),
                if (_resident.firstVerifiedDate != null &&
                    _resident.firstVerifiedDate!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'First Verified',
                    value: _resident.firstVerifiedDate!,
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                  ),
                ],
                if (_resident.visitDate != null &&
                    _resident.visitDate!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Last Visit',
                    value: _resident.visitDate!,
                    icon: Icons.event,
                    iconColor: Colors.blue,
                  ),
                ],
                if (_resident.lastUpdatedBy != null &&
                    _resident.lastUpdatedBy!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Last Updated By',
                    value: _resident.lastUpdatedBy!,
                    icon: Icons.person_outline,
                    iconColor: Colors.grey,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveResident(),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save',
                      style: TextStyle(fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _saveResident(saveAndNext: true),
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Next',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  InputDecoration _inputDeco(String label,
      {String? hint, String? helperText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      border: const OutlineInputBorder(),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    int maxLines = 1,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      children: [
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          decoration: _inputDeco(label, hint: hint, helperText: helperText),
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge(this.source);

  @override
  Widget build(BuildContext context) {
    final isFieldAdded = source == 'Field Added';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFieldAdded ? Colors.orange.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        source,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isFieldAdded ? Colors.orange.shade800 : Colors.blue.shade800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
