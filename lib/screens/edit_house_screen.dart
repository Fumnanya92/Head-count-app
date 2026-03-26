import 'package:flutter/material.dart';
import '../models/resident.dart';
import '../services/database_service.dart';

class EditHouseScreen extends StatefulWidget {
  final Resident resident;

  const EditHouseScreen({super.key, required this.resident});

  @override
  State<EditHouseScreen> createState() => _EditHouseScreenState();
}

class _EditHouseScreenState extends State<EditHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _zoneController;
  late final TextEditingController _houseTypeController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.resident.houseAddress);
    _zoneController = TextEditingController(text: widget.resident.zoneBlock ?? '');
    _houseTypeController = TextEditingController(text: widget.resident.houseType ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _zoneController.dispose();
    _houseTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final updatedResident = widget.resident.copyWith(
        houseAddress: _addressController.text.trim(),
        zoneBlock: _zoneController.text.trim(),
        houseType: _houseTypeController.text.trim(),
        isModified: true,
      );

      await DatabaseService.saveResident(updatedResident);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('House information updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update house: $e'),
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
        title: const Text('Edit House Info'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveChanges,
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
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'House Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'House Address *',
                          hintText: 'e.g., 4, FAMUYIWA Obodo St. Infinity Estate',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the house address';
                          }
                          return null;
                        },
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _zoneController,
                        decoration: const InputDecoration(
                          labelText: 'Zone/Block',
                          hintText: 'e.g., IBE\'S COMPOUND',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _houseTypeController,
                        decoration: const InputDecoration(
                          labelText: 'House Type',
                          hintText: 'e.g., Mini flat, 1 room, 2 bedroom',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
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
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing basic house information. Occupancy details can be updated from the quick update screen.',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
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
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}