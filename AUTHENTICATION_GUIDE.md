# Authentication & Group Management Implementation

## Overview
This document describes the authentication and group management features added to Spare Change.

## Features Implemented

### 1. Authentication Flow

#### Unauthenticated State
- Shows empty dashboard with app logo and welcome message
- Single "Add Transaction" button prompts authentication
- No denomination or transaction data displayed

#### Authentication Screen
- **Google Sign-In**: One-tap authentication with Google account
- **Email/Password Sign-In**: Traditional login with email and password
- **Email/Password Sign-Up**: Create new account with name, email, and password
- Toggle between Sign In and Sign Up modes
- Automatic user document creation in Firestore

#### Post-Authentication Flow
- If user has no group → Redirect to Group Setup
- If user has a group → Show full dashboard

### 2. Group Management

#### Group Setup Screen
- **Create New Group**: 
  - Enter group name (e.g., "Family Savings")
  - Auto-assigns current user as creator
  - Generates unique group ID
  
- **Join Existing Group**:
  - Enter group ID shared by another member
  - Validates group exists and has space
  - Maximum 6 members per group

#### Group Features in Settings
- View current group name and members
- Copy group ID to share with others
- See member details (name, email, photo)
- Member count display (e.g., "3/6 members")
- Sign out option

### 3. Security

#### Firestore Security Rules
- Authentication required for all operations
- Users can only write their own user document
- Group members can read/write group data
- Only group creators can delete groups
- Transaction ownership validation

#### User Privacy
- User data stored securely in Firestore
- Email/password encrypted by Firebase Auth
- Photo URLs from Google Sign-In

## File Structure

```
lib/
├── services/
│   └── auth_service.dart           # Authentication & group management logic
├── screens/
│   ├── auth_screen.dart           # Sign in/sign up UI
│   ├── group_setup_screen.dart    # Create/join group UI
│   ├── home_screen.dart           # Updated with auth state handling
│   └── settings_screen.dart       # Updated with account & group info
└── main.dart                      # StreamBuilder for auth state
```

## Key Code Components

### AuthService (lib/services/auth_service.dart)
- `signInWithGoogle()` - Google OAuth flow
- `signInWithEmail()` - Email/password login
- `signUpWithEmail()` - New account creation
- `createGroup()` - Creates new group, max 6 members
- `joinGroup()` - Adds user to existing group
- `getGroupMembers()` - Fetches all group member details
- `getUserGroup()` - Gets user's current group
- `signOut()` - Signs out from Firebase Auth and Google

### Main App Flow (lib/main.dart)
```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    // Not authenticated → Empty dashboard
    // Authenticated but no group → Group setup
    // Authenticated with group → Full dashboard
  }
)
```

### Home Screen (lib/screens/home_screen.dart)
- Empty state for unauthenticated users
- "Add Transaction" button opens auth screen
- Full dashboard for authenticated users with group

### Settings Screen (lib/screens/settings_screen.dart)
- Account section with user info
- Group details and member management
- Copy group ID functionality
- Sign out option

## Database Schema

### users Collection
```json
{
  "uid": "firebase_auth_uid",
  "email": "user@example.com",
  "displayName": "John Doe",
  "photoURL": "https://...",
  "createdAt": "Timestamp",
  "groupId": "group_document_id"
}
```

### groups Collection
```json
{
  "name": "Family Savings",
  "createdBy": "creator_uid",
  "createdAt": "Timestamp",
  "members": ["uid1", "uid2", "uid3"],
  "maxMembers": 6
}
```

## User Journey

### First Time User
1. Opens app → Sees empty dashboard
2. Clicks "Add Transaction" → Opens Auth Screen
3. Signs in with Google or Email → Authenticated
4. No group → Opens Group Setup Screen
5. Creates/joins group → Dashboard loads
6. Can now add transactions and manage denominations

### Returning User
1. Opens app → Auto-authenticates
2. Has group → Directly to Dashboard
3. Full access to all features

### Inviting Members
1. Go to Settings → Account section
2. Tap on "Group" to see members
3. Tap "Copy" icon next to Group ID
4. Share Group ID via any messaging app
5. New member opens app → Auth → Join Group → Paste ID

## Dependencies Added

```yaml
firebase_auth: ^5.4.2        # Firebase Authentication
google_sign_in: ^6.2.3       # Google OAuth integration
```

## Configuration Required

### Firebase Console
1. Enable Authentication (Email/Password + Google)
2. Add SHA-1 fingerprint for Google Sign-In
3. Update Firestore security rules
4. Download updated google-services.json

### Android (google-services.json)
- Place in `android/app/google-services.json`
- Contains OAuth client IDs for Google Sign-In

## Testing Checklist

- [ ] Unauthenticated user sees empty dashboard
- [ ] "Add Transaction" opens auth screen
- [ ] Google Sign-In works and creates user
- [ ] Email/Password Sign-In works
- [ ] Email/Password Sign-Up creates account
- [ ] Group creation assigns user to group
- [ ] Group joining validates and adds member
- [ ] Group member limit (6) enforced
- [ ] Group ID can be copied
- [ ] Member list displays correctly
- [ ] Sign out returns to empty dashboard
- [ ] Settings shows account info
- [ ] Re-authentication persists session

## Future Enhancements

- Group admin features (remove members)
- Group leave functionality
- Multiple group support per user
- Group transaction permissions
- Push notifications for group activities
- Profile picture upload
- Password reset functionality
