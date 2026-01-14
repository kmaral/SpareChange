import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../services/encryption_service.dart';

@HiveType(typeId: 3)
class CurrencyTransaction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String userName;

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

  @HiveField(10)
  final SyncStatus syncStatus;

  CurrencyTransaction({
    required this.id,
    required this.userId,
    required this.userName,
    required this.denominationValue,
    required this.denominationId,
    required this.quantity,
    required this.transactionType,
    required this.totalAmount,
    this.reason,
    DateTime? timestamp,
    DateTime? lastModified,
    this.syncStatus = SyncStatus.pending,
  }) : timestamp = timestamp ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now();

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    final encryption = EncryptionService();
    return {
      'id': id,
      'userId': userId,
      'userName': encryption.encrypt(userName),
      'denominationValue': denominationValue,
      'denominationId': denominationId,
      'quantity': quantity,
      'transactionType': transactionType.toString().split('.').last,
      'totalAmount': totalAmount,
      'reason': encryption.encryptNullable(reason),
      'timestamp': Timestamp.fromDate(timestamp),
      'lastModified': Timestamp.fromDate(lastModified),
      'syncStatus': syncStatus.toString().split('.').last,
    };
  }

  // Create from Firestore document
  factory CurrencyTransaction.fromJson(Map<String, dynamic> json) {
    final encryption = EncryptionService();
    final encryptedUserName = json['userName'] as String;
    final encryptedReason = json['reason'] as String?;

    return CurrencyTransaction(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: encryption.decrypt(encryptedUserName),
      denominationValue: (json['denominationValue'] as num).toDouble(),
      denominationId: json['denominationId'] as String? ?? '',
      quantity: json['quantity'] as int,
      transactionType: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['transactionType'],
      ),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      reason: encryption.decryptNullable(encryptedReason),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      lastModified: (json['lastModified'] as Timestamp).toDate(),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['syncStatus'] ?? 'synced'),
        orElse: () => SyncStatus.synced,
      ),
    );
  }

  // Create a copy with updated fields
  CurrencyTransaction copyWith({
    String? id,
    String? userId,
    String? userName,
    double? denominationValue,
    String? denominationId,
    int? quantity,
    TransactionType? transactionType,
    double? totalAmount,
    String? reason,
    DateTime? timestamp,
    DateTime? lastModified,
    SyncStatus? syncStatus,
  }) {
    return CurrencyTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      denominationValue: denominationValue ?? this.denominationValue,
      denominationId: denominationId ?? this.denominationId,
      quantity: quantity ?? this.quantity,
      transactionType: transactionType ?? this.transactionType,
      totalAmount: totalAmount ?? this.totalAmount,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
      lastModified: lastModified ?? this.lastModified,
      syncStatus: syncStatus ?? this.syncStatus,
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

  // Get sign prefix for display (+/-)
  String get signPrefix {
    return transactionType == TransactionType.added ? '+' : '-';
  }

  @override
  String toString() {
    return 'CurrencyTransaction(id: $id, userName: $userName, $signPrefix$displayDenomination × $quantity = $displayTotalAmount)';
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

@HiveType(typeId: 5)
enum SyncStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  synced,

  @HiveField(2)
  failed,
}
