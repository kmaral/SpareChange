import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/transaction.dart';
import 'firestore_service.dart';

class SyncService {
  final FirestoreService _firestoreService;
  final Connectivity _connectivity = Connectivity();
  Box<CurrencyTransaction>? _pendingTransactionsBox;

  bool _isOnline = true;
  bool _isSyncing = false;

  SyncService(this._firestoreService);

  // Initialize Hive and start monitoring connectivity
  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CurrencyTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SyncStatusAdapter());
    }

    // Open pending transactions box
    _pendingTransactionsBox = await Hive.openBox<CurrencyTransaction>(
      'pending_transactions',
    );

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      // If we just came online, sync pending transactions
      if (wasOffline && _isOnline) {
        syncPendingTransactions();
      }
    });

    // Sync any pending transactions on startup
    if (_isOnline) {
      syncPendingTransactions();
    }
  }

  bool get isOnline => _isOnline;

  // Queue a transaction for later sync (when offline)
  Future<void> queueTransaction(CurrencyTransaction transaction) async {
    if (_pendingTransactionsBox == null) {
      throw Exception('SyncService not initialized');
    }

    final pendingTransaction = transaction.copyWith(
      syncStatus: SyncStatus.pending,
    );

    await _pendingTransactionsBox!.put(transaction.id, pendingTransaction);
  }

  // Remove a transaction from the queue
  Future<void> removeFromQueue(String transactionId) async {
    if (_pendingTransactionsBox == null) return;
    await _pendingTransactionsBox!.delete(transactionId);
  }

  // Sync all pending transactions to Firestore
  Future<void> syncPendingTransactions() async {
    if (_pendingTransactionsBox == null || _isSyncing) return;
    if (!_isOnline) return;

    _isSyncing = true;

    try {
      final pendingTransactions = _pendingTransactionsBox!.values.toList();

      for (final transaction in pendingTransactions) {
        try {
          // Sync to Firestore
          await _firestoreService.addTransaction(
            transaction.copyWith(syncStatus: SyncStatus.synced),
          );

          // Remove from local queue
          await _pendingTransactionsBox!.delete(transaction.id);
        } catch (e) {
          // Mark as failed
          final failedTransaction = transaction.copyWith(
            syncStatus: SyncStatus.failed,
          );
          await _pendingTransactionsBox!.put(transaction.id, failedTransaction);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  // Get count of pending transactions
  int get pendingCount => _pendingTransactionsBox?.length ?? 0;

  // Get all pending transactions
  List<CurrencyTransaction> get pendingTransactions =>
      _pendingTransactionsBox?.values.toList() ?? [];

  // Retry failed transactions
  Future<void> retryFailedTransactions() async {
    if (_pendingTransactionsBox == null || !_isOnline) return;

    final failedTransactions = _pendingTransactionsBox!.values
        .where((t) => t.syncStatus == SyncStatus.failed)
        .toList();

    for (final transaction in failedTransactions) {
      try {
        await _firestoreService.addTransaction(
          transaction.copyWith(syncStatus: SyncStatus.synced),
        );
        await _pendingTransactionsBox!.delete(transaction.id);
      } catch (e) {
        // Keep as failed
      }
    }
  }

  // Clear all pending transactions (use with caution)
  Future<void> clearPendingTransactions() async {
    if (_pendingTransactionsBox == null) return;
    await _pendingTransactionsBox!.clear();
  }

  // Close the service
  Future<void> close() async {
    await _pendingTransactionsBox?.close();
  }
}

// Adapter classes for Hive (will be generated)
class CurrencyTransactionAdapter extends TypeAdapter<CurrencyTransaction> {
  @override
  final int typeId = 3;

  @override
  CurrencyTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CurrencyTransaction(
      id: fields[0] as String,
      userId: fields[1] as String,
      userName: fields[2] as String,
      denominationValue: fields[3] as double,
      denominationId: fields[11] as String? ?? '',
      quantity: fields[4] as int,
      transactionType: fields[5] as TransactionType,
      totalAmount: fields[6] as double,
      reason: fields[7] as String?,
      timestamp: fields[8] as DateTime,
      lastModified: fields[9] as DateTime,
      syncStatus: fields[10] as SyncStatus,
      groupId: fields[12] as String? ?? 'unknown',
    );
  }

  @override
  void write(BinaryWriter writer, CurrencyTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.denominationValue)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.transactionType)
      ..writeByte(6)
      ..write(obj.totalAmount)
      ..writeByte(7)
      ..write(obj.reason)
      ..writeByte(8)
      ..write(obj.timestamp)
      ..writeByte(9)
      ..write(obj.lastModified)
      ..writeByte(10)
      ..write(obj.syncStatus)
      ..writeByte(11)
      ..write(obj.denominationId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 4;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.added;
      case 1:
        return TransactionType.taken;
      default:
        return TransactionType.added;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.added:
        writer.writeByte(0);
        break;
      case TransactionType.taken:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncStatusAdapter extends TypeAdapter<SyncStatus> {
  @override
  final int typeId = 5;

  @override
  SyncStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncStatus.pending;
      case 1:
        return SyncStatus.synced;
      case 2:
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SyncStatus obj) {
    switch (obj) {
      case SyncStatus.pending:
        writer.writeByte(0);
        break;
      case SyncStatus.synced:
        writer.writeByte(1);
        break;
      case SyncStatus.failed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
