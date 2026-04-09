import 'package:just_audio/just_audio.dart';
import 'package:yandex_music/yandex_music.dart' as ym;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:rxdart/rxdart.dart';

enum AudioSourceType { yandex, soundcloud }

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
      duration: track.durationMs != null
          ? Duration(milliseconds: track.durationMs!)
          : null,
      source: AudioSourceType.yandex,
      originalObject: track,
    );
  }

  factory AppTrack.fromSoundcloud(Map<String, dynamic> scTrack) {
    String cover = '';
    if (scTrack['artwork_url'] != null) {
      cover =
          scTrack['artwork_url'].toString().replaceAll('-large', '-t500x500');
    } else if (scTrack['user'] != null &&
        scTrack['user']['avatar_url'] != null) {
      cover = scTrack['user']['avatar_url']
          .toString()
          .replaceAll('-large', '-t500x500');
    }

    String artist = 'Unknown Artist';
    if (scTrack['user'] != null && scTrack['user']['username'] != null) {
      artist = scTrack['user']['username'].toString();
    }

    String? bestStreamUrl;
    if (scTrack['media'] != null && scTrack['media']['transcodings'] != null) {
      final transcodings = scTrack['media']['transcodings'] as List;

      var prog = transcodings.firstWhere(
        (t) =>
            t['format'] != null &&
            t['format']['protocol'] == 'progressive' &&
            t['format']['mime_type'] != null &&
            t['format']['mime_type'].toString().contains('mpeg'),
        orElse: () => null,
      );

      prog ??= transcodings.firstWhere(
        (t) => t['format'] != null && t['format']['protocol'] == 'progressive',
        orElse: () => null,
      );

      if (prog != null && prog['url'] != null) {
        bestStreamUrl = prog['url'].toString();
      }
    } else if (scTrack['stream_url'] != null) {
      bestStreamUrl = scTrack['stream_url'].toString();
    }

    return AppTrack(
      id: scTrack['id'].toString(),
      title: scTrack['title']?.toString() ?? 'Untitled Track',
      artistName: artist,
      coverUrl: cover,
      duration: scTrack['duration'] != null
          ? Duration(milliseconds: scTrack['duration'])
          : null,
      source: AudioSourceType.soundcloud,
      originalObject: scTrack,
      streamUrl: bestStreamUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artistName': artistName,
      'coverUrl': coverUrl,
      'durationMs': duration?.inMilliseconds,
      'source': source.index,
      'originalObject': source == AudioSourceType.yandex 
          ? (originalObject as ym.Track).raw 
          : originalObject,
      'streamUrl': streamUrl,
    };
  }

  factory AppTrack.fromJson(Map<String, dynamic> json) {
    final source = AudioSourceType.values[json['source']];
    return AppTrack(
      id: json['id'],
      title: json['title'],
      artistName: json['artistName'],
      coverUrl: json['coverUrl'],
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs']) : null,
      source: source,
      originalObject: source == AudioSourceType.yandex 
          ? ym.Track(json['originalObject']) 
          : json['originalObject'],
      streamUrl: json['streamUrl'],
    );
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: 'lizaplayer',
      title: title,
      artist: artistName,
      duration: duration,
      artUri: Uri.tryParse(coverUrl),
    );
  }
}

class PlayerService {
  PlayerService._internal() {
    _attachListenersToPrimary();
  }
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;

  AudioPlayer _primaryPlayer = AudioPlayer();
  AudioPlayer _secondaryPlayer = AudioPlayer();

  AudioPlayer get player => _primaryPlayer;

  ym.YandexMusic? _yandexClient;
  String? _soundcloudClientId;

  AppTrack? currentTrack;
  List<AppTrack> _currentPlaylist = [];
  int _currentIndex = -1;
  bool _isFading = false;
  int? _preloadedIndex;

  List<AppTrack> get currentPlaylist => _currentPlaylist;
  int get currentIndex => _currentIndex;

  Duration? get duration => _primaryPlayer.duration;
  Duration get position => _primaryPlayer.position;
  PlayerState get playerState => _primaryPlayer.playerState;
  ProcessingState get processingState => _primaryPlayer.processingState;
  
