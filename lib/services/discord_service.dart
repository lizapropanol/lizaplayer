import 'dart:io';
import 'dart:async';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'package:lizaplayer/services/player_service.dart';
import 'package:lizaplayer/services/token_storage.dart';

class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  DiscordRPC? _rpc;
  final PlayerService _playerService = PlayerService();
  StreamSubscription? _trackSub;
  StreamSubscription? _playSub;
  StreamSubscription? _seekSub;
  bool _enabled = false;

  Future<void> init() async {
    _enabled = await TokenStorage.getDiscordRPCEnabled();
    if (_enabled) {
      _startRPC();
    }
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (_enabled) {
      _startRPC();
    } else {
      _stopRPC();
    }
  }

  Future<void> _startRPC() async {
    try {
      await _rpc?.shutdown();
      _rpc = DiscordRPC();
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _rpc!.initialize('1495533519240429729');
      print('Discord RPC: Initialized with ID 1495533519240429729');
      
      _updatePresence();

      _trackSub?.cancel();
      _trackSub = _playerService.trackStream.listen((_) => _updatePresence());
      _playSub?.cancel();
      _playSub = _playerService.playingStream.listen((_) => _updatePresence());
      _seekSub?.cancel();
      _seekSub = _playerService.seekStream.listen((_) => _updatePresence());
    } catch (e) {
      print('Discord RPC Error: $e');
    }
  }

  Future<void> _stopRPC() async {
    _trackSub?.cancel();
    _playSub?.cancel();
    _seekSub?.cancel();
    await _rpc?.clearPresence();
    await _rpc?.shutdown();
    _rpc = null;
  }

  void _updatePresence() async {
    if (!_enabled || _rpc == null) return;

    final track = _playerService.currentTrack;
    final isPlaying = _playerService.playing;

    if (track == null) {
      await _rpc!.clearPresence();
      return;
    }

    await _rpc!.setPresence(
      DiscordPresence(
        type: DiscordActivityType.listening,
        details: track.title,
        state: isPlaying ? 'by ${track.artistName}' : 'Paused: ${track.artistName}',
        largeAsset: DiscordAsset(
          key: track.coverUrl.isNotEmpty ? null : 'logo',
          url: track.coverUrl.isNotEmpty ? track.coverUrl : null,
          text: 'lizaplayer',
        ),
        smallAsset: DiscordAsset(
          key: isPlaying ? 'play' : 'pause',
          text: isPlaying ? 'Playing' : 'Paused',
        ),
        timestamps: isPlaying && track.duration != null
          ? DiscordTimestamps(
              start: (DateTime.now().millisecondsSinceEpoch - _playerService.position.inMilliseconds) ~/ 1000,
              end: (DateTime.now().millisecondsSinceEpoch - _playerService.position.inMilliseconds + track.duration!.inMilliseconds) ~/ 1000,
            )
          : null,
      ),
    );
  }
}
