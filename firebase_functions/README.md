# Firebase Cloud Functions — Pulse Messaging

This directory contains the production-ready Node.js Cloud Function that powers real-time push notifications for **Pulse**, a cross-platform Flutter messaging app. The function triggers on every new Firestore message, resolves the recipient's FCM token, and dispatches a fully-formed push notification with deep-link support across Android, iOS, and Web.

---

## How It Works

```
User sends message
       │
       ▼
Firestore: chats/{chatId}/messages/{messageId}  ← onCreate trigger
       │
       ▼
sendChatNotification (Cloud Function)
       │
       ├─ Fetch sender displayName  →  users/{senderId}
       ├─ Fetch recipient FCM token →  users/{recipientId}
       │
       ▼
FCM Admin SDK  →  Push Notification
       │
       ├─ Android: high-priority, channel: pulse_high_importance
       ├─ iOS (APNs): alert + sound
       └─ Data payload: { chatId, click_action }  →  Flutter deep-link router
```

The Flutter client (`lib/services/notification_service.dart`) handles all three delivery states:

| State | Behavior |
|---|---|
| **Foreground** | Shows a local notification via `flutter_local_notifications`. Suppressed if the user is already viewing that chat (WhatsApp-style). |
| **Background** | System tray notification. Tap opens the app and navigates to the correct chat via `onMessageOpenedApp`. |
| **Terminated** | FCM `getInitialMessage()` is checked on cold start and deep-links after a 1.2 s build delay. |

---

## Prerequisites

| Requirement | Version |
|---|---|
| Node.js | ≥ 18 |
| Firebase CLI | Latest (`npm install -g firebase-tools`) |
| Firebase project | Blaze (pay-as-you-go) plan — required for outbound network calls from Cloud Functions |

---

## Firestore Data Schema

The function reads from two collections. Ensure your Firestore documents match these shapes before deploying.

### `chats/{chatId}/messages/{messageId}`
```json
{
  "senderId": "uid_abc",
  "recipientId": "uid_xyz",
  "content": "Hey, are you free tonight?",
  "timestamp": "<Firestore Timestamp>"
}
```

### `users/{uid}`
```json
{
  "uid": "uid_xyz",
  "displayName": "Jane Doe",
  "email": "jane@example.com",
  "fcmToken": "<FCM registration token>",
  "status": "online",
  "lastSeen": "<Firestore Timestamp>"
}
```

> The `fcmToken` field is written and refreshed automatically by `lib/services/notification_service.dart` → `updateTokenInFirestore()` on every login.

---

## Deployment

### 1. Authenticate and select your project

```bash
firebase login
firebase use --add
```

Select your target Firebase project when prompted.

### 2. Initialize Functions in the project root

Run this from `Cross-Platform Messaging App/` (the Flutter project root), **not** from inside `firebase_functions/`:

```bash
firebase init functions
```

- Select **Use an existing project**
- Choose **JavaScript**
- Answer **No** when asked to overwrite `package.json` or `index.js` — this preserves the production code

### 3. Verify dependencies

Confirm `firebase_functions/package.json` includes:

```json
{
  "dependencies": {
    "firebase-admin": "^11.8.0",
    "firebase-functions": "^4.3.1"
  },
  "engines": {
    "node": "18"
  }
}
```

Install locally if needed:

```bash
cd firebase_functions
npm install
```

### 4. Deploy

```bash
firebase deploy --only functions
```

After a successful deploy, the function appears as **active** in **Firebase Console → Functions**. End-to-end push notifications are live immediately.

---

## Environment & Configuration

No environment variables or `.env` files are required. The function uses the **Application Default Credentials** provided automatically by the Firebase runtime via `admin.initializeApp()`.

If you need to run the function emulator locally:

```bash
firebase emulators:start --only functions,firestore
```

---

## Android Notification Channel

The function sets `channelId: 'pulse_high_importance'` in the Android FCM payload. This channel is registered on the Flutter side in `notification_service.dart`:

```dart
const channel = AndroidNotificationChannel(
  'pulse_high_importance',
  'Pulse Conversations',
  description: 'Notifications for active Pulse messages.',
  importance: Importance.max,
);
```

If you rename the channel, update both the Cloud Function payload and the Flutter channel registration to match.

---

## Mock Mode

The Flutter app ships with a built-in **offline Mock Mode** that activates automatically when Firebase is not configured (`google-services.json` / `GoogleService-Info.plist` absent or invalid). In Mock Mode:

- `MockNotificationService` replaces `FirebaseNotificationService`
- Local notifications are triggered directly from the chat provider — no Cloud Function is involved
- The same WhatsApp-style suppression logic applies

This means the app is fully interactive and demonstrable without a live Firebase project.

---

## Troubleshooting

**Function deploys but notifications are not received**
- Confirm the recipient's `fcmToken` field exists and is current in Firestore.
- Check **Firebase Console → Functions → Logs** for `No active FCM registration token found` messages.
- Ensure the device has granted notification permissions.

**`Error: Billing account not configured`**
- Cloud Functions (2nd gen) and outbound FCM calls require the **Blaze plan**. Upgrade in the Firebase Console.

**Android notifications not showing in foreground**
- Verify the `channelId` in the function payload matches the channel registered in Flutter exactly (`pulse_high_importance`).

**iOS notifications not delivered**
- Confirm APNs authentication keys are uploaded in **Firebase Console → Project Settings → Cloud Messaging**.

---

## Project Structure Reference

```
Cross-Platform Messaging App/
├── firebase_functions/
│   ├── index.js          ← Cloud Function (this directory)
│   └── README.md
├── lib/
│   ├── services/
│   │   ├── notification_service.dart   ← FCM client + Mock service
│   │   ├── auth_service.dart           ← Firebase Auth + Mock auth
│   │   └── database_service.dart       ← Firestore read/write
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   └── chat_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   └── main.dart                       ← Firebase init + Mock fallback
├── firebase.json
└── pubspec.yaml
```
