import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/agora_config.dart';
import 'chat_service.dart';

class CallPermissions {
  static Future<bool> ensure({required bool video}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (!video) return true;
    final camera = await Permission.camera.request();
    return camera.isGranted;
  }
}

class CallSession {
  final String id;
  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final String chatId;
  final String type;
  final String status;
  final String channelName;
  final int durationSeconds;
  final DateTime createdAt;

  const CallSession({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.chatId,
    required this.type,
    required this.status,
    required this.channelName,
    required this.createdAt,
    this.durationSeconds = 0,
  });

  bool get isVideo => type == 'video';

  factory CallSession.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final created = data['createdAt'];
    return CallSession(
      id: doc.id,
      callerId: data['callerId']?.toString() ?? '',
      callerName: data['callerName']?.toString() ?? 'Người dùng',
      calleeId: data['calleeId']?.toString() ?? '',
      calleeName: data['calleeName']?.toString() ?? 'Người dùng',
      chatId: data['chatId']?.toString() ?? '',
      type: data['type']?.toString() ?? 'audio',
      status: data['status']?.toString() ?? 'ringing',
      channelName: data['channelName']?.toString() ?? AgoraConfig.channelName,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
    );
  }
}

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _calls => _firestore.collection('calls');

  Future<CallSession> startCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    required bool video,
  }) async {
    final doc = _calls.doc();
    final now = DateTime.now();
    final session = CallSession(
      id: doc.id,
      callerId: callerId,
      callerName: callerName,
      calleeId: calleeId,
      calleeName: calleeName,
      chatId: ChatService.getChatId(callerId, calleeId),
      type: video ? 'video' : 'audio',
      status: 'ringing',
      channelName: AgoraConfig.channelName,
      createdAt: now,
    );
    await doc.set({
      'callerId': session.callerId,
      'callerName': session.callerName,
      'calleeId': session.calleeId,
      'calleeName': session.calleeName,
      'chatId': session.chatId,
      'type': session.type,
      'status': session.status,
      'channelName': session.channelName,
      'durationSeconds': 0,
      'createdAt': Timestamp.fromDate(now),
    });
    return session;
  }

  Stream<CallSession?> watchCall(String callId) {
    return _calls.doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CallSession.fromDoc(doc);
    });
  }

  Stream<CallSession?> watchIncoming(String uid) {
    return _calls.where('calleeId', isEqualTo: uid).snapshots().map((snap) {
      final ringing = snap.docs.map(CallSession.fromDoc).where((call) {
        return call.status == 'ringing' && DateTime.now().difference(call.createdAt) < const Duration(minutes: 2);
      }).toList();
      ringing.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (ringing.isEmpty) return null;
      return ringing.first;
    });
  }

  Future<void> updateStatus(String callId, String status, {int? durationSeconds}) {
    return _calls.doc(callId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'durationSeconds': ?durationSeconds,
    });
  }
}

final callServiceProvider = Provider<CallService>((ref) => CallService());
