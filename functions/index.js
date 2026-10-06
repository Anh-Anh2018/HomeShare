const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { RtcRole, RtcTokenBuilder } = require("agora-token");

admin.initializeApp();

const appCertificate = defineSecret("AGORA_APP_CERTIFICATE");
const APP_ID = "3844040c2d2244778f46467cc801e808";
const TOKEN_TTL_SECONDS = 60 * 60 * 2;

exports.createRtcToken = onCall(
  { region: "asia-southeast1", secrets: [appCertificate] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Dang nhap truoc khi goi.");
    }

    const channelName = String(request.data?.channelName || "").trim();
    if (!/^[A-Za-z0-9_-]{1,64}$/.test(channelName)) {
      throw new HttpsError("invalid-argument", "Ten kenh khong hop le.");
    }

    const snap = await admin.firestore().collection("calls").doc(channelName).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Khong thay cuoc goi.");
    }

    const call = snap.data() || {};
    const uid = request.auth.uid;
    if (uid !== call.callerId && uid !== call.calleeId) {
      throw new HttpsError("permission-denied", "Ban khong thuoc cuoc goi nay.");
    }

    const expireAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      appCertificate.value(),
      channelName,
      0,
      RtcRole.PUBLISHER,
      expireAt,
      expireAt,
    );

    return { token, uid: 0, channelName };
  },
);

// Chạy khi có document mới trong calls/{callId}.
// Gửi thông báo ưu tiên cao tới máy người nhận nếu cuộc gọi đang đổ chuông.
// App đang mở vẫn hiện màn hình qua Firestore; thông báo này dành cho lúc app tắt hoặc ở nền.
exports.notifyIncomingCall = onDocumentCreated(
  { document: "calls/{callId}", region: "asia-southeast1" },
  async (event) => {
    const call = event.data?.data();
    // Bỏ qua cuộc gọi không còn ở trạng thái ringing.
    if (!call || call.status !== "ringing" || !call.calleeId) return;

    // fcmToken do app ghi vào users/{uid} lúc người nhận đăng nhập.
    const user = await admin.firestore().collection("users").doc(call.calleeId).get();
    const token = user.data()?.fcmToken;
    if (!token) return;

    const isVideo = call.type === "video";
    const callerName = call.callerName || "Người dùng";
    try {
      await admin.messaging().send({
        token,
        // Phần hệ thống tự hiện trên màn hình khi app không mở.
        notification: {
          title: isVideo ? "Cuộc gọi video" : "Cuộc gọi thoại",
          body: `${callerName} đang gọi cho bạn`,
        },
        // Phần app đọc khi người dùng bấm thông báo để mở đúng cuộc gọi.
        data: {
          type: "incoming_call",
          callId: event.params.callId,
        },
        android: {
          priority: "high",
          notification: {
            // Trùng kênh "calls" đã tạo trong CallPushService.
            channelId: "calls",
            sound: "default",
            priority: "high",
            defaultSound: true,
            visibility: "PUBLIC",
          },
        },
      });
    } catch (error) {
      const code = String(error.code || "");
      // Mã máy đã hết hạn hoặc không hợp lệ thì xóa, tránh gửi lại mã chết.
      if (code.includes("registration-token-not-registered") || code.includes("invalid-argument")) {
        await user.ref.set(
          { fcmToken: admin.firestore.FieldValue.delete() },
          { merge: true },
        );
        return;
      }
      throw error;
    }
  },
);
