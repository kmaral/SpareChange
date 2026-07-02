import 'package:hive/hive.dart';

part 'denomination.g.dart';

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

  @HiveField(6)
  final bool isAutoCreated;

  Denomination({
    required this.id,
    required this.value,
    required this.type,
    this.isActive = true,
    DateTime? createdAt,
    this.isAutoCreated = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Create a copy with updated fields
  Denomination copyWith({
    String? id,
    double? value,
    DenominationType? type,
    bool? isActive,
    DateTime? createdAt,
    bool? isAutoCreated,
  }) {
    return Denomination(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isAutoCreated: isAutoCreated ?? this.isAutoCreated,
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

  // Display value with custom currency symbol and number formatter
  String displayValueWithCurrency(
    String currencySymbol, {
    String Function(double)? formatter,
  }) {
    final formattedValue =
        formatter?.call(value) ??
        (value < 1
            ? value.toStringAsFixed(2)
            : value % 1 == 0
            ? value.toInt().toString()
            : value.toStringAsFixed(2));
    return '$currencySymbol$formattedValue';
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
