import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Denomination {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double value;

  @HiveField(2)
  final DenominationType type;

  @HiveField(3)
  final bool isActive;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String groupId;

  Denomination({
    required this.id,
    required this.value,
    required this.type,
    this.isActive = true,
    DateTime? createdAt,
    required this.groupId,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'type': type.toString().split('.').last,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'groupId': groupId,
    };
  }

  // Create from Firestore document
  factory Denomination.fromJson(Map<String, dynamic> json) {
    final groupId = json['groupId'] as String?;
    if (groupId == null || groupId.isEmpty) {
      throw ArgumentError('Denomination must have a valid groupId');
    }

    return Denomination(
      id: json['id'] as String,
      value: (json['value'] as num).toDouble(),
      type: DenominationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      groupId: groupId,
    );
  }

  // Create a copy with updated fields
  Denomination copyWith({
    String? id,
    double? value,
    DenominationType? type,
    bool? isActive,
    DateTime? createdAt,
    String? groupId,
  }) {
    return Denomination(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      groupId: groupId ?? this.groupId,
    );
  }

  // Display value with currency symbol
  String get displayValue {
    if (value < 1) {
      return '₹${value.toStringAsFixed(2)}';
    } else if (value % 1 == 0) {
      return '₹${value.toInt()}';
    } else {
      return '₹${value.toStringAsFixed(2)}';
    }
  }

  @override
  String toString() {
    return 'Denomination(id: $id, value: $value, type: $type, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Denomination && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@HiveType(typeId: 1)
enum DenominationType {
  @HiveField(0)
  coin,

  @HiveField(1)
  note,
}
