const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function triggered when a new message document is created
 * under 'chats/{chatId}/messages/{messageId}'.
 * Resolves the recipient, checks their active FCM token, and sends a push notification.
 */
exports.sendChatNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message) return null;

    const { chatId } = context.params;
    const { senderId, recipientId, content } = message;

    try {
      // 1. Fetch sender profile details to display their name
      const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
      const senderData = senderDoc.data();
      const senderName = senderData ? senderData.displayName : 'Pulse User';

      // 2. Fetch recipient profile to acquire their FCM registration token
      const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        console.log(`Recipient ${recipientId} does not exist in Firestore.`);
        return null;
      }

      const recipientData = recipientDoc.data();
      const fcmToken = recipientData ? recipientData.fcmToken : null;

      if (!fcmToken) {
        console.log(`No active FCM registration token found for recipient ${recipientId}.`);
        return null;
      }

      // 3. Prepare Push Notification message payload
      const payload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: content.length > 80 ? content.substring(0, 77) + '...' : content,
        },
        data: {
          // Pass the chatId inside the data map so the Flutter deep-linking router
          // immediately opens the correct chat room upon notification click
          chatId: chatId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'pulse_high_importance', // Must match Flutter channel registration
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: senderName,
                body: content.length > 80 ? content.substring(0, 77) + '...' : content,
              },
              sound: 'default',
            },
          },
        },
      };

      // 4. Send notification via FCM Admin client
      const response = await admin.messaging().send(payload);
      console.log(`Successfully dispatched push notification: ${response}`);
      return response;
    } catch (error) {
      console.error('Error dispatching chat push notification:', error);
      return null;
    }
  });
