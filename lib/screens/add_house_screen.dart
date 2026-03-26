import 'package:flutter/material.dart';
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
  String? _houseType;

  @override
  void dispose() {
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

  Future<void> _saveHouse() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final newResident = Resident(
        id: 0, // Auto-assigned
        houseAddress: _addressController.text.trim(),
        zoneBlock: _zoneController.text.trim(),
        houseType: _houseType,
        unitFlat: _unitFlatController.text.trim(),
        totalFlatsInCompound: int.tryParse(_totalFlatsController.text.trim()),
        occupancyStatus: 'No', // Default vacant
        householdsCount: 0,
        adults: 0,
        children: 0,
        totalHeadcount: 0,
        dataSource: 'Field Added',
        verificationStatus: 'Unverified',
        isModified: true,
      );

      final newId = await DatabaseService.addResident(newResident);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('House added successfully (ID: $newId)'),
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
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                            child: TextFormField(
                              controller: _unitFlatController,
                              decoration: _inputDeco(
                                  'Unit / Flat No.', hint: 'e.g. B2'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _houseType,
                        decoration: _inputDeco('House Type'),
                        isExpanded: true,
                        items: kHouseTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setState(() => _houseType = v),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'House will be marked Vacant by default. You can update occupancy details on the next screen.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveHouse,
                  icon: const Icon(Icons.add_home),
                  label: const Text('ADD HOUSE',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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