  double _userVolume = 1.0;
  double get volume => _userVolume;
  final _volumeController = BehaviorSubject<double>.seeded(1.0);
  Stream<double> get volumeStream => _volumeController.stream;

  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;
  final _loopModeController = BehaviorSubject<LoopMode>.seeded(LoopMode.off);
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;

  bool get hasNext =>
      _currentIndex >= 0 && _currentIndex < _currentPlaylist.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  int _playbackNonce = 0;
  Timer? _telemetryTimer;
  Timer? _fadeTimer;
  Timer? _saveStateTimer;
  int _currentTrackListenSeconds = 0;

  final _trackChangedController = BehaviorSubject<AppTrack?>();
  Stream<AppTrack?> get trackStream => _trackChangedController.stream;

  final _playingController = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get playingStream => _playingController.stream;
  bool get playing => _primaryPlayer.playing;

  final _positionController = BehaviorSubject<Duration>.seeded(Duration.zero);
  Stream<Duration> get positionStream => _positionController.stream;

  final _playerStateController = BehaviorSubject<PlayerState>.seeded(PlayerState(false, ProcessingState.idle));
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  final _durationController = BehaviorSubject<Duration?>();
  Stream<Duration?> get durationStream => _durationController.stream;

  final _processingStateController = BehaviorSubject<ProcessingState>.seeded(ProcessingState.idle);
  Stream<ProcessingState> get processingStateStream => _processingStateController.stream;

  Future<void> play() => _primaryPlayer.play();
  Future<void> pause() => _primaryPlayer.pause();
  Future<void> stop() => _primaryPlayer.stop();
  Future<void> seek(Duration position) => _primaryPlayer.seek(position);

