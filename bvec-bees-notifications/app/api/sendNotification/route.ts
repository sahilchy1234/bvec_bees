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

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { userId, title, body: notificationBody, type, data } = body;

    if (!userId) {
      return NextResponse.json(
        { error: "Missing userId" },
        { status: 400 },
      );
    }

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userData = userDoc.data() || {};
    const fcmToken = userData.fcmToken as string | undefined;

    if (!fcmToken) {
      return NextResponse.json(
        { error: "No fcmToken for user" },
        { status: 400 },
      );
    }

    const message = {
      notification: {
        title: title || "Notification",
        body: notificationBody || "",
      },
      data: {
        type: type || "generic",
        ...(data || {}),
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);

    return NextResponse.json({ success: true, response }, { status: 200 });
  } catch (error) {
    console.error("Error in /api/sendNotification:", error);
    return NextResponse.json(
      { error: "Failed to send notification" },
      { status: 500 },
    );
  }
}
