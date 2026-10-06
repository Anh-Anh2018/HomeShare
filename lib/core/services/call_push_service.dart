import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/chat/screens/call_screen.dart';
import '../../firebase_options.dart';
import 'call_service.dart';

/// Khóa điều hướng gốc của MaterialApp.
/// Dùng khóa này vì thông báo có thể mở màn hình cuộc gọi khi người dùng
/// đang ở bất kỳ trang nào, hoặc khi app vừa được bật lại từ trạng thái tắt.
final navigatorKey = GlobalKey<NavigatorState>();

/// Trùng với channelId trong Cloud Function và
/// com.google.firebase.messaging.default_notification_channel_id trên Android.
/// Android 8 trở lên bỏ thông báo nếu kênh này chưa được tạo trên máy.
const callNotificationChannelId = 'calls';

/// Hàm bắt buộc của Firebase Messaging khi app ở nền hoặc đã bị tắt.
/// Phải là hàm top-level, không nằm trong class, và có @pragma để
/// trình biên dịch không xóa hàm khi app không chạy trên màn hình chính.
/// Hiện chỉ khởi tạo Firebase. Hệ thống Android tự hiện thông báo có tiếng;
/// màn hình nhận cuộc gọi chỉ mở khi người dùng bấm vào thông báo đó.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Mở IncomingCallScreen đúng một lần cho mỗi cuộc gọi.
/// Có hai nguồn cùng lúc có thể yêu cầu mở màn hình:
/// - Firestore báo có cuộc gọi khi app đang mở.
/// - Người dùng bấm thông báo khi app đang tắt hoặc ở nền.
/// showingCallId chặn việc đẩy hai màn hình chồng lên nhau.
class IncomingCallRouter {
  static String? showingCallId;

  static Future<void> show(CallSession call) async {
    // Chỉ hiện khi cuộc gọi còn đang đổ chuông.
    // Cuộc gọi đã nhận, từ chối, nhỡ hoặc kết thúc thì bỏ qua.
    if (call.status != 'ringing' || showingCallId == call.id) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    showingCallId = call.id;
    await nav.push(
      MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)),
    );
    // Người dùng đã đóng màn hình nhận cuộc gọi, cho phép hiện cuộc gọi sau.
    if (showingCallId == call.id) showingCallId = null;
  }
}

/// Phần trên điện thoại của chuông cuộc gọi.
/// Cloud Function gửi thông báo; class này xin quyền, lưu mã máy,
/// tạo kênh chuông, rồi mở màn hình nhận khi người dùng bấm thông báo.
class CallPushService {
  /// Plugin local chỉ dùng để tạo kênh "Cuộc gọi" một lần.
  /// Nội dung thông báo do Firebase Cloud Messaging hiện, không tự dựng ở đây.
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// Gọi một lần trong main(), trước runApp.
  /// Đăng ký handler chạy nền và tạo kênh thông báo mức cao nhất, có tiếng.
  static Future<void> prepare() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: android));
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            callNotificationChannelId,
            'Cuộc gọi',
            description: 'Chuông cuộc gọi đến khi ứng dụng đang tắt',
            importance: Importance.max,
            playSound: true,
          ),
        );
  }

  /// Gọi sau khi đăng nhập, trong _SignedInShell.
  /// Máy phải mở app ít nhất một lần để lưu fcmToken, nếu không
  /// Cloud Function không biết gửi chuông tới đâu khi app đã tắt.
  static Future<void> bindUser(String uid) async {
    // Android 13 trở lên cần quyền POST_NOTIFICATIONS.
    await Permission.notification.request();
    final messaging = FirebaseMessaging.instance;
    // Quyền thông báo trên iOS và một số máy Android.
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await _saveToken(uid, await messaging.getToken());
    // Firebase đôi khi cấp mã mới. Ghi đè mã cũ trên cùng user.
    messaging.onTokenRefresh.listen((token) => _saveToken(uid, token));
    // App đang ở nền, người dùng bấm thông báo để mở lại.
    FirebaseMessaging.onMessageOpenedApp.listen(openFromMessage);
    // App đã bị tắt hẳn, người dùng bấm thông báo để khởi động app.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      await openFromMessage(initial);
    }
  }

  /// Ghi mã thiết bị vào users/{uid}.fcmToken.
  /// merge: true để không xóa các field khác của user.
  /// Đăng xuất thì auth_service xóa field này, tránh chuông nhầm tài khoản cũ.
  static Future<void> _saveToken(String uid, String? token) async {
    if (token == null || token.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  /// Đọc thông báo cuộc gọi rồi mở màn hình nhận nếu cuộc gọi còn đổ chuông.
  /// data.type và data.callId do Cloud Function notifyIncomingCall gắn vào.
  static Future<void> openFromMessage(RemoteMessage message) async {
    final callId = message.data['callId']?.toString() ?? '';
    if (message.data['type'] != 'incoming_call' || callId.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('calls').doc(callId).get();
    if (!doc.exists) return;
    await IncomingCallRouter.show(CallSession.fromDoc(doc));
  }
}
