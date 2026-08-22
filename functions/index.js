const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/**
 * Fires whenever a new message document is created in any chat.
 * Looks up every OTHER participant, grabs their saved FCM token, and sends
 * them a push notification with the sender's name and message preview.
 */
exports.onNewMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const message = event.data.data();
  const chatId = event.params.chatId;

  const chatDoc = await db.collection("chats").doc(chatId).get();
  if (!chatDoc.exists) return;
  const chat = chatDoc.data();

  const senderDoc = await db.collection("users").doc(message.senderId).get();
  const senderName = senderDoc.exists ? senderDoc.data().username : "Someone";

  const title = chat.isGroup ? `${senderName} in ${chat.groupName}` : senderName;
  const body = message.type === "image" ? "📷 Sent a photo" : message.text;

  const recipients = (chat.participants || []).filter((uid) => uid !== message.senderId);

  const tokens = [];
  for (const uid of recipients) {
    const userDoc = await db.collection("users").doc(uid).get();
    const token = userDoc.exists ? userDoc.data().fcmToken : null;
    if (token) tokens.push(token);
  }
  if (tokens.length === 0) return;

  await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: {chatId},
  });
});
