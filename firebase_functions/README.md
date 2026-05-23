# Firebase Cloud Functions: Chat Push Notifications

This directory contains a complete, ready-to-deploy Node.js Cloud Function that automates WhatsApp-style push notifications for the Pulse Messaging App.

## What it does
When a user sends a message, it is written to the Firestore path `chats/{chatId}/messages/{messageId}`. This function triggers instantly, checks the recipient's FCM registration token from the `users/{recipientId}` document, and dispatches an FCM push notification containing a custom data payload (`chatId`). This enables deep linking on mobile and web viewports.

---

## Deployment Steps

Follow these steps to deploy this trigger to your active Firebase project in seconds:

### Prerequisites
Make sure you have Node.js (v18 or higher recommended) and the Firebase CLI installed on your machine:
```bash
npm install -g firebase-tools
```

### 1. Initialize Firebase Functions
At the root of the project (`Cross-Platform Messaging App`), run:
```bash
firebase login
firebase init functions
```
- Select **Use an existing project** and pick your target Firebase project.
- Choose **JavaScript** or **TypeScript** (this file is pre-configured for JavaScript).
- Choose **No** when asked to overwrite `package.json` or `index.js` (to preserve this ready-to-deploy code!).
- Choose **Yes** to install dependencies via `npm`.

### 2. Copy dependencies configurations
Make sure your `functions/package.json` includes `firebase-admin` and `firebase-functions` in dependencies:
```json
"dependencies": {
  "firebase-admin": "^11.8.0",
  "firebase-functions": "^4.3.1"
}
```

### 3. Deploy
Execute the deployment command from the functions directory or root:
```bash
firebase deploy --only functions
```

Once completed, the function will show as green and active in your **Firebase Console -> Functions** dashboard, and push notifications will trigger dynamically on all platforms!
