import 'package:just_audio/just_audio.dart';
import 'package:yandex_music/yandex_music.dart';

class PlayerService {
  final AudioPlayer player = AudioPlayer();
  double volume = 1.0;

  Track? currentTrack;

  Stream<Duration> get positionStream => player.positionStream;
  Duration? get duration => player.duration;

  Future<void> playTrack(Track track, YandexMusic client) async {
    currentTrack = track;

    try {
      final url = await client.tracks.getDownloadLink(track.id.toString());

      await player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        preload: true,
      );

      await player.play();
    } catch (e) {
      print('Play error: $e');
    }
  }

  Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    await player.setVolume(volume);
  }

  void dispose() {
    player.dispose();
  }
}
