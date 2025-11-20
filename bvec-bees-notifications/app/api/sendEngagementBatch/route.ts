import { NextRequest, NextResponse } from "next/server";
import admin from "firebase-admin";

// Initialize Firebase Admin once per runtime
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
  });
}

async function shouldSendEngagementNotification(
  userDoc: FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>,
): Promise<boolean> {
  try {
    const data = userDoc.data() || {};
    const lastActiveTime = data.lastActiveTime as FirebaseFirestore.Timestamp | undefined;
    const notificationFrequency = (data.notificationFrequency as string) || "medium";
    const engagementScore = (data.engagementScore as number) ?? 0;

    if (lastActiveTime) {
      const timeSinceActive = Date.now() - lastActiveTime.toDate().getTime();
      const minutes = timeSinceActive / (1000 * 60);
      if (minutes < 30) {
        return false;
      }
    }

    if (notificationFrequency === "low") {
      return engagementScore < 30;
    }
    if (notificationFrequency === "high") {
      return engagementScore < 70;
    }
    // medium
    return engagementScore < 50;
  } catch (e) {
    console.error("Error in shouldSendEngagementNotification:", e);
    return false;
  }
}

export async function POST(_request: NextRequest) {
  try {
    const firestore = admin.firestore();

    const usersSnapshot = await firestore
      .collection("users")
      .where("isVerified", "==", true)
      .get();

    const engagementMessages = [
      {
        title: "New matches waiting! 🔥",
        body: "Check out who's interested in you today.",
      },
      {
        title: "Your profile is hot! 🌟",
        body: "People are checking you out. Come see who!",
      },
      {
        title: "Don't miss out! 💬",
        body: "You have new messages and interactions.",
      },
      {
        title: "Trending posts nearby 📱",
        body: "See what's popular in your college right now.",
      },
      {
        title: "Someone liked your vibe! 💕",
        body: "Check out their profile and say hello.",
      },
    ];

    const results: Array<{ userId: string; status: string; response?: string }> = [];

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data() || {};

      const shouldSend = await shouldSendEngagementNotification(userDoc);
      if (!shouldSend) {
        results.push({ userId, status: "skipped_shouldSend=false" });
        continue;
      }

      const fcmToken = userData.fcmToken as string | undefined;
      if (!fcmToken) {
        results.push({ userId, status: "skipped_no_fcmToken" });
        continue;
      }

      const randomMessage =
        engagementMessages[
          Math.floor(Math.random() * engagementMessages.length)
        ];

      // Create Firestore notification document (mirrors app behaviour)
      const notificationRef = firestore
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc();

      await notificationRef.set({
        type: "engagement",
        title: randomMessage.title,
        body: randomMessage.body,
        senderId: null,
        senderName: null,
        senderImage: null,
        relatedId: null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: { action: "open_feed" },
      });

      const message: admin.messaging.Message = {
        notification: {
          title: randomMessage.title,
          body: randomMessage.body,
        },
        data: {
          type: "engagement",
          action: "open_feed",
        },
        token: fcmToken,
      };

      try {
        const response = await admin.messaging().send(message);

        await userDoc.ref.update({
          lastEngagementNotification: admin.firestore.FieldValue.serverTimestamp(),
        });

        results.push({ userId, status: "sent", response });
      } catch (e) {
        console.error("Error sending engagement notification to", userId, e);
        results.push({ userId, status: "error_sending" });
      }
    }

    return NextResponse.json(
      {
        totalUsers: usersSnapshot.size,
        results,
      },
      { status: 200 },
    );
  } catch (error) {
    console.error("Error in /api/sendEngagementBatch:", error);
    return NextResponse.json(
      { error: "Failed to send batch engagement notifications" },
      { status: 500 },
    );
  }
}