  Future<void> restoreLastState() async {
    final playlistJsons = await TokenStorage.getLastPlaylist();
    final savedIndex = await TokenStorage.getLastIndex();
    
    if (playlistJsons.isNotEmpty && savedIndex >= 0) {
      try {
        final List<AppTrack> restoredPlaylist = playlistJsons.map((j) => AppTrack.fromJson(json.decode(j))).toList();
        final positionMs = await TokenStorage.getLastPosition();
        
        _currentPlaylist = restoredPlaylist;
        _currentIndex = savedIndex;
        currentTrack = _currentPlaylist[_currentIndex];
        
        final url = await _resolveTrackUrl(currentTrack!);
        if (url != null && url.isNotEmpty) {
          final source = AudioSource.uri(
            Uri.parse(url),
            tag: currentTrack!.toMediaItem(),
          );
          
          await _primaryPlayer.setAudioSource(source);
          
          _primaryPlayer.processingStateStream.firstWhere((state) => state == ProcessingState.ready).timeout(const Duration(seconds: 10)).then((_) async {
            await _primaryPlayer.seek(Duration(milliseconds: positionMs));
            await _primaryPlayer.setVolume(_userVolume);
            await _primaryPlayer.pause();
          }).catchError((_) {});
          
          _trackChangedController.add(currentTrack);
        }
      } catch (e) {
      }
    }
    
    _saveStateTimer?.cancel();
    _saveStateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPlaylist.isNotEmpty) {
        final playlistJsons = _currentPlaylist.map((t) => json.encode(t.toJson())).toList();
        TokenStorage.saveLastPlaylist(playlistJsons, _currentIndex);
        TokenStorage.saveLastPosition(_primaryPlayer.position.inMilliseconds);
      }
    });
  }

  void setYandexClient(ym.YandexMusic client) {
    _yandexClient = client;
  }

  void setSoundcloudClientId(String clientId) {
    _soundcloudClientId = clientId;
  }

  void setVolume(double v) {
    _userVolume = v.clamp(0.0, 1.0);
    _volumeController.add(_userVolume);
    if (!_isFading) {
      _primaryPlayer.setVolume(_userVolume);
    }
  }

  void setLoopMode(LoopMode mode) {
    _loopMode = mode;
    _primaryPlayer.setLoopMode(mode);
    _loopModeController.add(mode);
  }

  Future<void> playPlaylist(List<AppTrack> playlist, int startIndex) async {
    _resetFades();
    _currentPlaylist = List.from(playlist);
    _currentIndex = startIndex;
    currentTrack = _currentPlaylist[_currentIndex];
    _onTrackChanged();
    await _playCurrentIndex(++_playbackNonce, fadeLoad: true);
  }

  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _currentPlaylist.length) return;
    _currentIndex = index;
    _resetFades();
    currentTrack = _currentPlaylist[_currentIndex];
    _onTrackChanged();
    await _playCurrentIndex(++_playbackNonce, fadeLoad: true);
  }

  Future<String?> _resolveTrackUrl(AppTrack track) async {
    try {
      if (track.source == AudioSourceType.yandex) {
        if (_yandexClient == null) return null;
        return await _yandexClient!.tracks.getDownloadLink(track.id);
      } else {
        if (_soundcloudClientId == null) return null;
        if (track.streamUrl != null) {
          return await _getSoundcloudStreamUrl(track.streamUrl!);
        }
      }
    } catch (e) {
    }
    return null;
  }

  Future<void> _playCurrentIndex(int requestId, {bool fadeLoad = false}) async {
    if (_currentIndex < 0 || _currentIndex >= _currentPlaylist.length) return;
    final track = _currentPlaylist[_currentIndex];

    try {
      if (_preloadedIndex == _currentIndex) {
        _stateSub?.cancel();
        _posSub?.cancel();
        _playingSub?.cancel();
        _playerStateSub?.cancel();
        _durationSub?.cancel();
        
        await _primaryPlayer.stop().catchError((_) {});
        final oldPlayer = _primaryPlayer;
        _primaryPlayer = _secondaryPlayer;
        _secondaryPlayer = oldPlayer;
        
        _attachListenersToPrimary();
        _preloadedIndex = null;
      } else {
        String? url = await _resolveTrackUrl(track);
        if (requestId != _playbackNonce) return;

        if (url != null && url.isNotEmpty) {
          final source = AudioSource.uri(
            Uri.parse(url),
            tag: track.toMediaItem(),
          );
          await _primaryPlayer.setAudioSource(source).timeout(const Duration(seconds: 15));
        } else {
          next();
          return;
        }
      }

      if (requestId == _playbackNonce) {
        _primaryPlayer.setLoopMode(_loopMode);
        await _primaryPlayer.seek(Duration.zero).catchError((_) {});
        if (fadeLoad) {
          _startFadeIn();
        } else {
          _primaryPlayer.setVolume(_userVolume);
          _primaryPlayer.play().catchError((_) {});
        }
      }
    } catch (e) {
      if (requestId == _playbackNonce) next();
    }
  }

  void _startFadeIn() {
    _fadeTimer?.cancel();
    _isFading = true;
    _primaryPlayer.setVolume(0.0);
    _primaryPlayer.play().catchError((_) {});

    int currentStep = 0;
    const steps = 30;
    final volumeStep = _userVolume / steps;

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentStep++;
      final vol = (volumeStep * currentStep).clamp(0.0, _userVolume);
      _primaryPlayer.setVolume(vol);
      if (currentStep >= steps) {
        timer.cancel();
        _isFading = false;
        _primaryPlayer.setVolume(_userVolume);
      }
    });
  }

  void _startFadeOut() {
    if (_isFading) return;
    _isFading = true;
    int currentStep = 0;
    const steps = 30;
    final volumeStep = _userVolume / steps;

    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentStep++;
      final vol = (_userVolume - (volumeStep * currentStep)).clamp(0.0, _userVolume);
      _primaryPlayer.setVolume(vol);
      if (currentStep >= steps) {
        timer.cancel();
        _isFading = false;
      }
    });
  }

  Future<void> _preloadNext() async {
    if (!hasNext || _preloadedIndex == _currentIndex + 1) return;
    final nextIdx = _currentIndex + 1;
    final track = _currentPlaylist[nextIdx];
    try {
      final url = await _resolveTrackUrl(track);
      if (url != null && url.isNotEmpty) {
        _preloadedIndex = nextIdx;
        final source = AudioSource.uri(
          Uri.parse(url),
          tag: track.toMediaItem(),
        );
        await _secondaryPlayer.stop().catchError((_) {});
        await _secondaryPlayer.setAudioSource(source).timeout(const Duration(seconds: 15));
        await _secondaryPlayer.seek(Duration.zero).catchError((_) {});
        await _secondaryPlayer.setVolume(0.0);
      }
    } catch (e) {
      _preloadedIndex = null;
    }
  }

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;

  void _attachListenersToPrimary() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _playingSub?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();

    _stateSub = _primaryPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == LoopMode.one) {
          _primaryPlayer.seek(Duration.zero);
          _primaryPlayer.play();
        } else {
          next();
        }
      }
    }, onError: (_) => next());

    _playerStateSub = _primaryPlayer.playerStateStream.listen((state) {
      _playerStateController.add(state);
      _processingStateController.add(state.processingState);
    });

    _playingSub = _primaryPlayer.playingStream.listen((playing) {
      _playingController.add(playing);
    });

    _durationSub = _primaryPlayer.durationStream.listen((duration) {
      _durationController.add(duration);
    });

    _posSub = _primaryPlayer.positionStream.listen((position) {
      _positionController.add(position);
      final dur = _primaryPlayer.duration;
      if (dur != null && dur > Duration.zero) {
        final remaining = dur - position;
        if (remaining <= const Duration(seconds: 3) && remaining > Duration.zero && _loopMode != LoopMode.one) {
          _startFadeOut();
        } else if (remaining > const Duration(seconds: 3) && _isFading) {
          _resetFades();
        }
        if (remaining <= const Duration(seconds: 10) && _preloadedIndex != _currentIndex + 1 && _loopMode != LoopMode.one) {
          _preloadNext();
        }
      }
    });
  }

  void _resetFades() {
    _isFading = false;
    _fadeTimer?.cancel();
    _primaryPlayer.setVolume(_userVolume);
  }

  void _startTelemetryTracking() {
    _telemetryTimer?.cancel();
    _currentTrackListenSeconds = 0;
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_primaryPlayer.playing) {
        _currentTrackListenSeconds++;
        await TokenStorage.addListeningTime(1);
        if (_currentTrackListenSeconds == 30) {
          await TokenStorage.incrementTracksPlayed();
          if (currentTrack != null) {
            final platform = currentTrack!.source == AudioSourceType.yandex ? 'Yandex' : 'SoundCloud';
            await TokenStorage.recordTrackPlay(currentTrack!.artistName, currentTrack!.title, platform);
          }
        }
      }
    });
  }

  void _onTrackChanged() {
    _telemetryTimer?.cancel();
    _currentTrackListenSeconds = 0;
    _startTelemetryTracking();
    _trackChangedController.add(currentTrack);
  }

  void stopTelemetryTracking() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
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
    } catch (e) {}
    return null;
  }

  void next() {
    _resetFades();
    if (hasNext) {
      _currentIndex++;
      currentTrack = _currentPlaylist[_currentIndex];
      _onTrackChanged();
      _playCurrentIndex(++_playbackNonce, fadeLoad: true);
    } else if (_loopMode == LoopMode.all && _currentPlaylist.isNotEmpty) {
      _currentIndex = 0;
      currentTrack = _currentPlaylist[_currentIndex];
      _onTrackChanged();
      _playCurrentIndex(++_playbackNonce, fadeLoad: true);
    } else {
      _primaryPlayer.stop().catchError((_) {});
    }
  }

  void previous() {
    _resetFades();
    if (_primaryPlayer.position.inSeconds > 3) {
      _primaryPlayer.seek(Duration.zero).catchError((_) {});
    } else if (hasPrevious) {
      _currentIndex--;
      currentTrack = _currentPlaylist[_currentIndex];
      _onTrackChanged();
      _playCurrentIndex(++_playbackNonce, fadeLoad: true);
    }
  }

  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _playingSub?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _fadeTimer?.cancel();
    _telemetryTimer?.cancel();
    _primaryPlayer.dispose();
    _secondaryPlayer.dispose();
  }
}
