import 'package:hive/hive.dart';

@HiveType(typeId: 6)
class Inventory {
  @HiveField(0)
  final Map<String, int> denominationCounts;

  @HiveField(1)
  final DateTime lastUpdated;

  @HiveField(2)
  final String? groupId;

  Inventory({
    Map<String, int>? denominationCounts,
    DateTime? lastUpdated,
    this.groupId,
  }) : denominationCounts = denominationCounts ?? {},
       lastUpdated = lastUpdated ?? DateTime.now();

  // Get count for a specific denomination ID
  int getCount(String denominationId) {
    return denominationCounts[denominationId] ?? 0;
  }

  // Set count for a specific denomination ID
  Inventory setCount(String denominationId, int count) {
    final newCounts = Map<String, int>.from(denominationCounts);
    if (count <= 0) {
      newCounts.remove(denominationId);
    } else {
      newCounts[denominationId] = count;
    }
    return Inventory(
      denominationCounts: newCounts,
      lastUpdated: DateTime.now(),
      groupId: groupId,
    );
  }

  // Add to count for a specific denomination ID
  Inventory addCount(String denominationId, int quantity) {
    final currentCount = getCount(denominationId);
    return setCount(denominationId, currentCount + quantity);
  }

  // Subtract from count for a specific denomination ID
  Inventory subtractCount(String denominationId, int quantity) {
    final currentCount = getCount(denominationId);
    final newCount = currentCount - quantity;
    return setCount(denominationId, newCount > 0 ? newCount : 0);
  }

  // Calculate total value based on denomination values
  double calculateTotalValue(Map<String, double> denominationValues) {
    double total = 0.0;
    denominationCounts.forEach((denominationId, count) {
      final value = denominationValues[denominationId] ?? 0.0;
      total += value * count;
    });
    return total;
  }

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'denominationCounts': denominationCounts,
      'lastUpdated': lastUpdated.toIso8601String(),
      'groupId': groupId,
    };
  }

  // Create from Firestore document
  factory Inventory.fromJson(Map<String, dynamic> json) {
    final countsMap = json['denominationCounts'] as Map<String, dynamic>?;
    final counts =
        countsMap?.map((key, value) => MapEntry(key, value as int)) ?? {};

    return Inventory(
      denominationCounts: counts,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
      groupId: json['groupId'] as String?,
    );
  }

  // Create a copy with updated fields
  Inventory copyWith({
    Map<String, int>? denominationCounts,
    DateTime? lastUpdated,
    String? groupId,
  }) {
    return Inventory(
      denominationCounts: denominationCounts ?? this.denominationCounts,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      groupId: groupId ?? this.groupId,
    );
  }

  @override
  String toString() {
    return 'Inventory(counts: ${denominationCounts.length} denominations, lastUpdated: $lastUpdated, groupId: $groupId)';
  }
}
