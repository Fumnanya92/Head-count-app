import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/resident.dart';
import '../services/database_service.dart';

// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider for filter options
final filterOptionsProvider = StateProvider<FilterOptions>((ref) => FilterOptions());

class FilterOptions {
  final bool? occupied;
  final bool? followUpNeeded;
  final bool? notVisited;

  FilterOptions({
    this.occupied,
    this.followUpNeeded,
    this.notVisited,
  });

  FilterOptions copyWith({
    bool? occupied,
    bool? followUpNeeded,
    bool? notVisited,
    bool clearOccupied = false,
    bool clearFollowUp = false,
    bool clearNotVisited = false,
  }) {
    return FilterOptions(
      occupied: clearOccupied ? null : (occupied ?? this.occupied),
      followUpNeeded: clearFollowUp ? null : (followUpNeeded ?? this.followUpNeeded),
      notVisited: clearNotVisited ? null : (notVisited ?? this.notVisited),
    );
  }

  bool get hasActiveFilters =>
      occupied != null || followUpNeeded != null || notVisited != null;
}

// Provider for residents list with search and filter
final residentsListProvider = Provider<List<Resident>>((ref) {
  final searchQuery = ref.watch(searchQueryProvider);
  final filterOptions = ref.watch(filterOptionsProvider);

  // Start with all residents
  List<Resident> residents = DatabaseService.getAllResidents();

  // Apply search
  if (searchQuery.isNotEmpty) {
    residents = DatabaseService.searchResidents(searchQuery);
  }

  // Apply filters
  if (filterOptions.hasActiveFilters) {
    if (filterOptions.occupied != null) {
      residents = residents.where((r) => r.isOccupied == filterOptions.occupied).toList();
    }
    if (filterOptions.followUpNeeded != null) {
      residents = residents.where((r) => r.needsFollowUp == filterOptions.followUpNeeded).toList();
    }
    if (filterOptions.notVisited == true) {
      residents = residents.where((r) => r.visitDate == null || r.visitDate!.isEmpty).toList();
    }
  }

  // Sort by house address
  residents.sort((a, b) => a.houseAddress.compareTo(b.houseAddress));

  return residents;
});

// Provider for statistics
final statisticsProvider = Provider<Map<String, dynamic>>((ref) {
  // Watch residents list to trigger rebuild
  ref.watch(residentsListProvider);
  return DatabaseService.getStatistics();
});

// Provider for selected resident
final selectedResidentProvider = StateProvider<Resident?>((ref) => null);
