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
    await _rpc?.shutdown();
    _rpc = DiscordRPC();
    await _rpc!.initialize('1342674253106516109');
    
    _updatePresence();

    _trackSub?.cancel();
    _trackSub = _playerService.trackStream.listen((_) => _updatePresence());
    _playSub?.cancel();
    _playSub = _playerService.playingStream.listen((_) => _updatePresence());
  }

  Future<void> _stopRPC() async {
    _trackSub?.cancel();
    _playSub?.cancel();
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
        details: track.title,
        state: 'by ${track.artistName}',
        largeAsset: const DiscordAsset(
          key: 'logo',
          text: 'lizaplayer',
        ),
        smallAsset: DiscordAsset(
          key: isPlaying ? 'play' : 'pause',
          text: isPlaying ? 'Playing' : 'Paused',
        ),
        timestamps: isPlaying 
          ? DiscordTimestamps(start: DateTime.now().millisecondsSinceEpoch ~/ 1000)
          : null,
      ),
    );
  }
}
