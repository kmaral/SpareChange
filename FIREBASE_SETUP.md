# Firebase Setup Instructions

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or "Create a project"
3. Enter project name: **SpareChange** (or your preferred name)
4. Disable Google Analytics (optional for this project)
5. Click "Create project"

## Step 2: Add Android App

1. In Firebase Console, click the Android icon to add Android app
2. Enter Android package name: `com.example.spare_change`
3. App nickname: `SpareChange Android`
4. Skip SHA-1 certificate (not needed for this project)
5. Click "Register app"
6. Download `google-services.json`
7. Place the file in: `android/app/google-services.json`
8. Follow the SDK configuration steps:
   - Edit `android/build.gradle` - add classpath
   - Edit `android/app/build.gradle` - add plugin
9. Click "Continue to console"

## Step 3: Add iOS App (Optional, if testing on iOS)

1. In Firebase Console, click the iOS icon to add iOS app
2. Enter iOS bundle ID: `com.example.spareChange`
3. App nickname: `SpareChange iOS`
4. Download `GoogleService-Info.plist`
5. Place the file in: `ios/Runner/GoogleService-Info.plist`
6. Click "Continue to console"

## Step 4: Enable Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Select "Start in **test mode**" (we'll set proper rules later)
4. Choose Cloud Firestore location: `asia-south1` (Mumbai) or nearest region
5. Click "Enable"

## Step 5: Enable Authentication

1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable the following providers:
   - **Email/Password**: Click, toggle "Enable", Save
   - **Google**: Click, toggle "Enable", enter support email, Save

### Configure Google Sign-In (Android)

1. Add SHA-1 certificate fingerprint:
   ```bash
   # For debug build
   keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
2. Copy the SHA-1 fingerprint
3. Go to Firebase Console > Project Settings > Your apps > Android app
4. Add the SHA-1 fingerprint
5. Download the updated `google-services.json` and replace in `android/app/`

## Step 6: Configure Firestore Security Rules

Go to Firestore Database > Rules and replace with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Authenticated users only
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /groups/{groupId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.members;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       request.auth.uid in resource.data.members;
      allow delete: if request.auth != null && 
                       request.auth.uid == resource.data.createdBy;
    }
    
    match /denominations/{denominationId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    match /transactions/{transactionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
                               request.auth.uid == resource.data.userId;
    }
    
    match /inventory/{inventoryId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Click "Publish" to save the rules.

## Step 7: Update Android Gradle Files

### android/build.gradle
Add to dependencies block:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

### android/app/build.gradle
Add at the bottom of the file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## Step 8: Test the Setup

Run the app:
```bash
flutter run
```

Check the console for successful Firebase initialization message.

## Authentication Flow

1. **Unauthenticated**: User sees empty dashboard with "Add Transaction" button
2. **Click Add Transaction**: Opens authentication screen
3. **Sign In/Sign Up**: Via Google or Email/Password
4. **Group Setup**: After authentication, user creates or joins a group (max 6 members)
5. **Dashboard**: Full app access with transactions and denomination tracking

## Database Structure

The app will create these collections:

- **/users**: User profiles
  - uid (auth UID), email, displayName, photoURL, createdAt, groupId

- **/groups**: User groups (max 6 members)
  - name, createdBy, createdAt, members (array of UIDs), maxMembers

- **/denominations**: Currency denominations
  - id, value, type (coin/note), isActive, createdAt

- **/transactions**: All currency transactions
  - id, userId, userName, denominationValue, quantity, transactionType, totalAmount, reason, timestamp, lastModified, syncStatus

- **/inventory**: Current denomination counts
  - denominationId → count

## Group Management

- **Create Group**: User creates a new group with a custom name and becomes the creator
- **Join Group**: User enters a Group ID to join an existing group (if not full)
- **Group ID Sharing**: Copy Group ID from Settings to share with others
- **Member Limit**: Maximum 6 members per group
- **View Members**: See all group members with their names and emails

## Offline Support

Firestore offline persistence is enabled by default in the app. Data will sync automatically when the device comes online.
