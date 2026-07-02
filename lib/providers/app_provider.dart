import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/denomination.dart';
import '../models/transaction.dart';
import '../models/inventory.dart';
import '../services/local_storage_service.dart';

class AppProvider with ChangeNotifier {
  final LocalStorageService _localStorageService;
  final SharedPreferences _prefs;

  List<Denomination> _denominations = [];
  List<CurrencyTransaction> _allTransactions = [];
  Inventory _inventory = Inventory();

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _currency = 'INR';

  bool _isLoading = false;
  String? _error;
  String _themeMode = 'System';

  AppProvider({
    required LocalStorageService localStorageService,
    required SharedPreferences prefs,
  }) : _localStorageService = localStorageService,
       _prefs = prefs {
    _loadThemeMode();
    _loadCurrency();
    _loadAll();
  }

  // Getters
  List<Denomination> get denominations => _denominations;
  List<Denomination> get activeDenominations =>
      _denominations.where((d) => d.isActive).toList();

  List<CurrencyTransaction> get transactions {
    if (_filterStartDate == null && _filterEndDate == null) {
      return _allTransactions;
    }
    return _allTransactions.where((t) {
      if (_filterStartDate != null && t.timestamp.isBefore(_filterStartDate!)) {
        return false;
      }
      if (_filterEndDate != null) {
        final endOfDay = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
          23,
          59,
          59,
          999,
        );
        if (t.timestamp.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();
  }

  Inventory get inventory => _inventory;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get themeMode => _themeMode;
  String get currency => _currency;

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

  void _loadAll() {
    _denominations = _localStorageService.getDenominations();
    _allTransactions = _localStorageService.getTransactions();
    _inventory = _localStorageService.getInventory();
    notifyListeners();
  }

  void _loadThemeMode() {
    _themeMode = _prefs.getString('themeMode') ?? 'System';
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs.setString('themeMode', mode);
    notifyListeners();
  }

  void _loadCurrency() {
    _currency = _prefs.getString('currency') ?? 'INR';
  }

  Future<bool> updateCurrency(String currency) async {
    try {
      _currency = currency;
      await _prefs.setString('currency', currency);

      // If changed to INR, auto-create denominations; otherwise remove the auto-created ones
      if (currency == 'INR') {
        await autoCreateINRDenominations();
      } else {
        await deleteAutoCreatedDenominations();
      }

      notifyListeners();
      return true;
    } catch (e) {
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

  // ===== DENOMINATION OPERATIONS =====

  // Auto-create INR denominations if none exist yet
  Future<void> autoCreateINRDenominations() async {
    final hasAutoCreated = _denominations.any((d) => d.isAutoCreated);
    if (hasAutoCreated) return;

    final inrValues = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];

    for (final value in inrValues) {
      final exists = _denominations.any((d) => d.value == value);
      if (!exists) {
        final denomination = Denomination(
          id: const Uuid().v4(),
          value: value,
          type: DenominationType.note,
          isActive: true,
          isAutoCreated: true,
        );
        await _localStorageService.addDenomination(denomination);
      }
    }

    _denominations = _localStorageService.getDenominations();
    notifyListeners();
  }

  // Delete all auto-created denominations
  Future<void> deleteAutoCreatedDenominations() async {
    final autoCreatedDenoms = _denominations
        .where((d) => d.isAutoCreated)
        .toList();

    for (final denom in autoCreatedDenoms) {
      await _localStorageService.deleteDenomination(denom.id);
    }

    _denominations = _localStorageService.getDenominations();
    notifyListeners();
  }

  Future<void> addDenomination(double value, DenominationType type) async {
    _setLoading(true);
    try {
      final exists = _denominations.any(
        (d) => d.value == value && d.type == type,
      );
      if (exists) {
        final typeName = type == DenominationType.coin ? 'coin' : 'note';
        _setError('$typeName with value ₹$value already exists');
        return;
      }

      final denomination = Denomination(
        id: const Uuid().v4(),
        value: value,
        type: type,
        isActive: true,
        isAutoCreated: false,
      );

      await _localStorageService.addDenomination(denomination);
      _denominations = _localStorageService.getDenominations();
      _clearError();
    } catch (e) {
      _setError('Failed to add denomination: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleDenominationActive(Denomination denomination) async {
    _setLoading(true);
    try {
      final updated = denomination.copyWith(isActive: !denomination.isActive);
      await _localStorageService.updateDenomination(updated);
      _denominations = _localStorageService.getDenominations();
    } catch (e) {
      _setError('Failed to update denomination: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDenomination(String denominationId) async {
    _setLoading(true);
    try {
      final hasTransactions = _localStorageService.hasDenominationTransactions(
        denominationId,
      );
      if (hasTransactions) {
        return false; // Return false to show warning dialog
      }

      await _localStorageService.deleteDenomination(denominationId);
      _denominations = _localStorageService.getDenominations();
      return true;
    } catch (e) {
      _setError('Failed to delete denomination: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== TRANSACTION OPERATIONS =====

  Future<void> addTransaction({
    required Denomination denomination,
    required int quantity,
    required TransactionType type,
    String? reason,
    DateTime? timestamp,
  }) async {
    _setLoading(true);
    try {
      final transaction = CurrencyTransaction(
        id: const Uuid().v4(),
        denominationValue: denomination.value,
        denominationId: denomination.id,
        quantity: quantity,
        transactionType: type,
        totalAmount: denomination.value * quantity,
        reason: reason,
        timestamp: timestamp ?? DateTime.now(),
        lastModified: DateTime.now(),
      );

      _inventory = await _localStorageService.addTransactionAndUpdateInventory(
        transaction,
      );
      _allTransactions = _localStorageService.getTransactions();
      _clearError();
    } catch (e) {
      _setError('Failed to add transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTransaction({
    required CurrencyTransaction transaction,
    required Denomination denomination,
    required int quantity,
    required TransactionType type,
    String? reason,
  }) async {
    _setLoading(true);
    try {
      final updated = transaction.copyWith(
        denominationValue: denomination.value,
        denominationId: denomination.id,
        quantity: quantity,
        transactionType: type,
        totalAmount: denomination.value * quantity,
        reason: reason,
        lastModified: DateTime.now(),
      );

      await _localStorageService.updateTransaction(updated);
      _allTransactions = _localStorageService.getTransactions();
      _inventory = await _localStorageService.recalculateInventoryFromTransactions();
      _clearError();
    } catch (e) {
      _setError('Failed to update transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTransaction(CurrencyTransaction transaction) async {
    _setLoading(true);
    try {
      await _localStorageService.deleteTransaction(transaction.id);
      _allTransactions = _localStorageService.getTransactions();
      _inventory = await _localStorageService.recalculateInventoryFromTransactions();
      _clearError();
    } catch (e) {
      _setError('Failed to delete transaction: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Delete all transactions
  Future<bool> deleteAllTransactions() async {
    _setLoading(true);
    try {
      await _localStorageService.deleteAllTransactions();
      _allTransactions = [];
      _inventory = Inventory();
      await _localStorageService.saveInventory(_inventory);
      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to delete all transactions: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Recalculate inventory from all transactions
  Future<void> recalculateInventory() async {
    try {
      _inventory = await _localStorageService.recalculateInventoryFromTransactions();
      _clearError();
      notifyListeners();
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
    return _inventory.calculateTotalValue(denominationValues);
  }

  Map<Denomination, int> getDenominationBreakdown() {
    final breakdown = <Denomination, int>{};
    for (final denomination in _denominations) {
      final count = _inventory.getCount(denomination.id);
      if (count > 0) {
        breakdown[denomination] = count;
      }
    }
    return breakdown;
  }

  // ===== PRIVATE METHODS =====

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
}
