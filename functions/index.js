const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldPath} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

function pushData(notificationId, value) {
  return {
    notification_id: notificationId,
    type: String(value.type || ""),
    related_record_id: String(value.related_record_id || ""),
    zone: String(value.zone || ""),
  };
}

async function recipientUids(db, recipientUid) {
  if (recipientUid !== "experts") return recipientUid ? [recipientUid] : [];
  const experts = await db
      .collection("users")
      .where("accountRole", "==", "expert")
      .get();
  return experts.docs
      .filter((doc) => doc.get("isActive") === true)
      .map((doc) => doc.id);
}

exports.sendNotificationPush = onDocumentCreated(
    {document: "notifications/{notificationId}", region: "asia-southeast1"},
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const value = snapshot.data();
      const title = String(value.title || "COTS Monitor").slice(0, 200);
      const body = String(value.body || "You have a new activity.").slice(0, 4000);
      const db = getFirestore();
      const uids = await recipientUids(db, String(value.recipient_uid || ""));
      if (uids.length === 0) return;

      const tokenDocs = [];
      for (let offset = 0; offset < uids.length; offset += 30) {
        const group = uids.slice(offset, offset + 30);
        const query = await db
            .collection("push_tokens")
            .where("uid", "in", group)
            .get();
        tokenDocs.push(...query.docs);
      }
      if (tokenDocs.length === 0) return;

      for (let offset = 0; offset < tokenDocs.length; offset += 500) {
        const group = tokenDocs.slice(offset, offset + 500);
        const response = await getMessaging().sendEachForMulticast({
          tokens: group.map((doc) => doc.get("token")),
          notification: {title, body},
          data: pushData(event.params.notificationId, value),
          android: {
            priority: "high",
            notification: {channelId: "cots_activity"},
          },
        });

        const staleRefs = [];
        response.responses.forEach((result, index) => {
          if (!result.success && invalidTokenCodes.has(result.error?.code)) {
            staleRefs.push(group[index].ref);
          }
        });
        if (staleRefs.length > 0) {
          const batch = db.batch();
          staleRefs.forEach((ref) => batch.delete(ref));
          await batch.commit();
        }
      }
    },
);

exports._test = {pushData};
