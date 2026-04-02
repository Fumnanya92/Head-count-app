import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/resident.dart';
import '../providers/resident_provider.dart';
import '../services/database_service.dart';
import 'export_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final residents = DatabaseService.getAllResidents();
    final filterOptions = ref.watch(filterOptionsProvider);
    final statistics = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estate Capture'),
        actions: [
          // Filter button
          IconButton(
            icon: Badge(
              isLabelVisible: filterOptions.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterDialog(context),
          ),
          // Statistics button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showStatistics(context, statistics),
          ),
          // Export button
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search house address / street / number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '${residents.length} houses',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                if (filterOptions.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('Filtered'),
                    onDeleted: () {
                      ref.read(filterOptionsProvider.notifier).state =
                          FilterOptions();
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Residents list
          Expanded(
            child: residents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No houses found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: residents.length,
                    itemBuilder: (context, index) {
                      final resident = residents[index];
                      return _ResidentListTile(
                        resident: resident,
                        onTap: () async {
                          // Navigation removed - this file is deprecated
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This interface has been replaced with the new form-first design')),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Houses'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Occupied Only'),
                leading: const Icon(Icons.home),
                onTap: () {
                  ref.read(filterOptionsProvider.notifier).state =
                      ref.read(filterOptionsProvider).copyWith(occupied: true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Vacant Only'),
                leading: const Icon(Icons.home_outlined),
                onTap: () {
                  ref.read(filterOptionsProvider.notifier).state =
                      ref.read(filterOptionsProvider).copyWith(occupied: false);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Follow-up Needed'),
                leading: const Icon(Icons.flag),
                onTap: () {
                  ref.read(filterOptionsProvider.notifier).state = ref
                      .read(filterOptionsProvider)
                      .copyWith(followUpNeeded: true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Not Visited'),
                leading: const Icon(Icons.location_off),
                onTap: () {
                  ref.read(filterOptionsProvider.notifier).state =
                      ref.read(filterOptionsProvider).copyWith(notVisited: true);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Clear Filters'),
                leading: const Icon(Icons.clear_all),
                onTap: () {
                  ref.read(filterOptionsProvider.notifier).state =
                      FilterOptions();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStatistics(
      BuildContext context, Map<String, dynamic> statistics) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow('Total Houses:', statistics['total'].toString()),
              _StatRow('Occupied:', statistics['occupied'].toString()),
              _StatRow('Vacant:', statistics['vacant'].toString()),
              _StatRow('Total People:', statistics['totalPeople'].toString()),
              const Divider(),
              _StatRow('Visited:', statistics['visited'].toString()),
              _StatRow('Follow-up Needed:', statistics['followUp'].toString()),
              _StatRow('Modified:', statistics['modified'].toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _ResidentListTile extends StatelessWidget {
  final Resident resident;
  final VoidCallback onTap;

  const _ResidentListTile({
    required this.resident,
    required this.onTap,
  });

  Color _getBackgroundColor() {
    if (resident.needsFollowUp) {
      return Colors.yellow[100]!;
    } else if (resident.isOccupied) {
      return Colors.green[50]!;
    } else {
      return Colors.red[50]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: _getBackgroundColor(),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          resident.houseAddress,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (resident.zoneBlock != null && resident.zoneBlock!.isNotEmpty)
              Text(
                resident.zoneBlock!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Badge(
                  label: resident.isOccupied ? 'Occupied' : 'Vacant',
                  color:
                      resident.isOccupied ? Colors.green[700]! : Colors.red[700]!,
                ),
                const SizedBox(width: 8),
                if (resident.isOccupied)
                  _Badge(
                    label:
                        '${resident.adults}A + ${resident.children}C = ${resident.totalHeadcount}',
                    color: Colors.blue[700]!,
                  ),
                const SizedBox(width: 8),
                if (resident.needsFollowUp)
                  _Badge(
                    label: 'Follow-up',
                    color: Colors.orange[700]!,
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
