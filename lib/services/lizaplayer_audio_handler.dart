import 'package:audio_service/audio_service.dart';
import 'package:lizaplayer/services/player_service.dart';
import 'package:just_audio/just_audio.dart';

class LizaplayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final PlayerService _playerService = PlayerService();

  LizaplayerAudioHandler() {
    _playerService.trackStream.listen((track) {
      if (track != null) {
        mediaItem.add(MediaItem(
          id: track.id,
          album: 'lizaplayer',
          title: track.title,
          artist: track.artistName,
          duration: track.duration,
          artUri: Uri.tryParse(track.coverUrl),
        ));
      }
    });

    _playerService.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[state.processingState]!,
        playing: state.playing,
        updatePosition: _playerService.position,
      ));
    });

    _playerService.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    });
  }

  @override
  Future<void> play() => _playerService.play();

  @override
  Future<void> pause() => _playerService.pause();

  @override
  Future<void> seek(Duration position) => _playerService.seek(position);

  @override
  Future<void> stop() => _playerService.stop();

  @override
  Future<void> skipToNext() async => _playerService.next();

  @override
  Future<void> skipToPrevious() async => _playerService.previous();
}
