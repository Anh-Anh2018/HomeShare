import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/agora_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../data/models/chat_model.dart';
import '../../auth/providers/auth_provider.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallSession call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  Timer? _ringTimer;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    super.dispose();
  }

  Future<void> _reject() async {
    if (_handled) return;
    _handled = true;
    await ref.read(callServiceProvider).updateStatus(widget.call.id, 'rejected');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _accept() async {
    if (_handled) return;
    final granted = await CallPermissions.ensure(video: widget.call.isVideo);
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền micro và camera để nghe máy.')),
      );
      return;
    }
    _handled = true;
    await ref.read(callServiceProvider).updateStatus(widget.call.id, 'accepted');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CallScreen(call: widget.call, isCaller: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callAsync = ref.watch(_callDocProvider(widget.call.id));
    final status = callAsync.value?.status ?? widget.call.status;
    if ((status == 'cancelled' || status == 'ended' || status == 'missed') && !_handled) {
      _handled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }

    final title = widget.call.isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _reject();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.call.callerName.isNotEmpty ? widget.call.callerName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.call.callerName,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundAction(
                    color: const Color(0xFFEF4444),
                    icon: Icons.call_end,
                    label: 'Từ chối',
                    onTap: _reject,
                  ),
                  _RoundAction(
                    color: const Color(0xFF22C55E),
                    icon: widget.call.isVideo ? Icons.videocam : Icons.call,
                    label: 'Nghe máy',
                    onTap: _accept,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

final _callDocProvider = StreamProvider.family<CallSession?, String>((ref, callId) {
  return ref.watch(callServiceProvider).watchCall(callId);
});

final incomingCallProvider = StreamProvider<CallSession?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null || uid.isEmpty) return const Stream.empty();
  return ref.watch(callServiceProvider).watchIncoming(uid);
});

class CallScreen extends ConsumerStatefulWidget {
  final CallSession call;
  final bool isCaller;

  const CallScreen({super.key, required this.call, required this.isCaller});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _closing = false;
  bool _logged = false;
  String _statusText = 'Đang kết nối...';
  String? _errorText;
  int _seconds = 0;
  Timer? _timer;
  Timer? _ringTimeout;

  @override
  void initState() {
    super.initState();
    _speakerOn = widget.call.isVideo;
    _statusText = widget.isCaller ? 'Đang đổ chuông...' : 'Đang kết nối...';
    _join();
    if (widget.isCaller) {
      _ringTimeout = Timer(const Duration(seconds: 45), () {
        if (_remoteUid == null && mounted) {
          _finish(localStatus: 'missed');
        }
      });
    }
  }

  Future<void> _join() async {
    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() => _joined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _ringTimeout?.cancel();
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
            _statusText = 'Đã kết nối';
          });
          _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _seconds += 1);
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted || _closing) return;
          _finish(localStatus: 'ended');
        },
        onError: (err, msg) {
          if (!mounted) return;
          setState(() => _errorText = 'Lỗi kết nối ($err). Kiểm tra lại token và tên kênh homeshare_test.');
        },
      ));

      await engine.enableAudio();
      if (widget.call.isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      } else {
        await engine.disableVideo();
      }
      await engine.setDefaultAudioRouteToSpeakerphone(_speakerOn);

      await engine.joinChannel(
        token: AgoraConfig.token,
        channelId: AgoraConfig.channelName,
        uid: 0,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.call.isVideo,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.call.isVideo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Không vào được cuộc gọi: $e');
    }
  }

  String get _clock {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    await _engine?.setEnableSpeakerphone(next);
    if (mounted) setState(() => _speakerOn = next);
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> _finish({required String localStatus}) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    _ringTimeout?.cancel();
    final service = ref.read(callServiceProvider);
    final chat = ref.read(chatServiceProvider);
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;

    final current = await service.watchCall(widget.call.id).first;
    final alreadyClosed = current == null ||
        current.status == 'ended' ||
        current.status == 'rejected' ||
        current.status == 'cancelled' ||
        current.status == 'missed';
    if (!alreadyClosed) {
      await service.updateStatus(widget.call.id, localStatus, durationSeconds: _seconds);
    }
    if (widget.isCaller) {
      await _writeCallLog(chat, localStatus);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _writeCallLog(ChatService chat, String status) async {
    if (_logged) return;
    _logged = true;
    final kind = widget.call.isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
    final text = _seconds > 0 ? '$kind • $_clock' : '$kind nhỡ';
    final myId = widget.isCaller ? widget.call.callerId : widget.call.calleeId;
    final myName = widget.isCaller ? widget.call.callerName : widget.call.calleeName;
    final otherId = widget.isCaller ? widget.call.calleeId : widget.call.callerId;
    final otherName = widget.isCaller ? widget.call.calleeName : widget.call.callerName;
    try {
      await chat.sendMessage(
        ChatMessageModel(
          id: '',
          senderId: myId,
          senderName: myName,
          receiverId: otherId,
          text: text,
          messageType: 'text',
          timestamp: DateTime.now(),
          extraData: {'callStatus': status, 'durationSeconds': _seconds},
        ),
        receiverName: otherName,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringTimeout?.cancel();
    if (!_closing) {
      _engine?.leaveChannel();
      _engine?.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_callDocProvider(widget.call.id), (prev, next) {
      final status = next.value?.status;
      if (status == null || _closing) return;
      if (status == 'rejected') {
        setState(() => _statusText = 'Người nhận đã từ chối');
        _finish(localStatus: 'rejected');
      } else if (status == 'cancelled' || status == 'ended' || status == 'missed') {
        _finish(localStatus: status);
      }
    });

    final partnerName = widget.isCaller ? widget.call.calleeName : widget.call.callerName;
    final showVideo = widget.call.isVideo && _engine != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(localStatus: widget.isCaller && _remoteUid == null ? 'cancelled' : 'ended');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            if (showVideo && _remoteUid != null)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: const RtcConnection(channelId: AgoraConfig.channelName),
                ),
              )
            else if (showVideo && _joined)
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(partnerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _remoteUid != null ? _clock : _statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                    ],
                    const Spacer(),
                    if (showVideo && _remoteUid != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 110,
                            height: 150,
                            child: AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundAction(
                          color: _muted ? Colors.white : Colors.white24,
                          iconColor: _muted ? Colors.black : Colors.white,
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          label: _muted ? 'Bật mic' : 'Tắt mic',
                          onTap: _toggleMute,
                        ),
                        _RoundAction(
                          color: const Color(0xFFEF4444),
                          icon: Icons.call_end,
                          label: 'Cúp máy',
                          onTap: () => _finish(localStatus: widget.isCaller && _remoteUid == null ? 'cancelled' : 'ended'),
                        ),
                        _RoundAction(
                          color: _speakerOn ? Colors.white : Colors.white24,
                          iconColor: _speakerOn ? Colors.black : Colors.white,
                          icon: _speakerOn ? Icons.volume_up : Icons.hearing,
                          label: 'Loa',
                          onTap: _toggleSpeaker,
                        ),
                        if (widget.call.isVideo)
                          _RoundAction(
                            color: Colors.white24,
                            icon: Icons.cameraswitch,
                            label: 'Đổi cam',
                            onTap: _switchCamera,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
