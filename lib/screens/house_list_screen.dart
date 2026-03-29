import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/resident.dart';
import '../providers/resident_provider.dart';
import '../services/database_service.dart';
import 'resident_detail_screen.dart';
import 'add_house_screen.dart';
import 'export_screen.dart';

// Lazy-loading avatar widget
class LazyAvatarDisplay extends StatefulWidget {
  final String? imagePath;
  final String address;
  final double size;

  const LazyAvatarDisplay({
    super.key,
    this.imagePath,
    required this.address,
    this.size = 50,
  });

  @override
  State<LazyAvatarDisplay> createState() => _LazyAvatarDisplayState();
}

class _LazyAvatarDisplayState extends State<LazyAvatarDisplay> {
  bool _showImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Delay image loading to avoid rendering all 430 at once
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showImage = true;
        });
      }
    });
  }

  String _getInitials() {
    try {
      if (widget.address.isEmpty) return 'H';
      return widget.address[0].toUpperCase();
    } catch (e) {
      return 'H';
    }
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: Colors.blue.shade300,
      child: Text(
        _getInitials(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder until images can be loaded
    if (!_showImage || widget.imagePath == null || widget.imagePath!.isEmpty) {
      return _buildFallback();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: Image.file(
          File(widget.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback();
          },
        ),
      ),
    );
  }
}

enum HouseFilter {
  all,
  notVisited,
  visited,
  vacant,
  occupied,
  needsFollowup,
  verified,
  unverified,
}

class HouseListScreen extends ConsumerStatefulWidget {
  const HouseListScreen({super.key});

  @override
  ConsumerState<HouseListScreen> createState() => _HouseListScreenState();
}

class _HouseListScreenState extends ConsumerState<HouseListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  HouseFilter _selectedFilter = HouseFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Resident> _getFilteredResidents(List<Resident> allResidents) {
    List<Resident> filtered = allResidents.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.houseAddress.toLowerCase().contains(q) ||
          (r.zoneBlock?.toLowerCase().contains(q) ?? false) ||
          (r.mainContactName?.toLowerCase().contains(q) ?? false) ||
          r.id.toString().contains(q);
    }).toList();

    switch (_selectedFilter) {
      case HouseFilter.notVisited:
        filtered = filtered
            .where((r) => r.visitDate == null || r.visitDate!.isEmpty)
            .toList();
        break;
      case HouseFilter.visited:
        filtered = filtered
            .where((r) => r.visitDate != null && r.visitDate!.isNotEmpty)
            .toList();
        break;
      case HouseFilter.vacant:
        filtered = filtered
            .where((r) =>
                r.occupancyStatus.toLowerCase() == 'no' ||
                r.occupancyStatus.toLowerCase() == 'vacant')
            .toList();
        break;
      case HouseFilter.occupied:
        filtered = filtered
            .where((r) =>
                r.occupancyStatus.toLowerCase() == 'yes' ||
                r.occupancyStatus.toLowerCase() == 'occupied')
            .toList();
        break;
      case HouseFilter.needsFollowup:
        filtered = filtered.where((r) => r.needsFollowUp).toList();
        break;
      case HouseFilter.verified:
        filtered = filtered.where((r) => r.isVerified).toList();
        break;
      case HouseFilter.unverified:
        filtered = filtered.where((r) => !r.isVerified).toList();
        break;
      case HouseFilter.all:
        break;
    }

    filtered.sort((a, b) => a.id.compareTo(b.id));
    return filtered;
  }

  Widget _buildFilterChip(HouseFilter filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: Colors.blue.shade100,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Color _getStatusColor(Resident r) {
    if (r.isVerified) return Colors.indigo;
    if (r.visitDate != null && r.visitDate!.isNotEmpty) return Colors.green;
    if (r.isOccupied) return Colors.orange;
    return Colors.grey;
  }

  String _getStatusText(Resident r) {
    if (r.isVerified) return 'Verified';
    if (r.visitDate != null && r.visitDate!.isNotEmpty) return 'Visited';
    if (r.isOccupied) return 'Occupied';
    return 'Vacant';
  }

  Future<void> _quickExport() async {
    try {
      final csvData = DatabaseService.exportToCsv();
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/estate_headcount_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Estate Headcount Export');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Exported!'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allResidents = ref.watch(residentsListProvider);
    final filteredResidents = _getFilteredResidents(allResidents);
    final stats = DatabaseService.getStatistics();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Estate Door-to-Door',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Quick export
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _quickExport,
            tooltip: 'Quick Export',
          ),
          // Full export screen
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExportScreen())),
            tooltip: 'Export & Stats',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress summary strip
          Container(
            color: Colors.blue.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _QuickStat(
                    '${stats['total']}', 'Total', Icons.home, Colors.white),
                _QuickStat('${stats['visited']}', 'Visited',
                    Icons.check_circle_outline, Colors.greenAccent),
                _QuickStat('${stats['occupied']}', 'Occupied',
                    Icons.people, Colors.amber),
                _QuickStat('${stats['totalPeople']}', 'People',
                    Icons.groups, Colors.lightBlueAccent),
                _QuickStat('${stats['verified']}', 'Verified',
                    Icons.verified, Colors.tealAccent),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search address, zone, contact...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        })
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(HouseFilter.all, 'All', Icons.home),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.notVisited, 'Not Visited', Icons.schedule),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.visited, 'Visited', Icons.check_circle),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.occupied, 'Occupied', Icons.people),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.vacant, 'Vacant', Icons.home_outlined),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.verified, 'Verified', Icons.verified),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.unverified, 'Unverified', Icons.pending),
                const SizedBox(width: 8),
                _buildFilterChip(
                    HouseFilter.needsFollowup, 'Follow-up', Icons.flag),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filteredResidents.length} of ${allResidents.length} houses',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // List
          Expanded(
            child: filteredResidents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          allResidents.isEmpty
                              ? 'No houses loaded'
                              : 'No matching houses',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filteredResidents.length,
                    itemBuilder: (context, index) {
                      final r = filteredResidents[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ResidentDetailScreen(residentId: r.id),
                              ),
                            );
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Avatar with lazy loading
                                LazyAvatarDisplay(
                                  imagePath: r.avatarImagePath,
                                  address: r.houseAddress,
                                  size: 50,
                                ),
                                const SizedBox(width: 12),
                                // Status dot
                                Container(
                                  width: 4,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(r),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.houseAddress,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          if (r.zoneBlock?.isNotEmpty == true)
                                            r.zoneBlock!,
                                          if (r.houseType?.isNotEmpty == true)
                                            r.houseType!,
                                          if (r.totalFlatsInCompound != null)
                                            '${r.totalFlatsInCompound} flats',
                                        ].join(' · '),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Right side badges
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _StatusBadge(
                                      _getStatusText(r),
                                      _getStatusColor(r),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.isOccupied
                                          ? '${r.totalHeadcount} people'
                                          : 'Vacant',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    color: Colors.grey, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddHouseScreen()),
          );
          if (result == true) {
            ref.invalidate(residentsListProvider);
            setState(() {});
          }
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_home),
        label: const Text('Add House'),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _QuickStat(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
