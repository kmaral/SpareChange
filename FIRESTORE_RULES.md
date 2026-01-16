# Firestore Security Rules for SpareChange

To ensure proper group-based data isolation, configure these Firestore Security Rules in the Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to get user's groupId
    function getUserGroupId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.groupId;
    }
    
    // Helper function to check if user is in the group
    function isInGroup(groupId) {
      return isAuthenticated() && getUserGroupId() == groupId;
    }
    
    // Users collection - each user can read/write their own document
    match /users/{userId} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // Groups collection
    match /groups/{groupId} {
      // Anyone authenticated can create a group
      allow create: if isAuthenticated();
      
      // Read and write if user is a member or admin
      allow read, write: if isAuthenticated() && 
        (request.auth.uid == resource.data.adminId || 
         request.auth.uid in resource.data.members);
    }
    
    // Denominations - filtered by groupId
    match /denominations/{denominationId} {
      // Read if in the same group
      allow read: if isAuthenticated() && 
        isInGroup(resource.data.groupId);
      
      // Create/Update/Delete if in the same group
      allow create, update: if isAuthenticated() && 
        isInGroup(request.resource.data.groupId);
      
      allow delete: if isAuthenticated() && 
        isInGroup(resource.data.groupId);
    }
    
    // Transactions - filtered by groupId
    match /transactions/{transactionId} {
      // Read if in the same group
      allow read: if isAuthenticated() && 
        isInGroup(resource.data.groupId);
      
      // Create/Update/Delete if in the same group
      allow create, update: if isAuthenticated() && 
        isInGroup(request.resource.data.groupId);
      
      allow delete: if isAuthenticated() && 
        isInGroup(resource.data.groupId);
    }
    
    // Inventory - one document per group
    match /inventory/{groupId} {
      // Read/Write if user belongs to this group
      allow read, write: if isAuthenticated() && isInGroup(groupId);
    }
    
    // Family members (users in groups)
    match /family_members/{memberId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

## How to Apply These Rules

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your SpareChange project
3. Navigate to **Firestore Database** → **Rules**
4. Replace the existing rules with the above rules
5. Click **Publish**

## Data Structure Overview

### Denominations Collection
```
denominations/{denominationId}
  - id: string
  - value: number
  - type: string (note/coin)
  - isActive: boolean
  - groupId: string ← Links to group
  - createdAt: timestamp
```

### Transactions Collection
```
transactions/{transactionId}
  - id: string
  - userId: string
  - userName: string (encrypted)
  - denominationValue: number
  - denominationId: string
  - quantity: number
  - transactionType: string (added/removed)
  - totalAmount: number
  - reason: string (encrypted, optional)
  - timestamp: timestamp
  - groupId: string ← Links to group
```

### Inventory Collection
```
inventory/{groupId}  ← Document ID is the groupId
  - denominationCounts: map<string, number>
  - lastUpdated: timestamp
```

### Groups Collection
```
groups/{groupId}
  - name: string (encrypted)
  - createdBy: string (uid)
  - adminId: string (uid)
  - members: array<string> (uids)
  - maxMembers: number (6)
  - createdAt: timestamp
```

### Users Collection
```
users/{userId}
  - uid: string
  - email: string (encrypted)
  - displayName: string (encrypted)
  - photoURL: string
  - groupId: string ← Links to group
  - createdAt: timestamp
```

## Testing

After applying the rules, test that:

1. ✅ Users can only see denominations from their group
2. ✅ Users can only see transactions from their group
3. ✅ Users can only access inventory for their group
4. ✅ Users cannot access data from other groups
5. ✅ Anonymous users cannot access any data
