import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 3)
class CurrencyTransaction {
  @HiveField(0)
  final String id;

  @HiveField(3)
  final double denominationValue;

  @HiveField(11)
  final String denominationId;

  @HiveField(4)
  final int quantity;

  @HiveField(5)
  final TransactionType transactionType;

  @HiveField(6)
  final double totalAmount;

  @HiveField(7)
  final String? reason;

  @HiveField(8)
  final DateTime timestamp;

  @HiveField(9)
  final DateTime lastModified;

  CurrencyTransaction({
    required this.id,
    required this.denominationValue,
    required this.denominationId,
    required this.quantity,
    required this.transactionType,
    required this.totalAmount,
    this.reason,
    DateTime? timestamp,
    DateTime? lastModified,
  }) : timestamp = timestamp ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now();

  // Create a copy with updated fields
  CurrencyTransaction copyWith({
    String? id,
    double? denominationValue,
    String? denominationId,
    int? quantity,
    TransactionType? transactionType,
    double? totalAmount,
    String? reason,
    DateTime? timestamp,
    DateTime? lastModified,
  }) {
    return CurrencyTransaction(
      id: id ?? this.id,
      denominationValue: denominationValue ?? this.denominationValue,
      denominationId: denominationId ?? this.denominationId,
      quantity: quantity ?? this.quantity,
      transactionType: transactionType ?? this.transactionType,
      totalAmount: totalAmount ?? this.totalAmount,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  // Display denomination value with currency symbol
  String get displayDenomination {
    if (denominationValue < 1) {
      return '₹${denominationValue.toStringAsFixed(2)}';
    } else if (denominationValue % 1 == 0) {
      return '₹${denominationValue.toInt()}';
    } else {
      return '₹${denominationValue.toStringAsFixed(2)}';
    }
  }

  // Display denomination value with custom currency symbol and number formatter
  String displayDenominationWithCurrency(
    String currencySymbol, {
    String Function(double)? formatter,
  }) {
    final formattedValue =
        formatter?.call(denominationValue) ??
        (denominationValue < 1
            ? denominationValue.toStringAsFixed(2)
            : denominationValue % 1 == 0
            ? denominationValue.toInt().toString()
            : denominationValue.toStringAsFixed(2));
    return '$currencySymbol$formattedValue';
  }

  // Display total amount with currency symbol
  String get displayTotalAmount {
    if (totalAmount < 1) {
      return '₹${totalAmount.toStringAsFixed(2)}';
    } else if (totalAmount % 1 == 0) {
      return '₹${totalAmount.toInt()}';
    } else {
      return '₹${totalAmount.toStringAsFixed(2)}';
    }
  }

  // Display total amount with custom currency symbol and number formatter
  String displayTotalAmountWithCurrency(
    String currencySymbol, {
    String Function(double)? formatter,
  }) {
    final formattedValue =
        formatter?.call(totalAmount) ??
        (totalAmount < 1
            ? totalAmount.toStringAsFixed(2)
            : totalAmount % 1 == 0
            ? totalAmount.toInt().toString()
            : totalAmount.toStringAsFixed(2));
    return '$currencySymbol$formattedValue';
  }

  // Get sign prefix for display (+/-)
  String get signPrefix {
    return transactionType == TransactionType.added ? '+' : '-';
  }

  @override
  String toString() {
    return 'CurrencyTransaction(id: $id, $signPrefix$displayDenomination × $quantity = $displayTotalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrencyTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@HiveType(typeId: 4)
enum TransactionType {
  @HiveField(0)
  added,

  @HiveField(1)
  taken,
}
