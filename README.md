# Spare Change - Currency Tracker App

A Flutter application for tracking Indian currency denominations, fully offline and stored on-device. Manage your cash inventory, track money added/taken, and maintain an accurate balance across different currency denominations — no account, no cloud.

## Features

- **Denomination Management**: Add/remove coins and notes dynamically
- **Transaction Tracking**: Record when money is added or taken with:
  - Denomination and quantity
  - Timestamp (automatically recorded)
  - Optional reason/note
- **Denomination Breakdown Chart**: Visual display with authentic Indian currency note colors
- **Real-time Balance**: View total balance and breakdown by denomination
- **Transaction History**: Filter transactions by date range (today, this week, this month, custom)
- **Edit/Delete Transactions**: Modify or remove past transactions with automatic inventory recalculation
- **Soft Delete Protection**: Prevent deletion of denominations with existing transactions
- **Withdrawal Validation**: Prevents taking more denominations than available in inventory
- **Fully Offline**: All data lives on-device in a local Hive database; nothing leaves the phone

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── denomination.dart     # Currency denomination model
│   ├── transaction.dart      # Transaction model
│   └── inventory.dart        # Inventory management model
├── services/
│   ├── local_storage_service.dart # Local Hive-backed datastore
│   └── admob_service.dart         # Ad banner initialization
├── providers/
│   └── app_provider.dart       # State management with Provider
├── widgets/
│   └── denomination_chart.dart # Visual denomination breakdown
└── screens/
    ├── home_screen.dart                    # Main dashboard
    ├── denomination_settings_screen.dart   # Manage denominations
    ├── settings_screen.dart                # App settings
    ├── transactions_screen.dart            # Transaction history
    ├── add_transaction_screen.dart         # Add/Take money form
    └── transaction_detail_screen.dart      # View/Edit transaction details
```

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.9.2 or later)
- Dart SDK (3.9.2 or later)
- Android Studio / VS Code with Flutter extensions

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

## Usage Guide

### First Time Setup

1. **Launch the app** - INR denominations (₹10, ₹20, ₹50, ₹100, ₹200, ₹500) are created automatically
2. **Add more denominations if needed** - Go to Settings → Manage Denominations
3. **Start tracking** - Use Add (+) or Take (-) buttons to record transactions

### Adding Money

1. Tap the green "Add" button
2. Choose denomination
3. Enter quantity
4. Add optional reason
5. Tap "Add Money"

### Taking Money

1. Tap the red "Take" button
2. Choose denomination
3. Enter quantity
4. Add optional reason (e.g., "groceries", "transport")
5. Tap "Take Money"

### Viewing Transactions

- All transactions appear on the home screen
- Tap any transaction to view details
- Edit or delete from the detail screen

### Filtering Transactions

Use the filter chips at the top:
- **All** - Show all transactions
- **Today** - Show today's transactions
- **This Week** - Show current week
- **This Month** - Show current month
- **Custom** - Pick custom date range

### Managing Denominations

1. Go to Settings (⚙️ icon) → Manage Denominations
2. **Add denomination**: Tap the + button
   - Enter value (e.g., 1, 2, 5, 10, 20)
   - Select Coin or Note
3. **Deactivate**: Toggle the switch (keeps existing transactions)
4. **Delete**: Tap delete icon (only if no transactions exist)

## Local Storage

All data is stored on-device using [Hive](https://pub.dev/packages/hive), split across three boxes:

- `denominations` - Available denominations
- `transactions` - All money transactions
- `inventory` - Current denomination counts (single record)

## Development

### Regenerate Hive Type Adapters

Required after changing any `@HiveType`/`@HiveField` model:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Technologies Used

- **Flutter** - Cross-platform UI framework
- **Provider** - State management
- **Hive** - Local on-device storage
- **SharedPreferences** - Persistent key-value storage (theme, currency)
- **Intl** - Date/time formatting
- **UUID** - Unique ID generation

## Future Enhancements

- [ ] Export transactions to CSV/Excel
- [ ] Charts and analytics (spending patterns)
- [ ] Notifications for low balance
- [ ] Multiple currency support
- [ ] Backup/restore functionality
- [ ] Biometric app lock

## License

This project is created for personal/educational use.

## Support

For issues or questions, please create an issue in the repository.
