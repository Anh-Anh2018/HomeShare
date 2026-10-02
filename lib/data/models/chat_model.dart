import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Tin nhắn chuẩn hóa theo Database homeShare (DrawIO pkg_5: Trao đổi)
/// Bảng: Cuộc trò chuyện, Tin nhắn (cuocTroChuyenId, nguoiGuiId, noiDung, ngayGui...)
class ChatMessageModel {
  final String id;
  final String conversationId; // cuocTroChuyenId
  final String senderId; // nguoiGuiId
  final String senderName; // tenNguoiGui
  final String receiverId; // nguoiNhanId
  final String text; // noiDung
  final String attachmentUrl; // duongDan
  final String messageType; // loaiTinNhan_id ('text', 'image', 'location')
  final DateTime timestamp; // ngayGui
  final bool isRead; // trangThaiTinNhan: daDoc / chuaDoc

  final String status; // 'sending' | 'sent' | 'delivered' | 'read'
  final Map<String, dynamic> extraData; // Du lieu bo sung: lich hen, thong tin phong, vi tri...

  // Vietnamese DrawIO Alias Getters
  String get cuocTroChuyenId => conversationId;
  String get nguoiGuiId => senderId;
  String get tenNguoiGui => senderName;
  String get nguoiNhanId => receiverId;
  String get noiDung => text;
  String get duongDan => attachmentUrl;
  String get loaiTinNhan => messageType;
  DateTime get ngayGui => timestamp;
  bool get daDoc => isRead || status == 'read';
  String get trangThaiTinNhan => status;

  ChatMessageModel({
    required this.id,
    this.conversationId = '',
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.text,
    this.attachmentUrl = '',
    this.messageType = 'text',
    required this.timestamp,
    this.isRead = false,
    this.status = 'sent',
    this.extraData = const {},
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    return ChatMessageModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> data, String id) {
    final readVal = data['isRead'] ?? (data['trangThaiTinNhan_id'] == 'daDoc') ?? false;
    final statusVal = data['status'] ?? (readVal ? 'read' : 'sent');

    return ChatMessageModel(
      id: id,
      conversationId: data['conversationId'] ?? data['cuocTroChuyenId'] ?? '',
      senderId: data['senderId'] ?? data['nguoiGuiId'] ?? '',
      senderName: data['senderName'] ?? data['tenNguoiGui'] ?? '',
      receiverId: data['receiverId'] ?? data['nguoiNhanId'] ?? '',
      text: data['text'] ?? data['noiDung'] ?? '',
      attachmentUrl: data['attachmentUrl'] ?? data['duongDan'] ?? '',
      messageType: data['messageType'] ?? data['loaiTinNhan_id'] ?? 'text',
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : (data['ngayGui'] is Timestamp)
              ? (data['ngayGui'] as Timestamp).toDate()
              : DateTime.now(),
      isRead: readVal,
      status: statusVal,
      extraData: (data['extraData'] is Map)
          ? Map<String, dynamic>.from(data['extraData'] as Map)
          : {},
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? text,
    String? attachmentUrl,
    String? messageType,
    DateTime? timestamp,
    bool? isRead,
    String? status,
    Map<String, dynamic>? extraData,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      messageType: messageType ?? this.messageType,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      extraData: extraData ?? this.extraData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'cuocTroChuyenId': conversationId,
      'senderId': senderId,
      'nguoiGuiId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'nguoiNhanId': receiverId,
      'text': text,
      'noiDung': text,
      'attachmentUrl': attachmentUrl,
      'duongDan': attachmentUrl,
      'messageType': messageType,
      'loaiTinNhan_id': messageType,
      'timestamp': Timestamp.fromDate(timestamp),
      'ngayGui': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'status': status,
      'trangThaiTinNhan_id': status,
      'extraData': extraData,
    };
  }
}

/// Model Cuộc trò chuyện theo chuẩn DrawIO pkg_5 & SRS CDLTDD
class ConversationModel {
  final String id;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final String partnerPhone;
  final bool isLandlord;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isRead;
  final String? roomCode;
  final String? roomTitle;
  final double? roomPrice;
  final String? roomImage;

