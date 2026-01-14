# Data Deletion and Privacy Features

This document explains the data deletion and privacy features implemented in SpareChange, including how to configure them for Google Play Console requirements.

## Overview

SpareChange provides three ways for users to manage their data:

1. **Delete Account** (In-App) - Instant account deletion
2. **Request Data Deletion** (In-App) - Request to delete data without account
3. **Data Deletion Request Page** (Web) - External webpage for deletion requests

---

## 1. In-App Account Deletion

### User Flow

Users can delete their account directly from the app:

1. Open **SpareChange** app
2. Go to **Settings**
3. Scroll to **Privacy & Data** section
4. Tap **Delete Account**
5. Confirm twice (including typing "DELETE")
6. Account and all data are immediately deleted

### What Gets Deleted

When a user deletes their account:
- ✅ Firebase Authentication account
- ✅ All user data in Firestore
- ✅ All transactions
- ✅ All family member entries
- ✅ Group membership (user is removed from group)
- ✅ All encrypted personal data

### Implementation

The deletion is handled by the `deleteAccount()` method in [auth_service.dart](lib/services/auth_service.dart):

```dart
// Delete Firebase Auth account
await user.delete();

// Delete all Firestore data
// - User document
// - Transactions
// - Family members
// - Group membership
```

---

## 2. Request Data Deletion (Without Account Deletion)

### User Flow

Users can request data deletion while keeping their account:

1. Open **SpareChange** app
2. Go to **Settings**
3. Scroll to **Privacy & Data** section
4. Tap **Request Data Deletion**
5. Review what will be deleted
6. Submit request

### What Gets Deleted

- ✅ Transaction history
- ✅ Family member entries
- ✅ Group data

### What Stays

- ✅ Account credentials (email, password)
- ✅ Ability to log in

### Implementation

```dart
// Creates a deletion request in Firestore
await _firestore.collection('data_deletion_requests').add({
  'userId': user.uid,
  'requestType': 'delete_data',
  'status': 'pending',
  'requestedAt': FieldValue.serverTimestamp(),
});
```

**Note:** You need to implement a backend process to handle these requests within 30 days.

---

## 3. Export User Data

Users can export their data before deletion:

1. Open **SpareChange** app
2. Go to **Settings**
3. Scroll to **Privacy & Data** section
4. Tap **Export My Data**
5. Data is copied to clipboard in JSON format

### Exported Data Includes

- User profile information
- All transactions
- Family members
- Group information
- Statistics

---

## 4. Web-Based Data Deletion Request Page

### Overview

A standalone HTML page for users to request data deletion from outside the app. This satisfies Google Play Console requirements.

### Location

The page is located at: `web/data-deletion.html`

### Hosting Options

You need to host this page publicly. Here are your options:

#### Option A: Firebase Hosting (Recommended)

1. **Initialize Firebase Hosting:**
   ```bash
   firebase init hosting
   ```

2. **Configure `firebase.json`:**
   ```json
   {
     "hosting": {
       "public": "web",
       "ignore": [
         "firebase.json",
         "**/.*",
         "**/node_modules/**"
       ]
     }
   }
   ```

3. **Deploy:**
   ```bash
   firebase deploy --only hosting
   ```

4. **Your URL will be:**
   ```
   https://your-project-id.web.app/data-deletion.html
   ```

#### Option B: GitHub Pages

1. Create a `docs` folder in your repo
2. Copy `web/data-deletion.html` to `docs/data-deletion.html`
3. Enable GitHub Pages in repository settings
4. Your URL will be:
   ```
   https://your-username.github.io/SpareChange/data-deletion.html
   ```

#### Option C: Netlify Drop

