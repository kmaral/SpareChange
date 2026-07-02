import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'dart:async';
import '../models/user.dart';
import '../models/denomination.dart';
import '../models/transaction.dart';
import '../models/inventory.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class AppProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final SyncService _syncService;
  final SharedPreferences _prefs;

  List<User> _users = [];
  List<Denomination> _denominations = [];
  List<CurrencyTransaction> _transactions = [];
  Inventory? _inventory;

  User? _selectedUser;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _groupId;
  bool _isGroupIdLoaded = false;
  String _currency = 'INR';
  String _numberFormat = '1,234.56';

  bool _isLoading = false;
  String? _error;
  String _themeMode = 'System';

  // Stream subscriptions
  StreamSubscription? _usersSubscription;
  StreamSubscription? _denominationsSubscription;
  StreamSubscription? _transactionsSubscription;
  StreamSubscription? _inventorySubscription;

  AppProvider({
    required FirestoreService firestoreService,
    required SyncService syncService,
    required SharedPreferences prefs,
  }) : _firestoreService = firestoreService,
       _syncService = syncService,
       _prefs = prefs {
    _loadSelectedUser();
    _loadThemeMode();
    _initializeGroupId();
  }

  // Getters
  List<User> get users => _users;
  List<Denomination> get denominations => _denominations;
  List<Denomination> get activeDenominations =>
      _denominations.where((d) => d.isActive).toList();
  List<CurrencyTransaction> get transactions => _transactions;
  // Get transactions for the currently selected user only
  List<CurrencyTransaction> get userTransactions {
    if (_selectedUser == null) return [];
    return _transactions.where((t) => t.userId == _selectedUser!.id).toList();
  }

  Inventory get inventory =>
      _inventory ?? Inventory(groupId: _groupId ?? 'unknown');
  User? get selectedUser => _selectedUser;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _syncService.isOnline;
  int get pendingSyncCount => _syncService.pendingCount;
  String get themeMode => _themeMode;
  String? get groupId => _groupId;
  String get currency => _currency;
  String get numberFormat => _numberFormat;
  // Get currency symbol
  String get currencySymbol {
    switch (_currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
      default:
        return '₹';
    }
  }

  // Get currency icon
  IconData get currencyIconData {
    switch (_currency) {
      case 'USD':
        return Icons.attach_money;
      case 'EUR':
        return Icons.euro_symbol;
      case 'GBP':
        return Icons.currency_pound;
      case 'INR':
      default:
        return Icons.currency_rupee;
    }
  }

  // Get currency icon name (for backward compatibility)
  String get currencyIcon {
    switch (_currency) {
      case 'USD':
        return 'attach_money';
      case 'EUR':
        return 'euro_symbol';
      case 'GBP':
        return 'currency_pound';
      case 'INR':
      default:
        return 'currency_rupee';
    }
  }

  // Reload groupId (useful after creating/joining a group)
  Future<void> reloadGroupId() async {
    try {
      print('AppProvider: Reloading groupId...');
      final authService = AuthService();
      final group = await authService.getUserGroup();
      print('AppProvider: getUserGroup returned: $group');
      _groupId = group?['id'];
      _currency = (group?['currency'] as String?) ?? 'INR';
      _isGroupIdLoaded = true;
      print('AppProvider: Reloaded groupId = $_groupId, currency = $_currency');

      if (_groupId == null) {
        print('AppProvider: WARNING - groupId is still null after reload!');
        print('AppProvider: Group data: $group');
      } else {
        // Cancel old subscriptions and restart with new groupId
        await _cancelSubscriptions();
        _subscribeToStreams();
      }

      notifyListeners();
    } catch (e) {
      print('AppProvider: Error reloading groupId: $e');
    }
  }

  // Reset all data when user signs out (clear cached data for previous user)
  Future<void> resetForNewUser() async {
    try {
      print('AppProvider: Resetting data for user sign out...');

      // Cancel all subscriptions
      await _cancelSubscriptions();

      // Clear all data
      _users = [];
      _denominations = [];
      _transactions = [];
      _inventory = null;
      _selectedUser = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _groupId = null;
      _isGroupIdLoaded = false;
      _error = null;

      // Clear saved selected user from SharedPreferences
      await _prefs.remove('selected_user_id');

      print('AppProvider: Data reset complete');
      notifyListeners();
    } catch (e) {
      print('AppProvider: Error resetting data: $e');
    }
  }

  // Initialize data for new user after sign in
  Future<void> initializeForNewUser() async {
    try {
      print('AppProvider: Initializing data for new user...');

      // Reset data first
      await resetForNewUser();

      // Reload groupId and subscribe to streams
      await _initializeGroupId();

      print('AppProvider: Initialization complete');
    } catch (e) {
      print('AppProvider: Error initializing for new user: $e');
    }
  }

  Future<void> _initializeGroupId() async {
    try {
      print('AppProvider: Loading groupId...');
      final authService = AuthService();
      final group = await authService.getUserGroup();
      print('AppProvider: getUserGroup returned: $group');
      _groupId = group?['id'];
      _currency = (group?['currency'] as String?) ?? 'INR';
      _isGroupIdLoaded = true;
      print('AppProvider: Loaded groupId = $_groupId, currency = $_currency');
      print('AppProvider: _isGroupIdLoaded = $_isGroupIdLoaded');

      if (_groupId == null) {
        print(
          'AppProvider: WARNING - groupId is null! User may not be in a group.',
        );
        print('AppProvider: Group data: $group');
      }

      // Only subscribe after groupId is loaded
      _subscribeToStreams();
      notifyListeners();
    } catch (e) {
      print('AppProvider: Error loading groupId: $e');
      print('AppProvider: Stack trace: ${StackTrace.current}');
      _isGroupIdLoaded = true;
      // Subscribe anyway to avoid blocking the app
      _subscribeToStreams();
      notifyListeners();
    }
  }

  // Ensure groupId is loaded before operations
  Future<void> _ensureGroupIdLoaded() async {
    if (!_isGroupIdLoaded) {
      print('AppProvider: Waiting for groupId to load...');
      // Wait for groupId to be loaded (with timeout)
      int attempts = 0;
      while (!_isGroupIdLoaded && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!_isGroupIdLoaded) {
        print('AppProvider: Timeout waiting for groupId');
        throw Exception('System is initializing. Please wait and try again.');
      }
    }

    if (_groupId == null) {
      print(
        'AppProvider: ERROR - GroupId is null! User must create or join a group.',
      );
      throw Exception(
        'You must create or join a group before performing this action.',
      );
    }

    print('AppProvider: GroupId verified: $_groupId');
  }

  void _loadThemeMode() {
    _themeMode = _prefs.getString('themeMode') ?? 'System';
    print('AppProvider: Loaded theme mode: $_themeMode');
  }

  Future<void> setThemeMode(String mode) async {
    print('AppProvider: Setting theme mode to: $mode');
    _themeMode = mode;
    await _prefs.setString('themeMode', mode);
    print('AppProvider: Theme mode saved and notifying listeners');
    notifyListeners();
  }

  Future<bool> updateCurrency(String currency) async {
    if (_groupId == null) {
      _error = 'No group found';
      return false;
    }

    try {
      print('AppProvider: Updating currency to: $currency');
      await _firestoreService.updateGroupCurrency(_groupId!, currency);
      _currency = currency;
      print('AppProvider: Currency updated successfully');
      notifyListeners();
      return true;
    } catch (e) {
      print('AppProvider: Error updating currency: $e');
      _error = e.toString();
      return false;
    }
  }

  // Format number with comma separator and dot decimal (1,234.56)
  String formatNumber(double value, {int decimals = 2}) {
    final formatted = value.toStringAsFixed(decimals);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formattedInteger = integerPart.replaceAllMapped(
      regex,
      (match) => ',',
    );

    return decimalPart.isNotEmpty
        ? '$formattedInteger.$decimalPart'
        : formattedInteger;
  }

  // ===== USER OPERATIONS =====

  Future<User?> addUser(
    String name,
    String avatarColor, {
    String? firebaseUid,
  }) async {
    _setLoading(true);
    try {
      final user = User(
        id: const Uuid().v4(),
        name: name,
        avatarColor: avatarColor,
        firebaseUid: firebaseUid,
      );

      await _firestoreService.addUser(user);
      return user;
    } catch (e) {
      _setError('Failed to add user: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUser(User user) async {
    _setLoading(true);
    try {
      if (_syncService.isOnline) {
        await _firestoreService.updateUser(user);
      } else {
        _setError('Cannot update user while offline');
      }
    } catch (e) {
      _setError('Failed to update user: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteUser(String userId) async {
    _setLoading(true);
    try {
      final hasTransactions = await _firestoreService.hasUserTransactions(
        userId,
      );
      if (hasTransactions) {
        _setError('Cannot delete user with existing transactions');
        _setLoading(false);
        return;
      }

      if (_syncService.isOnline) {
        await _firestoreService.deleteUser(userId);
        if (_selectedUser?.id == userId) {
          setSelectedUser(null);
        }
      } else {
        _setError('Cannot delete user while offline');
      }
    } catch (e) {
      _setError('Failed to delete user: $e');
    } finally {
      _setLoading(false);
    }
  }

  void setSelectedUser(User? user) {
    _selectedUser = user;
    if (user != null) {
      _prefs.setString('selected_user_id', user.id);
    } else {
      _prefs.remove('selected_user_id');
    }
    notifyListeners();
  }

  void _loadSelectedUser() {
    final userId = _prefs.getString('selected_user_id');
    if (userId != null) {
      // Will be set once users are loaded
    }
  }

  // ===== DENOMINATION OPERATIONS =====

  // Auto-create INR denominations for a group
  Future<void> autoCreateINRDenominations() async {
    try {
      await _ensureGroupIdLoaded();

      // Check if auto-created denominations already exist
      final hasAutoCreated = _denominations.any((d) => d.isAutoCreated);
      if (hasAutoCreated) {
        print('AppProvider: Auto-created INR denominations already exist');
        return;
      }

      final inrValues = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];

      for (final value in inrValues) {
        // Check if denomination with this value already exists
        final exists = _denominations.any((d) => d.value == value);
        if (!exists) {
          final denomination = Denomination(
            id: const Uuid().v4(),
            value: value,
            type: DenominationType.note,
            isActive: true,
            groupId: _groupId!,
            isAutoCreated: true,
          );

          if (_syncService.isOnline) {
            await _firestoreService.addDenomination(denomination);
          }
        }
      }

      print('AppProvider: Auto-created INR denominations');
    } catch (e) {
      print('AppProvider: Error auto-creating INR denominations: $e');
    }
  }

  // Delete all auto-created denominations
  Future<void> deleteAutoCreatedDenominations() async {
    try {
      await _ensureGroupIdLoaded();

      final autoCreatedDenoms = _denominations
          .where((d) => d.isAutoCreated)
          .toList();

      for (final denom in autoCreatedDenoms) {
        if (_syncService.isOnline) {
          await _firestoreService.deleteDenomination(denom.id);
        }
      }

      print('AppProvider: Deleted all auto-created denominations');
    } catch (e) {
      print('AppProvider: Error deleting auto-created denominations: $e');
    }
  }

  // Update group currency
  Future<void> updateGroupCurrency(String currency) async {
    try {
      await _ensureGroupIdLoaded();

      if (_syncService.isOnline) {
        await _firestoreService.updateGroupCurrency(_groupId!, currency);

        // Update local currency state
        _currency = currency;

        // If changed to INR, auto-create denominations
        if (currency == 'INR') {
          await autoCreateINRDenominations();
        } else {
          // If changed from INR, delete auto-created denominations
          await deleteAutoCreatedDenominations();
        }

        notifyListeners();
      } else {
        _setError('Cannot update currency while offline');
      }
    } catch (e) {
      _setError('Failed to update currency: $e');
    }
  }

  Future<void> addDenomination(double value, DenominationType type) async {
    _setLoading(true);
    try {
      // Ensure groupId is loaded
      await _ensureGroupIdLoaded();

      print('AppProvider: Adding denomination with groupId = $_groupId');

      // Check if denomination with this value and type already exists
      final exists = _denominations.any(
        (d) => d.value == value && d.type == type,
      );
      if (exists) {
        final typeName = type == DenominationType.coin ? 'coin' : 'note';
        _setError('$typeName with value ₹$value already exists');
        _setLoading(false);
        return;
      }

      final denomination = Denomination(
        id: const Uuid().v4(),
        value: value,
        type: type,
        isActive: true,
        groupId: _groupId!,
        isAutoCreated: false, // Manually added
      );

      print(
        'AppProvider: Denomination created with groupId = ${denomination.groupId}',
      );

      if (_syncService.isOnline) {
        await _firestoreService.addDenomination(denomination);
        print('AppProvider: Denomination saved to Firestore');
      } else {
        _setError('Cannot add denomination while offline');
      }
    } catch (e) {
      print('AppProvider: Error adding denomination: $e');
      _setError('Failed to add denomination: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleDenominationActive(Denomination denomination) async {
    _setLoading(true);
    try {
      final updated = denomination.copyWith(isActive: !denomination.isActive);
      await _firestoreService.updateDenomination(updated);
    } catch (e) {
      _setError('Failed to update denomination: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDenomination(String denominationId) async {
    _setLoading(true);
    try {
      final hasTransactions = await _firestoreService
          .hasDenominationTransactions(denominationId);
      if (hasTransactions) {
        _setLoading(false);
        return false; // Return false to show warning dialog
      }

      if (_syncService.isOnline) {
        await _firestoreService.deleteDenomination(denominationId);
        _setLoading(false);
        return true;
      } else {
        _setError('Cannot delete denomination while offline');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Failed to delete denomination: $e');
      _setLoading(false);
      return false;
    }
  }

  // ===== TRANSACTION OPERATIONS =====

  Future<void> addTransaction({
    required User user,
    required Denomination denomination,
    required int quantity,
    required TransactionType type,
    String? reason,
    DateTime? timestamp,
  }) async {
    _setLoading(true);
    try {
      // Ensure groupId is loaded
      await _ensureGroupIdLoaded();

      print('AppProvider: Adding transaction with groupId = $_groupId');

      final transaction = CurrencyTransaction(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        denominationValue: denomination.value,
        denominationId: denomination.id,
        quantity: quantity,
        transactionType: type,
        totalAmount: denomination.value * quantity,
        reason: reason,
        timestamp: timestamp ?? DateTime.now(),
        lastModified: DateTime.now(),
        syncStatus: _syncService.isOnline
            ? SyncStatus.synced
            : SyncStatus.pending,
        groupId: _groupId!,
      );

      print(
        'AppProvider: Transaction created with groupId = ${transaction.groupId}',
      );

      if (_syncService.isOnline) {
        await _firestoreService.addTransactionAndUpdateInventory(
          transaction,
          denomination.id,
          groupId: _groupId!,
        );
        print('AppProvider: Transaction saved to Firestore');
      } else {
        // Queue for later sync
        await _syncService.queueTransaction(transaction);
        // Update local inventory immediately for offline experience
        // Note: The actual Firestore inventory will be updated when synced
      }

      _clearError();
    } catch (e) {
      print('AppProvider: Error adding transaction: $e');
      _setError('Failed to add transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTransaction({
    required CurrencyTransaction transaction,
    required User user,
    required Denomination denomination,
    required int quantity,
    required TransactionType type,
    String? reason,
  }) async {
    _setLoading(true);
    try {
      print('AppProvider: Updating transaction ${transaction.id}');
      print(
        'AppProvider: Old quantity: ${transaction.quantity}, New quantity: $quantity',
      );

      final updated = transaction.copyWith(
        userId: user.id,
        userName: user.name,
        denominationValue: denomination.value,
        denominationId: denomination.id,
        quantity: quantity,
        transactionType: type,
        totalAmount: denomination.value * quantity,
        reason: reason,
        lastModified: DateTime.now(),
      );

      if (_syncService.isOnline) {
        await _firestoreService.updateTransaction(updated);
        print('AppProvider: Transaction updated in Firestore');

        // Recalculate inventory in background (don't await to avoid blocking UI)
        _firestoreService
            .recalculateInventoryFromTransactions(groupId: _groupId!)
            .then((_) {
              print('AppProvider: Inventory recalculated in background');
              // The inventory stream will automatically update _inventory
            })
            .catchError((e) {
              print('AppProvider: Error recalculating inventory: $e');
            });
      } else {
        _setError('Cannot edit transaction while offline');
      }

      _clearError();
    } catch (e) {
      print('AppProvider: Error updating transaction: $e');
      _setError('Failed to update transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTransaction(CurrencyTransaction transaction) async {
    _setLoading(true);
    try {
      if (_syncService.isOnline) {
        await _firestoreService.deleteTransaction(transaction.id);
        // Recalculate inventory in background (don't await to avoid blocking UI)
        _firestoreService
            .recalculateInventoryFromTransactions(groupId: _groupId!)
            .then((_) {
              print('AppProvider: Inventory recalculated after deletion');
            })
            .catchError((e) {
              print('AppProvider: Error recalculating inventory: $e');
            });
      } else {
        _setError('Cannot delete transaction while offline');
      }

      _clearError();
    } catch (e) {
      _setError('Failed to delete transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Delete all transactions (admin only)
  Future<bool> deleteAllTransactions() async {
    _setLoading(true);
    try {
      if (!_syncService.isOnline) {
        _setError('Cannot delete all transactions while offline');
        _setLoading(false);
        return false;
      }

      await _ensureGroupIdLoaded();

      print('AppProvider: Deleting all transactions for groupId: $_groupId');

      // Get ALL transactions for the group (not just the filtered local list)
      final allTransactions = await _firestoreService.getAllTransactions(
        groupId: _groupId!,
      );

      print(
        'AppProvider: Found ${allTransactions.length} transactions to delete',
      );

      // Delete all transactions
      for (var transaction in allTransactions) {
        await _firestoreService.deleteTransaction(transaction.id);
      }

      print('AppProvider: All transactions deleted, resetting inventory');

      // Reset inventory to zero with groupId
      final emptyInventory = Inventory(groupId: _groupId!);
      await _firestoreService.updateInventory(
        emptyInventory,
        groupId: _groupId!,
      );

      print(
        'AppProvider: Empty inventory updated: ${emptyInventory.denominationCounts}',
      );

      // Force refresh local inventory to ensure UI updates
      _inventory = emptyInventory;
      notifyListeners();

      _clearError();
      _setLoading(false);
      return true;
    } catch (e) {
      print('AppProvider: Error deleting all transactions: $e');
      _setError('Failed to delete all transactions: $e');
      _setLoading(false);
      return false;
    }
  }

  // Recalculate inventory from all transactions
  Future<void> recalculateInventory() async {
    try {
      await _ensureGroupIdLoaded();

      if (_syncService.isOnline) {
        await _firestoreService.recalculateInventoryFromTransactions(
          groupId: _groupId!,
        );
        _clearError();
      }
    } catch (e) {
      _setError('Failed to recalculate inventory: $e');
    }
  }

  // ===== DATE FILTER =====

  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    notifyListeners();
  }

  void clearDateFilter() {
    _filterStartDate = null;
    _filterEndDate = null;
    notifyListeners();
  }

  void setTodayFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setDateFilter(today, today);
  }

  void setThisWeekFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    setDateFilter(weekStart, today);
  }

  void setThisMonthFilter() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    setDateFilter(monthStart, today);
  }

  // ===== CALCULATED VALUES =====

  double getTotalBalance() {
    final denominationValues = {for (var d in _denominations) d.id: d.value};
    final total = (_inventory ?? Inventory(groupId: _groupId ?? 'unknown'))
        .calculateTotalValue(denominationValues);
    print('AppProvider: getTotalBalance() = $total');
    print('AppProvider: Inventory counts: ${_inventory?.denominationCounts}');
    print('AppProvider: Denomination values map: $denominationValues');
    return total;
  }

  // Get total balance for the currently selected user
  double getUserBalance() {
    if (_selectedUser == null) return 0.0;

    double balance = 0.0;
    for (final transaction in userTransactions) {
      if (transaction.transactionType == TransactionType.added) {
        balance += transaction.totalAmount;
      } else {
        balance -= transaction.totalAmount;
      }
    }
    return balance;
  }

  Map<Denomination, int> getDenominationBreakdown() {
    final breakdown = <Denomination, int>{};
    final inventory = _inventory ?? Inventory(groupId: _groupId ?? 'unknown');

    print('AppProvider: getDenominationBreakdown()');
    print('AppProvider: Inventory counts: ${inventory.denominationCounts}');
    print('AppProvider: Total denominations: ${_denominations.length}');

    for (final denomination in _denominations) {
      final count = inventory.getCount(denomination.id);
      print(
        'AppProvider: Denom ${denomination.value} (${denomination.id}): count = $count, isActive = ${denomination.isActive}',
      );
      if (count > 0) {
        breakdown[denomination] = count;
      }
    }

    // Calculate total from breakdown for verification
    double breakdownTotal = 0;
    breakdown.forEach((denom, count) {
      breakdownTotal += denom.value * count;
    });
    print('AppProvider: Breakdown total: $breakdownTotal');
    print('AppProvider: Breakdown size: ${breakdown.length} items');

    return breakdown;
  }

  // Get denomination breakdown for the currently selected user
  Map<Denomination, int> getUserDenominationBreakdown() {
    if (_selectedUser == null) return {};

    final breakdown = <String, int>{};

    // Calculate from user's transactions
    for (final transaction in userTransactions) {
      final denomId = transaction.denominationId;
      final currentCount = breakdown[denomId] ?? 0;

      if (transaction.transactionType == TransactionType.added) {
        breakdown[denomId] = currentCount + transaction.quantity;
      } else {
        breakdown[denomId] = currentCount - transaction.quantity;
      }
    }

    // Convert to Denomination map
    final result = <Denomination, int>{};
    for (final denomination in _denominations) {
      final count = breakdown[denomination.id] ?? 0;
      if (count > 0) {
        result[denomination] = count;
      }
    }
    return result;
  }

  // ===== PRIVATE METHODS =====

  Future<void> _cancelSubscriptions() async {
    await _usersSubscription?.cancel();
    await _denominationsSubscription?.cancel();
    await _transactionsSubscription?.cancel();
    await _inventorySubscription?.cancel();
  }

  void _subscribeToStreams() {
    print('AppProvider: Subscribing to streams with groupId = $_groupId');

    // Only subscribe to group-related streams if groupId is available
    if (_groupId == null || _groupId!.isEmpty) {
      print(
        'AppProvider: WARNING - Cannot subscribe to streams without valid groupId',
      );
      return;
    }

    _usersSubscription = _firestoreService.streamUsers().listen((users) {
      _users = users;
      // Auto-select user based on Firebase Auth UID
      if (_selectedUser == null) {
        final firebaseUser = auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          // Try to find user by Firebase UID
          final matchingUser = users.where(
            (u) => u.firebaseUid == firebaseUser.uid,
          );
          if (matchingUser.isNotEmpty) {
            _selectedUser = matchingUser.first;
            _prefs.setString('selected_user_id', _selectedUser!.id);
            print(
              'AppProvider: Auto-selected user ${_selectedUser!.name} based on Firebase UID',
            );
          } else {
            // Fallback: try to match by saved user ID
            final userId = _prefs.getString('selected_user_id');
            if (userId != null) {
              final savedUser = users.where((u) => u.id == userId);
              if (savedUser.isNotEmpty) {
                _selectedUser = savedUser.first;
                print(
                  'AppProvider: Selected user ${_selectedUser!.name} from saved preferences',
                );
              }
            }
          }
        }
      }
      notifyListeners();
    });

    _denominationsSubscription = _firestoreService
        .streamDenominations(groupId: _groupId!)
        .listen((denominations) {
          print(
            'AppProvider: Received ${denominations.length} denominations for groupId $_groupId',
          );
          _denominations = denominations;
          notifyListeners();
        });

    _transactionsSubscription = _firestoreService
        .streamTransactions(
          startDate: _filterStartDate,
          endDate: _filterEndDate,
          groupId: _groupId!,
        )
        .listen((transactions) {
          print(
            'AppProvider: Received ${transactions.length} transactions for groupId $_groupId',
          );
          _transactions = transactions;
          notifyListeners();
        });

    _inventorySubscription = _firestoreService
        .streamInventory(groupId: _groupId!)
        .listen((inventory) {
          print('AppProvider: Received inventory for groupId $_groupId');
          _inventory = inventory;
          notifyListeners();
        });
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Sync pending transactions
  Future<void> syncNow() async {
    await _syncService.syncPendingTransactions();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelSubscriptions(); // Don't await here, just call it
    super.dispose();
  }
}
