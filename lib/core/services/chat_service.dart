import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chat_model.dart';

class ChatParams {
  final String userA;
  final String userB;

  const ChatParams({required this.userA, required this.userB});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParams && userA == other.userA && userB == other.userB;

  @override
  int get hashCode => Object.hash(userA, userB);
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Danh sach tu khoa bi cam loc tu dong theo Tc_CHAT_49
  static const List<String> _prohibitedKeywords = [
    'lừa đảo',
    'lua dao',
    'cờ bạc',
    'co bac',
    'đánh bạc',
    'danh bac',
    'nạp tiền ảo',
    'nap tien ao',
    'hack tiền',
    'hack tien',
    'chuyển tiền trước không xem phòng',
  ];

  /// Kiểm tra tin nhắn vi phạm tiêu chuẩn cộng đồng (Tc_CHAT_49)
  static bool checkProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _prohibitedKeywords) {
      if (lower.contains(word)) {
        return true;
      }
    }
    return false;
  }

  // Tính chatId / cuocTroChuyenId duy nhất giữa 2 người dùng
  static String getChatId(String a, String b) {
    final cleanA = a.trim();
    final cleanB = b.trim();
    return cleanA.compareTo(cleanB) < 0 ? '${cleanA}_$cleanB' : '${cleanB}_$cleanA';
  }

  // Gửi tin nhắn mới lưu vào subcollection chats/{chatId}/messages
  Future<void> sendMessage(
    ChatMessageModel message, {
    String? receiverName,
    String? receiverAvatar,
    String? receiverPhone,
    Map<String, dynamic>? roomMetadata,
  }) async {
    // 1. Kiểm tra không gửi rỗng / toàn khoảng trắng (Tc_CHAT_24)
    if (message.text.trim().isEmpty && message.messageType == 'text') {
      throw ArgumentError('Nội dung tin nhắn không được để trống.');
    }

    // 2. Kiểm tra bộ lọc từ khóa cấm / lừa đảo (Tc_CHAT_49)
    if (checkProfanity(message.text)) {
      throw Exception('Tin nhắn vi phạm tiêu chuẩn cộng đồng về an toàn thông tin.');
    }

    final chatId = getChatId(message.senderId, message.receiverId);
    final batch = _firestore.batch();

    // 3. Lưu tin nhắn vào subcollection
    final msgDoc = message.id.isNotEmpty
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc(message.id)
        : _firestore.collection('chats').doc(chatId).collection('messages').doc();

    final messageToSave = message.copyWith(id: msgDoc.id, conversationId: chatId);
    batch.set(msgDoc, messageToSave.toMap());

    // 4. Cập nhật hội thoại tổng quan (recent conversation)
    final userNames = <String, String>{
      message.senderId: message.senderName,
    };
    if (receiverName != null && receiverName.trim().isNotEmpty) {
      userNames[message.receiverId] = receiverName.trim();
    }

    final partnerNames = <String, String>{
      message.senderId: (receiverName != null && receiverName.trim().isNotEmpty)
          ? receiverName.trim()
          : 'Đối tác trao đổi',
      message.receiverId: message.senderName,
    };

    final chatDoc = _firestore.collection('chats').doc(chatId);
    final convData = <String, dynamic>{
      'chatId': chatId,
      'cuocTroChuyenId': chatId,
      'users': [message.senderId, message.receiverId],
      'nguoiThamGia': [message.senderId, message.receiverId],
      'lastMessage': message.text,
      'noiDungCuoi': message.text,
      'lastSenderName': message.senderName,
      'lastSenderId': message.senderId,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'ngayGuiCuoi': FieldValue.serverTimestamp(),
      'userNames': userNames,
      'partnerNames': partnerNames,
      'isRead': false,
      'readBy': {
        message.senderId: true,
        message.receiverId: false,
      },
      'unreadCount': FieldValue.increment(1),
      'unreadFor_${message.receiverId}': FieldValue.increment(1),
      'unreadFor_${message.senderId}': 0,
    };

    if (receiverAvatar != null && receiverAvatar.isNotEmpty) {
      convData['userAvatars'] = {message.receiverId: receiverAvatar};
    }
    if (receiverPhone != null && receiverPhone.isNotEmpty) {
      convData['userPhones'] = {message.receiverId: receiverPhone};
    }

    if (roomMetadata != null) {
      convData.addAll(roomMetadata);
    }

    batch.set(chatDoc, convData, SetOptions(merge: true));

    await batch.commit();
  }

  // Đánh dấu đã đọc toàn bộ tin nhắn trong hội thoại
  Future<void> markAsRead(String currentUserId, String partnerId) async {
    final cleanA = currentUserId.trim();
    final cleanB = partnerId.trim();
    if (cleanA.isEmpty || cleanB.isEmpty) return;

    final chatId = getChatId(cleanA, cleanB);
    final chatDoc = _firestore.collection('chats').doc(chatId);

    try {
      await chatDoc.set({
        'isRead': true,
        'unreadCount': 0,
        'unreadFor_$cleanA': 0,
        'readBy': {cleanA: true},
      }, SetOptions(merge: true));

      final unreadMsgs = await chatDoc
          .collection('messages')
          .where('receiverId', isEqualTo: cleanA)
          .where('isRead', isEqualTo: false)
          .limit(30)
          .get();

      if (unreadMsgs.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadMsgs.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'status': 'read',
            'trangThaiTinNhan_id': 'read',
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  // Cập nhật trạng thái tin nhắn (đã đọc / phản hồi lời mời...)
  Future<void> updateMessageExtraData({
    required String senderId,
    required String receiverId,
    required String messageId,
    required Map<String, dynamic> extraData,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({'extraData': extraData}, SetOptions(merge: true));
  }

  /// Thu hồi tin nhắn ở cả 2 phía (Xóa nội dung tin nhắn và chuyển sang trạng thái đã thu hồi)
  Future<void> revokeMessageForEveryone({
    required String senderId,
    required String receiverId,
    required String messageId,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final msgDoc = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await msgDoc.set({
      'text': 'Tin nhắn đã được thu hồi',
      'noiDung': 'Tin nhắn đã được thu hồi',
      'attachmentUrl': '',
      'duongDan': '',
      'messageType': 'revoked',
      'loaiTinNhan_id': 'revoked',
      'status': 'revoked',
      'trangThaiTinNhan_id': 'revoked',
      'isRevoked': true,
      'revokedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Cập nhật tóm tắt cuộc trò chuyện
    try {
      final chatDoc = _firestore.collection('chats').doc(chatId);
      final chatSnap = await chatDoc.get();
      if (chatSnap.exists) {
        final data = chatSnap.data();
        if (data?['lastSenderId'] == senderId) {
          await chatDoc.set({
            'lastMessage': 'Tin nhắn đã được thu hồi',
            'noiDungCuoi': 'Tin nhắn đã được thu hồi',
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error updating lastMessage on revoke: $e');
    }
  }

  /// Xóa tin nhắn hoàn toàn khỏi database ở cả 2 phía
  Future<void> deleteMessagePermanently({
    required String senderId,
    required String receiverId,
    required String messageId,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final chatDoc = _firestore.collection('chats').doc(chatId);

    // 1. Xóa vĩnh viễn tin nhắn khỏi subcollection messages
    await chatDoc
        .collection('messages')
        .doc(messageId)
        .delete();

    // 2. Cập nhật lại thông tin lastMessage cho cuộc hội thoại
    try {
      final latestMsgs = await chatDoc
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latestMsgs.docs.isNotEmpty) {
        final lastData = latestMsgs.docs.first.data();
        await chatDoc.set({
          'lastMessage': lastData['text'] ?? lastData['noiDung'] ?? '',
          'noiDungCuoi': lastData['text'] ?? lastData['noiDung'] ?? '',
          'lastSenderId': lastData['senderId'] ?? lastData['nguoiGuiId'] ?? '',
        }, SetOptions(merge: true));
      } else {
        await chatDoc.set({
          'lastMessage': '',
          'noiDungCuoi': '',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error updating lastMessage on permanent delete: $e');
    }
  }

  // Stream tin nhắn an toàn, chỉ truy vấn đúng cuộc hội thoại giữa 2 người
  Stream<List<ChatMessageModel>> getMessagesStream(String userA, String userB) {
    final cleanA = userA.trim();
    final cleanB = userB.trim();
    if (cleanA.isEmpty || cleanB.isEmpty) {
      return Stream.value([]);
    }

    final chatId = getChatId(cleanA, cleanB);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          return ChatMessageModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error parsing message ${doc.id}: $e');
          return null;
        }
      }).whereType<ChatMessageModel>().toList();

      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // Stream danh sách cuộc trò chuyện gần đây của người dùng
  Stream<List<ConversationModel>> getConversationsStream(String currentUserId) {
    final cleanUid = currentUserId.trim();
    if (cleanUid.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('users', arrayContains: cleanUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          return ConversationModel.fromFirestore(doc, cleanUid);
        } catch (e) {
          debugPrint('Error parsing conversation ${doc.id}: $e');
          return null;
        }
      }).whereType<ConversationModel>().toList();

      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final messagesStreamProvider = StreamProvider.autoDispose.family<List<ChatMessageModel>, ChatParams>((ref, params) {
  final service = ref.watch(chatServiceProvider);
  return service.getMessagesStream(params.userA, params.userB);
});

final userConversationsStreamProvider = StreamProvider.autoDispose.family<List<ConversationModel>, String>((ref, userId) {
  final service = ref.watch(chatServiceProvider);
  return service.getConversationsStream(userId);
});
