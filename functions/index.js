const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Sends an FCM push when a notification document is created.
 *
 * Path: users/{userId}/notifications/{notificationId}
 * Matches the document written by FCMService.sendNotification
 * in the Flutter app.
 */
exports.sendNotificationOnCreate = functions.firestore
    .document("users/{userId}/notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      const notification = snap.data();
      const userId = context.params.userId;

      try {
        // Get user's FCM token
        const userDoc = await admin
            .firestore()
            .collection("users")
            .doc(userId)
            .get();

        const userData = userDoc.data() || {};
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.log(`No FCM token for user ${userId}`);
          return null;
        }

        const title = notification.title || "Notification";
        const body = notification.body || "";
        const type = notification.type || "generic";
        const extraData = notification.data || {};

        const message = {
          notification: {
            title,
            body,
          },
          data: {
            type,
            ...extraData,
          },
          token: fcmToken,
        };

        const response = await admin.messaging().send(message);
        console.log("Successfully sent message", response);

        await snap.ref.update({
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          sentStatus: "success",
        });

        return null;
      } catch (error) {
        console.error("Error sending notification", error);
        await snap.ref.update({
          sentStatus: "failed",
          error: error.message,
        });

        return null;
      }
    });