  int get computedUnread => unreadCount;
  bool get isReadVal => isRead;

  ConversationModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar = '',
    this.partnerPhone = '',
    this.isLandlord = false,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isRead = true,
    this.roomCode,
    this.roomTitle,
    this.roomPrice,
    this.roomImage,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final users = List<String>.from(data['users'] ?? data['nguoiThamGia'] ?? []);
    final partnerId = users.firstWhere((u) => u != currentUserId, orElse: () => '');
    
    DateTime timestamp = DateTime.now();
    if (data['lastTimestamp'] is Timestamp) {
      timestamp = (data['lastTimestamp'] as Timestamp).toDate();
    } else if (data['ngayGuiCuoi'] is Timestamp) {
      timestamp = (data['ngayGuiCuoi'] as Timestamp).toDate();
    }

    final userNames = (data['userNames'] is Map) ? Map<String, dynamic>.from(data['userNames'] as Map) : {};
    final partnerNames = (data['partnerNames'] is Map) ? Map<String, dynamic>.from(data['partnerNames'] as Map) : {};
    final userAvatars = (data['userAvatars'] is Map) ? Map<String, dynamic>.from(data['userAvatars'] as Map) : {};
    final userPhones = (data['userPhones'] is Map) ? Map<String, dynamic>.from(data['userPhones'] as Map) : {};

    String resolvedPartnerName = '';
    if (partnerNames.containsKey(currentUserId) && partnerNames[currentUserId]?.toString().isNotEmpty == true) {
      resolvedPartnerName = partnerNames[currentUserId].toString();
    } else if (userNames.containsKey(partnerId) && userNames[partnerId]?.toString().isNotEmpty == true) {
      resolvedPartnerName = userNames[partnerId].toString();
    } else if (data['lastSenderId'] == partnerId && data['lastSenderName'] != null) {
      resolvedPartnerName = data['lastSenderName'].toString();
    } else if (data['partnerName'] != null && data['partnerName'].toString().isNotEmpty) {
      resolvedPartnerName = data['partnerName'].toString();
    } else {
      resolvedPartnerName = 'Đối tác trao đổi';
    }

    String resolvedAvatar = userAvatars[partnerId]?.toString() ?? data['partnerAvatar'] ?? '';
    String resolvedPhone = userPhones[partnerId]?.toString() ?? data['partnerPhone'] ?? '';

    int computedUnread = 0;
    if (data['unreadFor_$currentUserId'] is num) {
      computedUnread = (data['unreadFor_$currentUserId'] as num).toInt();
    } else if (data['unreadCount'] is num) {
      computedUnread = (data['unreadCount'] as num).toInt();
    }

    final lastSenderId = data['lastSenderId']?.toString() ?? '';
    bool isReadVal = false;
    if (lastSenderId == currentUserId) {
      isReadVal = true;
    } else if (data['readBy'] is Map && data['readBy'][currentUserId] != null) {
      isReadVal = data['readBy'][currentUserId] == true;
    } else {
      isReadVal = data['isRead'] == true;
    }

    if (lastSenderId.isNotEmpty && lastSenderId != currentUserId) {
      if (!isReadVal && computedUnread <= 0) {
        computedUnread = 1;
      }
    } else if (lastSenderId == currentUserId) {
      computedUnread = 0;
      isReadVal = true;
    }

    return ConversationModel(
      id: doc.id,
      partnerId: partnerId,
      partnerName: resolvedPartnerName,
      partnerAvatar: resolvedAvatar,
      partnerPhone: resolvedPhone,
      isLandlord: data['isLandlord'] ?? false,
      lastMessage: data['lastMessage'] ?? data['noiDungCuoi'] ?? '',
      lastMessageTime: timestamp,
      unreadCount: computedUnread,
      isRead: isReadVal,
      roomCode: data['roomCode'],
      roomTitle: data['roomTitle'],
      roomPrice: (data['roomPrice'] is num) ? (data['roomPrice'] as num).toDouble() : null,
      roomImage: data['roomImage'],
    );
  }
}
