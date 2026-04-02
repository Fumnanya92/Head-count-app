import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../services/database_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _isExporting = false;
  bool _exportModifiedOnly = false;
  bool _isResetting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      // Get RenderBox before async operations to avoid BuildContext issues
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? Rect.fromLTWH(0, 0, box.size.width, box.size.height / 2)
          : Rect.fromLTWH(0, 0, 375, 100);
      
      final bytes =
          DatabaseService.exportToXlsx(modifiedOnly: _exportModifiedOnly);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = _exportModifiedOnly
          ? 'estate_modified_$timestamp.xlsx'
          : 'estate_full_$timestamp.xlsx';

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      // iOS requires sharePositionOrigin to show share sheet
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Estate Headcount Export',
        text: 'Estate headcount data export — $timestamp',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Export successful'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'This will DELETE all current records and reload the original seed data from the latest Excel file.\n\nAny changes made in the app will be LOST.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isResetting = true);
    try {
      final count = await DatabaseService.resetDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database reset — $count records loaded'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {}); // refresh stats
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Reset failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = DatabaseService.getStatistics();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Export Data'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats card
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
                        Icon(Icons.bar_chart, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Statistics',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                    const Divider(height: 20),
                    _StatGrid([
                      _StatItem('Total Records', stats['total'].toString(),
                          Icons.home, Colors.blue),
                      _StatItem('Occupied', stats['occupied'].toString(),
                          Icons.home_filled, Colors.green),
                      _StatItem('Vacant', stats['vacant'].toString(),
                          Icons.home_outlined, Colors.orange),
                      _StatItem('Total People', stats['totalPeople'].toString(),
                          Icons.people, Colors.purple),
                      _StatItem('Visited', stats['visited'].toString(),
                          Icons.check_circle, Colors.teal),
                      _StatItem('Verified', stats['verified'].toString(),
                          Icons.verified, Colors.indigo),
                      _StatItem('Follow-up', stats['followUp'].toString(),
                          Icons.flag, Colors.red),
                      _StatItem('Field Added', stats['fieldAdded'].toString(),
                          Icons.add_location_alt, Colors.amber.shade700),
                    ]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Export options
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
                        Icon(Icons.settings, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Export Options',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                    const Divider(height: 20),
                    SwitchListTile(
                      title: const Text('Export Modified Only'),
                      subtitle: Text(
                        _exportModifiedOnly
                            ? 'Only ${stats['modified']} modified records will be exported'
                            : 'All ${stats['total']} records will be exported',
                      ),
                      value: _exportModifiedOnly,
                      onChanged: (v) => setState(() => _exportModifiedOnly = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info card
            Card(
              color: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The export produces a 3-sheet Excel file:\n• Headcount (32 cols, cascaded address, colour rows)\n• Summary (key stats)\n• Street Summary (per-compound flat counts)\nShare via WhatsApp, Email or Google Drive.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportData,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.table_chart),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Export & Share Excel',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Reset database button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isResetting ? null : _resetDatabase,
                icon: _isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red),
                      )
                    : const Icon(Icons.restore, color: Colors.red),
                label: Text(
                  _isResetting ? 'Resetting...' : 'Reset & Reload from Seed',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _StatGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatGrid(this.items);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: item.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: item.color, size: 18),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
