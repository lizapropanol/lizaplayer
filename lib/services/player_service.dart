import 'package:just_audio/just_audio.dart';
import 'package:yandex_music/yandex_music.dart' as ym;
import 'package:http/http.dart' as http;
import 'dart:convert';

enum AudioSourceType {
  yandex,
  soundcloud
}

class AppTrack {
  final String id;
  final String title;
  final String artistName;
  final String coverUrl;
  final Duration? duration;
  final AudioSourceType source;
  final dynamic originalObject;
  final String? streamUrl;

  AppTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.coverUrl,
    this.duration,
    required this.source,
    this.originalObject,
    this.streamUrl,
  });

  factory AppTrack.fromYandex(ym.Track track) {
    String cover = '';
    if (track.coverUri != null && track.coverUri!.isNotEmpty) {
      cover = 'https://${track.coverUri!.replaceAll('%%', '400x400')}';
    }

    String artist = 'Unknown Artist';
    if (track.artists != null && track.artists!.isNotEmpty) {
      artist = track.artists!.map((a) {
        try {
          return (a as dynamic).title ?? (a as dynamic).name ?? '';
        } catch (_) {
          return '';
        }
      }).join(', ');
    }

    return AppTrack(
      id: track.id.toString(),
      title: track.title ?? 'Untitled Track',
      artistName: artist,
      coverUrl: cover,
      duration: track.durationMs != null ? Duration(milliseconds: track.durationMs!) : null,
      source: AudioSourceType.yandex,
      originalObject: track,
    );
  }

  factory AppTrack.fromSoundcloud(Map<String, dynamic> scTrack) {
    String cover = '';
    if (scTrack['artwork_url'] != null) {
      cover = scTrack['artwork_url'].toString().replaceAll('-large', '-t500x500');
    } else if (scTrack['user'] != null && scTrack['user']['avatar_url'] != null) {
      cover = scTrack['user']['avatar_url'].toString().replaceAll('-large', '-t500x500');
    }

    String artist = 'Unknown Artist';
    if (scTrack['user'] != null && scTrack['user']['username'] != null) {
      artist = scTrack['user']['username'].toString();
    }

    String? bestStreamUrl;
    if (scTrack['media'] != null && scTrack['media']['transcodings'] != null) {
      final transcodings = scTrack['media']['transcodings'] as List;
      
      var prog = transcodings.firstWhere(
        (t) => t['format'] != null && t['format']['protocol'] == 'progressive' && t['format']['mime_type'] != null && t['format']['mime_type'].toString().contains('mpeg'),
        orElse: () => null,
      );
      
      prog ??= transcodings.firstWhere(
        (t) => t['format'] != null && t['format']['protocol'] == 'progressive',
        orElse: () => null,
      );

      if (prog != null && prog['url'] != null) {
        bestStreamUrl = prog['url'].toString();
      }
    }

    return AppTrack(
      id: scTrack['id'].toString(),
      title: scTrack['title']?.toString() ?? 'Untitled Track',
      artistName: artist,
      coverUrl: cover,
      duration: scTrack['duration'] != null ? Duration(milliseconds: scTrack['duration']) : null,
      source: AudioSourceType.soundcloud,
      originalObject: scTrack,
      streamUrl: bestStreamUrl,
    );
  }
}

class PlayerService {
  PlayerService._internal();
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;

  final AudioPlayer player = AudioPlayer();
  ym.YandexMusic? _yandexClient;
  String? _soundcloudClientId;

  AppTrack? currentTrack;

  Duration? get duration => player.duration;
  double volume = 1.0;
  
  int _playbackNonce = 0;

  void setYandexClient(ym.YandexMusic client) {
    _yandexClient = client;
  }

  void setSoundcloudClientId(String clientId) {
    _soundcloudClientId = clientId;
  }

  Future<void> playPlaylist(List<AppTrack> playlist, int startIndex) async {
    final int requestId = ++_playbackNonce;
    if (playlist.isEmpty) return;

    final List<String?> urls = await Future.wait(playlist.map((track) async {
      try {
        String? url;
        if (track.source == AudioSourceType.yandex) {
          if (_yandexClient == null) return null;
          url = await _yandexClient!.tracks.getDownloadLink(track.id);
        } else {
          if (_soundcloudClientId == null) return null;
          if (track.streamUrl != null) {
            url = await _getSoundcloudStreamUrl(track.streamUrl!);
          }
        }
        return url;
      } catch (e) {
        print('Error prefetching URL for track ${track.id}: $e');
        return null;
      }
    }));

    if (requestId != _playbackNonce) return;

    final validSources = <AudioSource>[];
    for (int i = 0; i < urls.length; i++) {
      if (urls[i] != null && urls[i]!.isNotEmpty) {
        validSources.add(AudioSource.uri(Uri.parse(urls[i]!)));
      }
    }

    if (validSources.isEmpty) return;

    await player.pause();
    await player.stop();
    if (requestId != _playbackNonce) return;
    await player.setAudioSource(
      ConcatenatingAudioSource(children: validSources),
      initialIndex: startIndex,
      preload: true,
    );
    if (requestId != _playbackNonce) return;
    currentTrack = playlist[startIndex];
    await player.play();
  }

  Future<String?> _getSoundcloudStreamUrl(String initialUrl) async {
    if (_soundcloudClientId == null || _soundcloudClientId!.isEmpty) return null;
    try {
      final url = Uri.parse('$initialUrl?client_id=$_soundcloudClientId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      print('Error getting SoundCloud stream URL: $e');
    }
    return null;
  }

  void next() {
    if (player.hasNext) {
      player.seekToNext();
    }
  }

  void previous() {
    if (player.position.inSeconds > 3) {
      player.seek(Duration.zero);
    } else {
      if (player.hasPrevious) {
        player.seekToPrevious();
      }
    }
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    await player.setVolume(volume);
  }

  void dispose() {
    player.dispose();
  }
}
