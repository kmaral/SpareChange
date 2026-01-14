# Spare Change - Currency Tracker App

A Flutter application for tracking Indian currency denominations with multi-user support, Firebase synchronization, and group collaboration. Manage your cash inventory, track who took/added money, and maintain an accurate balance across different currency denominations.

## Features

### Authentication & Groups
- **Google Sign-In**: Quick authentication with Google account
- **Email/Password Auth**: Traditional sign-up and login
- **Group Management**: Create or join groups (max 6 members per group)
- **Group Sharing**: Share group ID to invite members
- **Member View**: See all group members with details

### Core Features
- **Multi-User Support**: Create multiple user profiles with custom avatars
- **Denomination Management**: Add/remove coins and notes dynamically
- **Transaction Tracking**: Record when money is added or taken with:
  - User who performed the action
  - Denomination and quantity
  - Timestamp (automatically recorded)
  - Optional reason/note
- **Denomination Breakdown Chart**: Visual display with authentic Indian currency note colors
- **Real-time Balance**: View total balance and breakdown by denomination
- **Transaction History**: Filter transactions by date range (today, this week, this month, custom)
- **Edit/Delete Transactions**: Modify or remove past transactions with automatic inventory recalculation
- **Offline Support**: Queue transactions when offline and sync automatically when connection is restored
- **Soft Delete Protection**: Prevent deletion of denominations/users with existing transactions
- **Withdrawal Validation**: Prevents taking more denominations than available in inventory

## Project Structure

```
lib/
├── main.dart                 # App entry point with auth state management
├── models/
│   ├── denomination.dart     # Currency denomination model
│   ├── user.dart             # User profile model
│   ├── transaction.dart      # Transaction model
│   └── inventory.dart        # Inventory management model
├── services/
│   ├── auth_service.dart       # Firebase Authentication & group management
│   ├── firestore_service.dart  # Firebase Firestore operations
│   └── sync_service.dart       # Offline sync & Hive local storage
├── providers/
│   └── app_provider.dart       # State management with Provider
├── widgets/
│   └── denomination_chart.dart # Visual denomination breakdown
└── screens/
    ├── auth_screen.dart                    # Sign in/sign up
    ├── group_setup_screen.dart             # Create/join group
    ├── home_screen.dart                    # Main dashboard
    ├── user_selector_screen.dart           # User selection/creation
    ├── denomination_settings_screen.dart   # Manage denominations
    ├── settings_screen.dart                # App & account settings
    ├── transactions_screen.dart            # Transaction history
    ├── add_transaction_screen.dart         # Add/Take money form
    └── transaction_detail_screen.dart      # View/Edit transaction details
```

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.9.2 or later)
- Dart SDK (3.9.2 or later)
- Firebase account
- Android Studio / VS Code with Flutter extensions

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Follow the detailed instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to:
1. Create a Firebase project
2. Add Android/iOS apps
3. Download and place configuration files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist` (if building for iOS)
4. Enable Firestore Database
5. Configure security rules

### 4. Run the App

```bash
flutter run
```

## Usage Guide

### First Time Setup

1. **Launch the app** - You'll see an empty home screen
2. **Add a user** - Tap "Select User" → "Add User"
   - Enter name and select a color
3. **Add denominations** - Go to Settings (⚙️ icon)
   - Add coins: ₹1, ₹2, ₹5, ₹10
   - Add notes: ₹20, ₹50, ₹100, ₹200, ₹500, ₹2000
4. **Start tracking** - Use Add (+) or Take (-) buttons to record transactions

### Adding Money

1. Tap the green "Add" button
2. Select user (if not already selected)
3. Choose denomination
4. Enter quantity
5. Add optional reason
6. Tap "Add Money"

### Taking Money

1. Tap the red "Take" button
2. Select user (if not already selected)
3. Choose denomination
4. Enter quantity
5. Add optional reason (e.g., "groceries", "transport")
6. Tap "Take Money"

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

1. Go to Settings (⚙️ icon)
2. **Add denomination**: Tap the + button
   - Enter value (e.g., 1, 2, 5, 10, 20)
   - Select Coin or Note
3. **Deactivate**: Toggle the switch (keeps existing transactions)
4. **Delete**: Tap delete icon (only if no transactions exist)

### Managing Users

1. Tap "Select User" or "Change" button
2. View all users in a grid
3. **Add new user**: Tap the + button
4. **Select user**: Tap any user card
5. **Note**: Cannot delete users with existing transactions

## Offline Support

- **Automatic queue**: When offline, transactions are saved locally
- **Auto-sync**: When connection is restored, transactions sync automatically
- **Status indicator**: Top bar shows offline status and pending sync count
- **Manual sync**: Pull down to refresh when back online

## Firebase Collections

The app uses the following Firestore collections:

- `/users` - User profiles
- `/denominations` - Available denominations
- `/transactions` - All money transactions
- `/inventory/current` - Current denomination counts

## Development

### Generate Hive Type Adapters (if needed)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Common Issues

**Problem**: "Target of URI hasn't been generated" errors  
**Solution**: The app includes manual Hive adapters, so this warning can be ignored. If you prefer generated adapters, uncomment the `part` directives and run the build_runner command above.

**Problem**: Firebase initialization fails  
**Solution**: Ensure google-services.json (Android) or GoogleService-Info.plist (iOS) is correctly placed and Firebase is properly configured.

**Problem**: Transactions not syncing  
**Solution**: Check internet connection, verify Firestore security rules allow read/write access.

## Technologies Used

- **Flutter** - Cross-platform UI framework
- **Firebase Core** - Firebase initialization
- **Cloud Firestore** - Real-time database and sync
- **Provider** - State management
- **Hive** - Local storage for offline support
- **SharedPreferences** - Persistent key-value storage
- **Connectivity Plus** - Network connectivity detection
- **Intl** - Date/time formatting
- **UUID** - Unique ID generation

## Future Enhancements

- [ ] Export transactions to CSV/Excel
- [ ] Charts and analytics (spending patterns)
- [ ] Notifications for low balance
- [ ] Multiple currency support
- [ ] Backup/restore functionality
- [ ] Dark mode
- [ ] Biometric authentication
- [ ] Recurring transactions

## License

This project is created for personal/educational use.

## Support

For issues or questions, please create an issue in the repository.