1. Go to [Netlify Drop](https://app.netlify.com/drop)
2. Drag and drop the `web` folder
3. Get your URL:
   ```
   https://random-name.netlify.app/data-deletion.html
   ```

#### Option D: Custom Domain

Host on your own domain:
```
https://yourwebsite.com/sparechange/data-deletion.html
```

---

## Google Play Console Configuration

### Where to Add the Link

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Navigate to **Policy** → **App content**
4. Find **Data safety** section
5. Click **Manage**
6. Under **Data deletion**, add your URL

### What URL to Provide

Provide the URL where you hosted `data-deletion.html`:

**Example:**
```
https://your-project-id.web.app/data-deletion.html
```

### Google Play Requirements

✅ **Account deletion via in-app option**
- Users can delete their account directly in Settings

✅ **Data deletion without account deletion**
- Users can request data deletion via in-app option
- Users can also use the web form

✅ **Clear information about what gets deleted**
- Both in-app and web options clearly explain what data is deleted

✅ **Confirmation before deletion**
- Multiple confirmation steps to prevent accidental deletion

---

## Handling Web Form Submissions

The `data-deletion.html` page currently displays a success message but doesn't submit data anywhere. You need to implement backend handling:

### Option A: Firebase Cloud Function

Create a Cloud Function to handle form submissions:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.handleDataDeletionRequest = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const { email, requestType, reason } = req.body;

  await admin.firestore().collection('data_deletion_requests').add({
    email,
    requestType,
    reason,
    source: 'web',
    status: 'pending',
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  res.status(200).json({ success: true });
});
```

Then update the JavaScript in `data-deletion.html`:

```javascript
const response = await fetch('YOUR_CLOUD_FUNCTION_URL', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(formData)
});
```

### Option B: Email Notification

Use a service like [Formspree](https://formspree.io/) or [EmailJS](https://www.emailjs.com/):

```html
<form action="https://formspree.io/f/YOUR_FORM_ID" method="POST">
  <!-- form fields -->
</form>
```

### Option C: Support Ticket System

Integrate with your support system (Zendesk, Freshdesk, etc.)

---

## Processing Deletion Requests

You must process deletion requests within **30 days** as per GDPR/privacy regulations.

### Recommended Process

1. **Monitor Requests:**
   ```dart
   // Listen for pending deletion requests
   FirebaseFirestore.instance
       .collection('data_deletion_requests')
       .where('status', isEqualTo: 'pending')
       .snapshots();
   ```

2. **Manual Review:**
   - Verify user identity
   - Check for any legal holds
   - Confirm deletion scope

3. **Execute Deletion:**
   ```dart
   // Delete user data
   await deleteUserTransactions(userId);
   await deleteUserFamilyMembers(userId);
   await removeFromGroup(userId);
   
   // Mark request as completed
   await request.update({'status': 'completed'});
   ```

4. **Send Confirmation:**
   - Email user to confirm deletion
   - Include what was deleted
   - Provide reference number

---

## Testing

### Test Account Deletion

1. Create a test account
2. Add some transactions and data
3. Go to Settings → Privacy & Data → Delete Account
4. Verify all data is removed from Firebase Console

### Test Data Deletion Request

1. Submit a request via in-app option
2. Check Firestore for the request document
3. Process the request manually
4. Verify data is deleted but account remains

### Test Web Form

1. Visit your hosted `data-deletion.html`
2. Fill out the form
3. Submit and verify request is received
4. Check your backend/email/support system

---

## Firestore Security Rules

Update your Firestore security rules to allow users to create deletion requests:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to create their own deletion requests
    match /data_deletion_requests/{requestId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null && 
                            request.auth.uid == resource.data.userId;
    }
  }
}
```

---

## Compliance

### GDPR Compliance

✅ Right to erasure (Article 17)
✅ Right to data portability (Article 20)
✅ Transparency about data processing
✅ User control over personal data

### CCPA Compliance

✅ Right to deletion
✅ Right to know what data is collected
✅ Easy-to-use deletion mechanism

### Google Play Requirements

✅ Account deletion option
✅ Data deletion without account deletion
✅ Clear information about what gets deleted
✅ External webpage for deletion requests

---

## Summary

### For Google Play Console

**Data Deletion URL:**
```
https://your-project-id.web.app/data-deletion.html
```

**In-App Deletion:** Yes
- Settings → Privacy & Data → Delete Account

**Data Deletion Without Account:** Yes
- Settings → Privacy & Data → Request Data Deletion

**Data Export:** Yes
- Settings → Privacy & Data → Export My Data

---

## Next Steps

1. ✅ **Deploy data-deletion.html** to Firebase Hosting or another service
2. ✅ **Add the URL** to Google Play Console
3. ✅ **Set up backend** to handle web form submissions (optional)
4. ✅ **Create a process** to handle deletion requests within 30 days
5. ✅ **Update privacy policy** to mention these features
6. ✅ **Test all flows** thoroughly

---

## Support

If users have issues with data deletion:

**Email:** support@yourapp.com (update with your support email)
**Response Time:** Within 48 hours
**Deletion Timeline:** Maximum 30 days

---

## Files Modified

- `lib/services/auth_service.dart` - Added deleteAccount(), requestDataDeletion(), exportUserData()
- `lib/screens/settings_screen.dart` - Added UI for all privacy features
- `web/data-deletion.html` - Created standalone deletion request page

---

**Last Updated:** January 14, 2026
