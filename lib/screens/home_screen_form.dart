import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resident.dart';
import '../providers/resident_provider.dart';

class HomeScreenForm extends ConsumerStatefulWidget {
  const HomeScreenForm({super.key});

  @override
  ConsumerState<HomeScreenForm> createState() => _HomeScreenFormState();
}

class _HomeScreenFormState extends ConsumerState<HomeScreenForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields (matching actual CSV structure)
  final _houseAddressController = TextEditingController();
  final _zoneBlockController = TextEditingController();
  final _houseTypeController = TextEditingController();
  final _unitFlatController = TextEditingController();
  final _occupancyStatusController = TextEditingController();
  final _recordStatusController = TextEditingController();
  final _householdsCountController = TextEditingController();
  final _monthlyDueController = TextEditingController();
  final _paymentStatusController = TextEditingController();
  final _lastPaymentDateController = TextEditingController();
  final _adultsController = TextEditingController();
  final _childrenController = TextEditingController();
  final _totalHeadcountController = TextEditingController();
  final _mainContactNameController = TextEditingController();
  final _contactRoleController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _appRegisteredController = TextEditingController();
  final _phoneTypeController = TextEditingController();
  final _notesController = TextEditingController();
  final _visitDateController = TextEditingController();
  final _visitedByController = TextEditingController();
  final _dataVerifiedController = TextEditingController();
  final _followUpNeededController = TextEditingController();
  final _followUpDateController = TextEditingController();
  
  int? _selectedHouseId;
  Resident? _currentResident;
  List<Resident> _allResidents = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadResidents();
    });
  }

  void _loadResidents() {
    final residents = ref.read(residentsListProvider);
    setState(() {
      _allResidents = residents;
      if (_allResidents.isNotEmpty) {
        _currentIndex = 0;
        _loadResidentData(_allResidents[0]);
      }
    });
  }

  void _loadResidentData(Resident resident) {
    setState(() {
      _currentResident = resident;
      _selectedHouseId = resident.id;
    });
    
    // Populate all form fields with resident data
    _houseAddressController.text = resident.houseAddress;
    _zoneBlockController.text = resident.zoneBlock ?? '';
    _houseTypeController.text = resident.houseType ?? '';
    _unitFlatController.text = resident.unitFlat ?? '';
    _occupancyStatusController.text = resident.occupancyStatus;
    _recordStatusController.text = resident.recordStatus ?? '';
    _householdsCountController.text = resident.householdsCount.toString();
    _monthlyDueController.text = resident.monthlyDue.toString();
    _paymentStatusController.text = resident.paymentStatus ?? '';
    _lastPaymentDateController.text = resident.lastPaymentDate ?? '';
    _adultsController.text = resident.adults.toString();
    _childrenController.text = resident.children.toString();
    _totalHeadcountController.text = resident.totalHeadcount.toString();
    _mainContactNameController.text = resident.mainContactName ?? '';
    _contactRoleController.text = resident.contactRole ?? '';
    _phoneNumberController.text = resident.phoneNumber ?? '';
    _whatsappNumberController.text = resident.whatsappNumber ?? '';
    _emailController.text = resident.email ?? '';
    _appRegisteredController.text = resident.appRegistered ?? '';
    _phoneTypeController.text = resident.phoneType ?? '';
    _notesController.text = resident.notes ?? '';
    _visitDateController.text = resident.visitDate ?? '';
    _visitedByController.text = resident.visitedBy ?? '';
    _dataVerifiedController.text = resident.dataVerified ?? '';
    _followUpNeededController.text = resident.followUpNeeded ?? '';
    _followUpDateController.text = resident.followUpDate ?? '';
  }

  void _saveCurrentResident() {
    if (_currentResident == null) return;

    // Update the resident with form data
    _currentResident!.houseAddress = _houseAddressController.text;
    _currentResident!.zoneBlock = _zoneBlockController.text;
    _currentResident!.houseType = _houseTypeController.text;
    _currentResident!.unitFlat = _unitFlatController.text;
    _currentResident!.occupancyStatus = _occupancyStatusController.text;
    _currentResident!.recordStatus = _recordStatusController.text;
    _currentResident!.householdsCount = int.tryParse(_householdsCountController.text) ?? 0;
    _currentResident!.monthlyDue = int.tryParse(_monthlyDueController.text) ?? 0;
    _currentResident!.paymentStatus = _paymentStatusController.text;
    _currentResident!.lastPaymentDate = _lastPaymentDateController.text;
    _currentResident!.adults = int.tryParse(_adultsController.text) ?? 0;
    _currentResident!.children = int.tryParse(_childrenController.text) ?? 0;
    _currentResident!.totalHeadcount = int.tryParse(_totalHeadcountController.text) ?? 0;
    _currentResident!.mainContactName = _mainContactNameController.text;
    _currentResident!.contactRole = _contactRoleController.text;
    _currentResident!.phoneNumber = _phoneNumberController.text;
    _currentResident!.whatsappNumber = _whatsappNumberController.text;
    _currentResident!.email = _emailController.text;
    _currentResident!.appRegistered = _appRegisteredController.text;
    _currentResident!.phoneType = _phoneTypeController.text;
    _currentResident!.notes = _notesController.text;
    _currentResident!.visitDate = _visitDateController.text;
    _currentResident!.visitedBy = _visitedByController.text;
    _currentResident!.dataVerified = _dataVerifiedController.text;
    _currentResident!.followUpNeeded = _followUpNeededController.text;
    _currentResident!.followUpDate = _followUpDateController.text;
    _currentResident!.isModified = true;
    _currentResident!.updatedAt = DateTime.now();

    // Save to database
    _currentResident!.save();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resident data saved for ${_currentResident!.houseAddress}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _saveAndNext() {
    _saveCurrentResident();
    
    if (_currentIndex < _allResidents.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadResidentData(_allResidents[_currentIndex]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reached end of resident list'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _previousResident() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadResidentData(_allResidents[_currentIndex]);
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final residents = ref.watch(residentsListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estate Door-to-Door Capture'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () async {
              // Export functionality - will be implemented later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export functionality will be added')),
              );
            },
          ),
        ],
      ),
      body: residents.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading resident data...'),
                ],
              ),
            )
          : Column(
              children: [
                // Navigation Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'House ${_currentIndex + 1} of ${_allResidents.length}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _currentIndex > 0 ? _previousResident : null,
                        tooltip: 'Previous House',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _currentIndex < _allResidents.length - 1 ? () {
                          setState(() {
                            _currentIndex++;
                          });
                          _loadResidentData(_allResidents[_currentIndex]);
                        } : null,
                        tooltip: 'Next House',
                      ),
                    ],
                  ),
                ),
                
                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // House Address (Primary Selector)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'House Address',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    initialValue: _selectedHouseId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Select House Address',
                                    ),
                                    items: _allResidents.map((resident) {
                                      return DropdownMenuItem<int>(
                                        value: resident.id,
                                        child: Text(
                                          resident.houseAddress.isNotEmpty
                                              ? resident.houseAddress
                                              : 'Unknown Address',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (int? newId) {
                                      if (newId != null) {
                                        final selectedResident = _allResidents.firstWhere(
                                          (r) => r.id == newId,
                                        );
                                        final index = _allResidents.indexOf(selectedResident);
                                        setState(() {
                                          _currentIndex = index;
                                          _selectedHouseId = newId;
                                        });
                                        _loadResidentData(selectedResident);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Basic House Information
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'House Information',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _zoneBlockController,
                                    decoration: const InputDecoration(
                                      labelText: 'Zone/Block',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _houseTypeController,
                                    decoration: const InputDecoration(
                                      labelText: 'House Type',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _unitFlatController,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit/Flat',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _occupancyStatusController,
                                    decoration: const InputDecoration(
                                      labelText: 'Occupied?',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Household Information
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Household Information',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _householdsCountController,
                                          decoration: const InputDecoration(
                                            labelText: '# Households',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _adultsController,
                                          decoration: const InputDecoration(
                                            labelText: 'Adults',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _childrenController,
                                          decoration: const InputDecoration(
                                            labelText: 'Children',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _totalHeadcountController,
                                          decoration: const InputDecoration(
                                            labelText: 'Total Headcount',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Contact Information
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Contact Information',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _mainContactNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Main Contact Name',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _contactRoleController,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Role',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: _phoneNumberController,
                                          decoration: const InputDecoration(
                                            labelText: 'Phone Number',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.call, color: Colors.green),
                                        onPressed: _phoneNumberController.text.isNotEmpty
                                            ? () => _makeCall(_phoneNumberController.text)
                                            : null,
                                        tooltip: 'Call',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: _whatsappNumberController,
                                          decoration: const InputDecoration(
                                            labelText: 'WhatsApp Number',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.chat, color: Colors.green),
                                        onPressed: _whatsappNumberController.text.isNotEmpty
                                            ? () => _openWhatsApp(_whatsappNumberController.text)
                                            : null,
                                        tooltip: 'WhatsApp',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Additional Information
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Additional Information',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _notesController,
                                    decoration: const InputDecoration(
                                      labelText: 'Notes/Issues',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _visitDateController,
                                    decoration: const InputDecoration(
                                      labelText: 'Visit Date',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _visitedByController,
                                    decoration: const InputDecoration(
                                      labelText: 'Visited By',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade400,
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveCurrentResident,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _currentIndex < _allResidents.length - 1 ? _saveAndNext : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save & Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _houseAddressController.dispose();
    _zoneBlockController.dispose();
    _houseTypeController.dispose();
    _unitFlatController.dispose();
    _occupancyStatusController.dispose();
    _recordStatusController.dispose();
    _householdsCountController.dispose();
    _monthlyDueController.dispose();
    _paymentStatusController.dispose();
    _lastPaymentDateController.dispose();
    _adultsController.dispose();
    _childrenController.dispose();
    _totalHeadcountController.dispose();
    _mainContactNameController.dispose();
    _contactRoleController.dispose();
    _phoneNumberController.dispose();
    _whatsappNumberController.dispose();
    _emailController.dispose();
    _appRegisteredController.dispose();
    _phoneTypeController.dispose();
    _notesController.dispose();
    _visitDateController.dispose();
    _visitedByController.dispose();
    _dataVerifiedController.dispose();
    _followUpNeededController.dispose();
    _followUpDateController.dispose();
    super.dispose();
  }
}