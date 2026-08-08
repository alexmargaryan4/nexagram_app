import { onDocumentDeleted, onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { initializeApp } from "firebase-admin/app";

initializeApp();

/**
 * When a chat document is deleted, recursively delete all of its messages.
 * Client SDKs can't do recursive deletes, and giving the client broad
 * delete permissions on the messages subcollection is unsafe — so this
 * runs server-side with the Admin SDK instead.
 */
export const cleanupChatMessages = onDocumentDeleted(
  "chats/{chatId}",
  async (event) => {
    const db = getFirestore();
    const messagesRef = db
      .collection("chats")
      .doc(event.params.chatId)
      .collection("messages");
    const snapshot = await messagesRef.get();
    const batchSize = 400;
    for (let i = 0; i < snapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      snapshot.docs.slice(i, i + batchSize).forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }
);

/**
 * When a new message is created, push a notification to every other
 * participant's registered devices. The client only shows a local
 * notification while the app is in the foreground — this is what reaches
 * people whose app is closed or backgrounded.
 */
export const notifyOnNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const db = getFirestore();
    const chatDoc = await db.collection("chats").doc(event.params.chatId).get();
    const chat = chatDoc.data();
    if (!chat) return;

    const recipients: string[] = chat.participantIds.filter(
      (uid: string) => uid !== message.senderId
    );
    if (recipients.length === 0) return;

    const usersSnap = await db
      .collection("users")
      .where("__name__", "in", recipients.slice(0, 30)) // whereIn caps at 30
      .get();

    const tokens = usersSnap.docs.flatMap((d) => d.data().fcmTokens ?? []);
    if (tokens.length === 0) return;

    const senderSnap = await db.collection("users").doc(message.senderId).get();
    const senderName = senderSnap.data()?.name ?? "New message";

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: senderName,
        body: message.type === "text" ? message.text : "Sent an attachment",
      },
      data: { chatId: event.params.chatId },
    });
  }
);
