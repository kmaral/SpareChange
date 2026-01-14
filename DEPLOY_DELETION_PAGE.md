# Quick Start: Deploy Data Deletion Page

This guide will help you quickly deploy the data deletion page and get the URL for Google Play Console.

## Fastest Method: Firebase Hosting (5 minutes)

### Prerequisites
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project already set up

### Steps

1. **Login to Firebase:**
   ```bash
   firebase login
   ```

2. **Initialize Hosting (in your project directory):**
   ```bash
   firebase init hosting
   ```
   - Select your Firebase project
   - Set public directory to: `web`
   - Configure as single-page app: `No`
   - Don't overwrite existing files

3. **Deploy:**
   ```bash
   firebase deploy --only hosting
   ```

4. **Get Your URL:**
   After deployment, you'll see:
   ```
   Hosting URL: https://your-project-id.web.app
   ```

5. **Your data deletion page URL is:**
   ```
   https://your-project-id.web.app/data-deletion.html
   ```

6. **Copy this URL to Google Play Console:**
   - Go to Play Console → Your App → Policy → App content
   - Find "Data safety" → Manage
   - Add the URL under "Data deletion"

---

## Alternative: GitHub Pages (Free)

1. **Create a `docs` folder in your repo:**
   ```bash
   mkdir docs
   cp web/data-deletion.html docs/
   ```

2. **Push to GitHub:**
   ```bash
   git add docs/
   git commit -m "Add data deletion page"
   git push
   ```

3. **Enable GitHub Pages:**
   - Go to GitHub → Your Repo → Settings → Pages
   - Source: Deploy from a branch
   - Branch: main
   - Folder: /docs
   - Save

4. **Your URL:**
   ```
   https://YOUR-USERNAME.github.io/SpareChange/data-deletion.html
   ```

---

## What to Tell Google Play Console

When asked: **"Do you provide a way for users to request that some or all of their data is deleted?"**

✅ **Answer: YES**

**Provide this information:**

1. **In-App Deletion:**
   - Users can delete their entire account via Settings → Privacy & Data → Delete Account
   - Users can request data deletion without deleting account via Settings → Privacy & Data → Request Data Deletion

2. **Web Link:**
   - Provide the URL from Firebase Hosting or GitHub Pages
   - Example: `https://your-project-id.web.app/data-deletion.html`

3. **What Gets Deleted:**
   - User account information
   - All transaction history
   - Family member entries
   - Group memberships
   - All personal data

4. **Timeline:**
   - In-app deletion: Immediate
   - Web request: Within 30 days

---

## Verify It Works

1. **Open your URL in a browser**
2. **Fill out the form**
3. **Click Submit**
4. **You should see a success message**

---

## Need Help?

- Firebase Hosting Docs: https://firebase.google.com/docs/hosting
- GitHub Pages Docs: https://docs.github.com/en/pages
- Full documentation: See `DATA_DELETION_GUIDE.md`

---

**Quick Checklist:**
- [ ] Deploy data-deletion.html to hosting
- [ ] Test the URL in browser
- [ ] Add URL to Google Play Console
- [ ] Update app with new features
- [ ] Test in-app deletion
- [ ] Submit app for review

You're all set! 🎉
