import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yandex_music/yandex_music.dart' as ym;
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/services/player_service.dart';
import 'package:lizaplayer/services/discord_service.dart';
import 'package:lizaplayer/screens/auth_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:convert';
import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';
import 'package:lizaplayer/widgets/custom_title_bar.dart';
import 'package:lizaplayer/utils/font_styler.dart';

final blurEnabledProvider = StateProvider((ref) => false);
final scaleProvider = StateProvider((ref) => 1.0);
final uiModeProvider = StateProvider((ref) => 'v2');
final v2FloatingEnabledProvider = StateProvider((ref) => false);

class LyricLine {
  final Duration time;
  final String text;
  LyricLine({required this.time, required this.text});
}

class HomeScreen extends ConsumerStatefulWidget {
  final String? yandexToken;
  final String? soundcloudClientId;

  const HomeScreen({
    this.yandexToken,
    this.soundcloudClientId,
    super.key,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin, WindowListener, FontStyler {
  ym.YandexMusic? _yandexClient;
  final PlayerService _playerService = PlayerService();
  late final TabController _tabController;
  final FocusNode _globalFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  String? _yandexToken;
  String? _soundcloudClientId;

  List<AppTrack> waveTracks = [];
  bool _loading = false;
  bool _isWaveActive = false;
  int _waveSessionId = 0;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _playlistSearchController = TextEditingController();
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerIndexSubscription;

  List<AppTrack> _likedTracks = [];
  bool _isLikesOpen = false;
  List<Map<String, dynamic>> _localPlaylists = [];
  Map<String, dynamic>? _selectedLocalPlaylist;
  List<AppTrack> _localPlaylistTracks = [];
  bool _isLoadingLocalPlaylist = false;
  final Map<String, List<AppTrack>> _localPlaylistTracksCache = {};

  bool _isInitialized = false;
  bool _isFrozen = false;
  bool _showLaunchAnimations = false;
  final Map<String, bool> _expandedSections = {};

  String _trackFilter = 'all';
  String _trackSort = 'default';

  String? _customBackgroundUrl;
  String? _customBackgroundPath;
  String? _customTrackCoverUrl;
  String? _customTrackCoverPath;

  bool _isPlaylistsListOpen = false;
  bool _loadingPlaylists = false;
  List<dynamic> _userPlaylists = [];
  dynamic _selectedUserPlaylist;
  bool _loadingPlaylistTracks = false;
  List<AppTrack> _selectedPlaylistTracks = [];
  List<String> _pendingPlaylistTrackIds = [];
  bool _loadingMorePlaylistTracks = false;

  bool _isSearchOpen = false;
  bool _isSearching = false;
  List<AppTrack> _searchResultsTracks = [];
  List<dynamic> _searchResultsArtists = [];
  List<dynamic> _searchResultsAlbums = [];
  String _lastSearchQuery = '';

  late AnimationController _pauseAnimationController;
  late Animation<double> _pauseAnimation;
  late AnimationController _prevAnimationController;
  late Animation<double> _prevAnimation;
  late AnimationController _nextAnimationController;
  late Animation<double> _nextAnimation;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  late AnimationController _waveController;
  late AnimationController _listLikeAnimationController;
  late Animation<double> _listLikeAnimation;

  List<AppTrack> _currentPlaylist = [];
  int _currentIndex = -1;
  List<AppTrack> _queueTracks = [];
  bool _showMiniPlayer = false;

  final TextEditingController _yandexTokenController = TextEditingController();
  final TextEditingController _soundcloudIdController = TextEditingController();
  bool _obscureYandexToken = true;
  bool _obscureScToken = true;
  String _waveSource = 'yandex';
  Offset _playerOffset = Offset.zero;

  bool _isPlayerExpanded = false;
  bool _isLoadingLyrics = false;
  List<LyricLine> _parsedLyrics = [];
  bool _hasSyncedLyrics = false;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {}
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'lizaplayer' && uri.host == 'track') {
      final trackId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final sourceStr = uri.queryParameters['source'];
      if (trackId.isNotEmpty) {
        final loc = AppLocalizations.of(context)!;
        _showGlassToast(loc.loading, isError: false);
        try {
          AppTrack? track;
          if (sourceStr == 'yandex') {
            if (_yandexToken != null) {
              final response = await http.get(
                Uri.parse('https://api.music.yandex.net/tracks/$trackId'),
                headers: {
                  'Authorization': 'OAuth $_yandexToken',
                  'X-Yandex-Music-Client': 'YandexMusicAndroid/24023621',
                  'User-Agent': 'Yandex-Music-API',
                },
              );
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data['result'] != null && data['result'].isNotEmpty) {
                  final ymTrack = ym.Track(data['result'][0] as Map<String, dynamic>);
                  track = AppTrack.fromYandex(ymTrack);
                }
              }
            }
          } else if (sourceStr == 'soundcloud') {
            if (_soundcloudClientId != null) {
              final scUrl = Uri.parse('https://api-v2.soundcloud.com/tracks/$trackId?client_id=$_soundcloudClientId');
              final response = await http.get(scUrl);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                track = AppTrack.fromSoundcloud(data);
              }
            }
          }
          if (track != null) {
            _playFromList([track], 0);
          } else {
             _showGlassToast(loc.noResultsFound, isError: true);
          }
        } catch (e) {
          debugPrint('Error loading deep link track: $e');
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _yandexToken = widget.yandexToken;
    _soundcloudClientId = widget.soundcloudClientId;
    _yandexTokenController.text = _yandexToken ?? '';
    _soundcloudIdController.text = _soundcloudClientId ?? '';

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_tabListener);

    _pauseAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pauseAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _pauseAnimationController, curve: Curves.easeInOut));
    _prevAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _prevAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _prevAnimationController, curve: Curves.easeInOut));
    _nextAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _nextAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _nextAnimationController, curve: Curves.easeInOut));
    _likeAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _likeAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeInOut));
    _listLikeAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _listLikeAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _listLikeAnimationController, curve: Curves.easeInOut));
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    windowManager.addListener(this);
    _initializeApp();
  }

  void _tabListener() {
    if (mounted) {
      setState(() {
        _showMiniPlayer = _tabController.index != 0;
      });
      _globalFocusNode.requestFocus();
    }
  }

  void _toggleRepeat() {
    final mode = _playerService.loopMode;
    if (mode == LoopMode.off) {
      _playerService.setLoopMode(LoopMode.one);
    } else {
      _playerService.setLoopMode(LoopMode.off);
    }
  }

  void _openArtistDetails() {
    final track = _playerService.currentTrack;
    if (track != null && track.originalObject != null) {
      if (track.source == AudioSourceType.yandex) {
        final yt = track.originalObject as ym.Track;
        if (yt.artists != null && yt.artists!.isNotEmpty) {
          _showArtistCard(yt.artists!.first);
        }
      } else {
        final scTrack = track.originalObject as Map<String, dynamic>;
        if (scTrack['user'] != null) {
          _showArtistCard(scTrack['user']);
        }
      }
    }
  }

  void _addToPlaylist() {
    final track = _playerService.currentTrack;
    if (track != null) {
      _showAddToPlaylistSheet(track);
    }
  }

  void _togglePlayback() {
    if (_playerService.playing) {
      _playerService.pause();
    } else {
      _playerService.play();
    }
  }

  void _toggleLyrics() {
    final current = _playerService.currentTrack;
    if (current == null) return;
    setState(() {
      _isPlayerExpanded = !_isPlayerExpanded;
      if (_isPlayerExpanded && _parsedLyrics.isEmpty) {
        _fetchLyrics(current.title, current.artistName);
      }
    });
  }

  void _seekRelative(Duration offset) {
    final currentPos = _playerService.position;
    final duration = _playerService.duration ?? Duration.zero;
    final newMs = (currentPos.inMilliseconds + offset.inMilliseconds)
        .clamp(0, duration.inMilliseconds);
    _playerService.seek(Duration(milliseconds: newMs));
  }

  void _handleEscape() {
    if (_isSearchOpen) {
      setState(() {
        _isSearchOpen = false;
        _searchController.clear();
      });
      return;
    }
    if (_isPlayerExpanded) {
      setState(() => _isPlayerExpanded = false);
    } else if (_isLikesOpen) {
      setState(() => _isLikesOpen = false);
    } else if (_isPlaylistsListOpen) {
      setState(() => _isPlaylistsListOpen = false);
    } else if (_selectedUserPlaylist != null) {
      setState(() => _selectedUserPlaylist = null);
    } else if (_selectedLocalPlaylist != null) {
      setState(() => _selectedLocalPlaylist = null);
    } else if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  bool _isFullScreen = false;
  double _preMuteVolume = 1.0;

  Future<void> _toggleFullScreen() async {
    final nextValue = !_isFullScreen;
    setState(() {
      _isFullScreen = nextValue;
    });
    
    if (nextValue && Platform.isWindows) {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      }
    }
    
    await windowManager.setFullScreen(nextValue);
    
    if (nextValue && Platform.isWindows) {
      await Future.delayed(const Duration(milliseconds: 200));
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.focus();
    }
  }

  void _toggleMute() {
    if (_playerService.volume > 0) {
      _preMuteVolume = _playerService.volume;
      _playerService.setVolume(0);
    } else {
      _playerService.setVolume(_preMuteVolume);
    }
  }

  void _focusSearch() {
    _tabController.animateTo(0);
    _searchController.clear();
    FocusScope.of(context).requestFocus(FocusNode());
    Future.microtask(() {
      _searchFocusNode.requestFocus();
    });
  }

  List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    final RegExp regExp = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');
    for (String line in lrc.split('\n')) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msString = match.group(3)!;
        final ms = msString.length == 2 ? int.parse(msString) * 10 : int.parse(msString);
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            time: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }
    return lines;
  }

  Future<void> _fetchLyrics(String trackTitle, String artistName) async {
    setState(() {
      _isLoadingLyrics = true;
      _parsedLyrics = [];
      _hasSyncedLyrics = false;
    });

    try {
      final cleanTitle = trackTitle.split('(')[0].trim();
      final uri = Uri.parse('https://lrclib.net/api/search?track_name=${Uri.encodeComponent(cleanTitle)}&artist_name=${Uri.encodeComponent(artistName)}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final trackData = data.first;
          final synced = trackData['syncedLyrics'] as String?;
          final plain = trackData['plainLyrics'] as String?;

          if (synced != null && synced.isNotEmpty) {
            _parsedLyrics = _parseLrc(synced);
            _hasSyncedLyrics = _parsedLyrics.isNotEmpty;
          } else if (plain != null && plain.isNotEmpty) {
            _parsedLyrics = plain.split('\n').map((e) => LyricLine(time: Duration.zero, text: e)).toList();
            _hasSyncedLyrics = false;
          } else {
            _parsedLyrics = [];
            _hasSyncedLyrics = false;
          }
        } else {
          _parsedLyrics = [];
        }
      } else {
        _parsedLyrics = [];
      }
    } catch (e) {
      debugPrint("Lyrics error: $e");
      _parsedLyrics = [LyricLine(time: Duration.zero, text: 'Ошибка загрузки текста.')];
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    await TokenStorage.initFirstInstallDate();
    
    final history = await TokenStorage.getRecentWaveTracks();
    if (mounted) {
      setState(() {
        _waveHistoryTrackIds.clear();
        _waveHistoryTrackIds.addAll(history);
      });
    }

    try {
      if (_yandexToken != null && _yandexToken!.isNotEmpty) {
        _yandexClient = ym.YandexMusic(token: _yandexToken!);
        await _yandexClient!.init();
        _playerService.setYandexClient(_yandexClient!);
      }
      if (_soundcloudClientId != null && _soundcloudClientId!.isNotEmpty) {
        _playerService.setSoundcloudClientId(_soundcloudClientId!);
      }

      _playerIndexSubscription = _playerService.trackStream.listen((track) async {
        if (_currentWaveTrack != null && (track == null || _currentWaveTrack!.id != track.id)) {
          final playedSeconds = _currentWaveTrackStartTime != null ? DateTime.now().difference(_currentWaveTrackStartTime!).inSeconds.toDouble() : 0.0;
          final durationSeconds = _currentWaveTrack!.duration?.inSeconds ?? 0;
          final isFinished = durationSeconds > 0 && playedSeconds >= durationSeconds * 0.8;
          _sendYandexWaveFeedback(_currentWaveTrack!, isFinished ? 'trackFinished' : 'skip', playedSeconds: playedSeconds);
          _currentWaveTrack = null;
        }

        if (track != null && mounted) {
          if (_isWaveActive) {
            _currentWaveTrack = track;
            _currentWaveTrackStartTime = DateTime.now();
            _sendYandexWaveFeedback(track, 'trackStarted');
          }

          setState(() {
            _currentIndex = _playerService.currentIndex;
            _currentPlaylist = _playerService.currentPlaylist;
            _queueTracks = _currentPlaylist.skip(_currentIndex + 1).toList();
            _parsedLyrics = [];
            _hasSyncedLyrics = false;
          });
          if (_isPlayerExpanded && track != null) {
            _fetchLyrics(track.title, track.artistName);
          }
        }
      });

      await _playerService.restoreLastState();

      final vol = await TokenStorage.getVolume();
      if (vol != null) {
        _playerService.setVolume(vol);
      }

      _playerStateSubscription = _playerService.playerStateStream.listen((state) {
        if (mounted) setState(() {});
      }, onError: (Object e, StackTrace st) {
        debugPrint("Player state stream error: $e\n$st");
      });

      await _loadLocalPlaylistsData();
      await _loadLikedTracks();
      _customBackgroundUrl = await TokenStorage.getCustomGifUrl();
      _customBackgroundPath = await TokenStorage.getCustomBackgroundPath();
      _customTrackCoverUrl = await TokenStorage.getCustomTrackCoverUrl();
      _customTrackCoverPath = await TokenStorage.getCustomTrackCoverPath();
      ref.read(blurEnabledProvider.notifier).state = await TokenStorage.getBlurEnabled();
      ref.read(scaleProvider.notifier).state = await TokenStorage.getScale() ?? 0.8;
      ref.read(uiModeProvider.notifier).state = await TokenStorage.getUiMode();
      ref.read(v2FloatingEnabledProvider.notifier).state = await TokenStorage.getV2FloatingEnabled();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _showLaunchAnimations = true);
          });
        });
      }
    } catch (e) {
      debugPrint("Initialization error: $e");
    }

    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 3)) {
      await Future.delayed(const Duration(seconds: 3) - elapsed);
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<List<AppTrack>> _fetchTracksByIds(List<String> storedIds) async {
    if (storedIds.isEmpty) return [];
    List<String> yaIds = [];
    List<String> scIds = [];

    for (var id in storedIds) {
      if (id.startsWith('sc:')) {
        scIds.add(id.substring(3));
      } else if (id.startsWith('ya:')) {
        yaIds.add(id.substring(3));
      } else {
        yaIds.add(id);
      }
    }

    List<AppTrack> yaTracksList = [];
    List<AppTrack> scTracksList = [];

    if (yaIds.isNotEmpty && _yandexClient != null) {
      try {
        for (var i = 0; i < yaIds.length; i += 50) {
          final chunk = yaIds.skip(i).take(50).toList();
          final yaTracks = await _yandexClient!.tracks.getTracks(chunk);
          yaTracksList.addAll(yaTracks.whereType<ym.Track>().map((t) => AppTrack.fromYandex(t)));
        }
      } catch (e) {
        debugPrint("Error fetching Yandex tracks: $e");
      }
    }

    if (scIds.isNotEmpty && _soundcloudClientId != null && _soundcloudClientId!.isNotEmpty) {
      try {
        for (var i = 0; i < scIds.length; i += 50) {
          final chunk = scIds.skip(i).take(50).toList();
          final scUrl = Uri.parse('https://api-v2.soundcloud.com/tracks?ids=${chunk.join(',')}&client_id=${_soundcloudClientId}');
          final scRes = await http.get(scUrl);
          if (scRes.statusCode == 200) {
            final data = jsonDecode(scRes.body) as List;
            scTracksList.addAll(data.map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>)));
          }
        }
      } catch (e) {
        debugPrint("Error fetching SoundCloud tracks: $e");
      }
    }

    List<AppTrack> orderedLoaded = [];
    for (var id in storedIds) {
      if (id.startsWith('sc:')) {
        final pureId = id.substring(3);
        final match = scTracksList.cast<AppTrack?>().firstWhere((t) => t?.id == pureId, orElse: () => null);
        if (match != null) orderedLoaded.add(match);
      } else {
        final pureId = id.startsWith('ya:') ? id.substring(3) : id;
        final match = yaTracksList.cast<AppTrack?>().firstWhere((t) => t?.id == pureId, orElse: () => null);
        if (match != null) orderedLoaded.add(match);
      }
    }
    return orderedLoaded;
  }

  Future<void> _loadLikedTracks() async {
    final storedIds = await TokenStorage.getLikedTrackIds();
    final tracks = await _fetchTracksByIds(storedIds);
    if (mounted) {
      setState(() {
        _likedTracks = tracks;
      });
    }
  }

  Future<void> _loadLocalPlaylistsData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('local_playlists');
    if (data != null) {
      setState(() {
        _localPlaylists = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
      for (var pl in _localPlaylists) {
        _preloadPlaylistCache(pl);
      }
    }
  }

  Future<void> _preloadPlaylistCache(Map<String, dynamic> pl) async {
    final plId = pl['id']?.toString() ?? pl['title']?.toString() ?? '';
    if (plId.isEmpty || _localPlaylistTracksCache.containsKey(plId)) return;
    
    final rawTracks = pl['tracks'] as List? ?? [];
    if (rawTracks.isEmpty) return;
    
    if (rawTracks.first is Map) {
      final tracks = (rawTracks as List).map((e) {
        final sourceStr = e['source']?.toString();
        AudioSourceType sourceType = sourceStr == 'soundcloud' ? AudioSourceType.soundcloud : AudioSourceType.yandex;
        return AppTrack(
          id: e['id']?.toString() ?? '',
          title: e['title']?.toString() ?? '',
          artistName: e['artistName']?.toString() ?? '',
          coverUrl: e['coverUrl']?.toString() ?? '',
          duration: e['durationMs'] != null ? Duration(milliseconds: e['durationMs']) : null,
          source: sourceType,
          originalObject: e['originalObject'],
          streamUrl: e['streamUrl']?.toString(),
        );
      }).toList();
      _localPlaylistTracksCache[plId] = tracks;
    } else {
      final storedIds = List<String>.from(rawTracks);
      final tracks = await _fetchTracksByIds(storedIds);
      _localPlaylistTracksCache[plId] = tracks;
    }
  }

  Future<void> _saveLocalPlaylistsData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_playlists', jsonEncode(_localPlaylists));
  }

  void _editLocalPlaylist(Map<String, dynamic> playlist) {
    final titleController = TextEditingController(text: playlist['title']);
    final imageController = TextEditingController(text: playlist['coverUri'] ?? '');
    final loc = AppLocalizations.of(context)!;
    final scale = ref.read(scaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.read(glassEnabledProvider);
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

    _showAnimatedDialog(
      context: context,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(30 * scale),
          scale: scale,
          child: Padding(
            padding: EdgeInsets.all(24 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.editPlaylist, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold))),
                SizedBox(height: 24 * scale),
                _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(16 * scale),
                  scale: scale,
                  child: TextField(
                    controller: titleController,
                    cursorColor: effectiveAccent,
                    decoration: InputDecoration(
                      hintText: loc.playlistName,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                      hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                    ),
                    style: TextStyle(fontSize: 15 * scale, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                SizedBox(height: 16 * scale),
                _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(16 * scale),
                  scale: scale,
                  child: TextField(
                    controller: imageController,
                    cursorColor: effectiveAccent,
                    decoration: InputDecoration(
                      hintText: loc.coverUrlHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                      hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                    ),
                    style: TextStyle(fontSize: 15 * scale, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                SizedBox(height: 24 * scale),
                Row(
                  children: [
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () {
                            playlist['title'] = titleController.text.trim();
                            playlist['coverUri'] = imageController.text.trim();
                            _saveLocalPlaylistsData();
                            Navigator.pop(context);
                            setState(() {
                              _selectedLocalPlaylist = playlist;
                            });
                            _showGlassToast(loc.playlistEdited);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: glassEnabled,
                            isDark: isDark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: scale,
                            borderColor: effectiveAccent.withOpacity(0.5),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                child: Text(loc.save, style: s(TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteLocalPlaylist(Map<String, dynamic> playlist) {
    final loc = AppLocalizations.of(context)!;
    final playlistName = playlist['title'] ?? loc.untitledPlaylist;
    final scale = ref.read(scaleProvider);

    _showAnimatedDialog(
      context: context,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          glassEnabled: ref.read(glassEnabledProvider),
          isDark: Theme.of(context).brightness == Brightness.dark,
          borderRadius: BorderRadius.circular(30 * scale),
          scale: ref.read(scaleProvider),
          child: Padding(
            padding: EdgeInsets.all(24 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.deletePlaylist, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold))),
                SizedBox(height: 16 * scale),
                Text(loc.deletePlaylistConfirm(playlistName), style: s(TextStyle(fontSize: 16 * scale, color: Colors.grey))),
                SizedBox(height: 24 * scale),
                Row(
                  children: [
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: ref.read(glassEnabledProvider),
                            isDark: Theme.of(context).brightness == Brightness.dark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: ref.read(scaleProvider),
                            child: Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16 * scale), child: Text(loc.cancel, style: TextStyle(fontSize: 16 * scale)))),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16 * scale),
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              final plId = playlist['id']?.toString() ?? playlist['title']?.toString() ?? '';
                              if (plId.isNotEmpty) {
                                _localPlaylistTracksCache.remove(plId);
                              }
                              _localPlaylists.remove(playlist);
                              if (_selectedLocalPlaylist == playlist) {
                                _selectedLocalPlaylist = null;
                              }
                            });
                            _saveLocalPlaylistsData();
                            Navigator.pop(context);
                            _showGlassToast(loc.playlistDeleted);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: ref.read(glassEnabledProvider),
                            isDark: Theme.of(context).brightness == Brightness.dark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: ref.read(scaleProvider),
                            borderColor: Colors.redAccent.withOpacity(0.5),
                            child: Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16 * scale), child: Text(loc.delete, style: s(TextStyle(fontSize: 16 * scale, color: Colors.redAccent, fontWeight: FontWeight.bold))))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showImportPlaylistDialog() {
    final urlController = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    final scale = ref.read(scaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.read(glassEnabledProvider);
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

    _showAnimatedDialog(
      context: context,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(30 * scale),
          scale: scale,
          child: Padding(
            padding: EdgeInsets.all(24 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.importPlaylist, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold))),
                SizedBox(height: 24 * scale),
                _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(16 * scale),
                  scale: scale,
                  child: TextField(
                    controller: urlController,
                    cursorColor: effectiveAccent,
                    decoration: InputDecoration(
                      hintText: 'https://music.yandex.ru/...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                      hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                    ),
                    style: TextStyle(fontSize: 15 * scale, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                SizedBox(height: 24 * scale),
                Row(
                  children: [
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: glassEnabled,
                            isDark: isDark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: scale,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                child: Text(loc.cancel, style: TextStyle(fontSize: 16 * scale, color: Colors.grey)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16 * scale),
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () async {
                            final url = urlController.text.trim();
                            if (url.isNotEmpty) {
                              Navigator.pop(context);
                              await _importPlaylistFromUrl(url);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: glassEnabled,
                            isDark: isDark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: scale,
                            borderColor: effectiveAccent.withOpacity(0.5),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                child: Text(loc.importPlaylist, style: s(TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  OverlayEntry _showGlassToast(String message, {bool isError = false, bool isLoading = false}) {
    final scale = ref.read(scaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.read(glassEnabledProvider);
    final overlay = Overlay.of(context);
    
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _GlassToastWidget(
        message: message,
        isError: isError,
        isLoading: isLoading,
        scale: scale,
        isDark: isDark,
        glassEnabled: glassEnabled,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
    return entry;
  }

  Future<void> _importPlaylistFromUrl(String urlText) async {
    final loc = AppLocalizations.of(context)!;
    final loadingToast = _showGlassToast(loc.syncing, isLoading: true);
    try {
      String finalUrl = urlText.trim();
      String? pageOwner;
      String? pageKind;
      
      if (finalUrl.contains('music.yandex.ru') && finalUrl.contains('playlists')) {
        try {
          final pageRes = await http.get(Uri.parse(finalUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          });
          if (pageRes.statusCode == 200) {
            final body = pageRes.body;
            final ownerMatch = RegExp(r'"owner":"([^"]+)"').firstMatch(body);
            final kindMatch = RegExp(r'"kind":(\d+)').firstMatch(body);
            
            if (ownerMatch != null) pageOwner = ownerMatch.group(1);
            if (kindMatch != null) pageKind = kindMatch.group(1);
            
            if (pageOwner != null && pageKind != null) {
              finalUrl = 'https://music.yandex.ru/users/$pageOwner/playlists/$pageKind';
            }
          }
        } catch (_) {}
      }

      if (finalUrl.contains('on.soundcloud.com') || (finalUrl.contains('music.yandex.ru') && !finalUrl.contains('users') && !finalUrl.contains('album'))) {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(finalUrl))..followRedirects = false;
        final response = await client.send(request);
        if (response.headers.containsKey('location')) {
          finalUrl = response.headers['location']!;
        }
      }

      if (finalUrl.contains('soundcloud.com')) {
        if (_soundcloudClientId != null) {
          final resUrl = Uri.parse(
              'https://api-v2.soundcloud.com/resolve?url=${Uri.encodeComponent(finalUrl)}&client_id=${_soundcloudClientId}');
          final res = await http.get(resUrl);
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['kind'] == 'playlist') {
              final rawTracks = (data['tracks'] as List);
              final List<AppTrack> tracks = [];
              final List<int> idsToFetch = [];

              for (var item in rawTracks) {
                if (item['kind'] == 'track' && item['title'] != null) {
                  tracks.add(AppTrack.fromSoundcloud(item as Map<String, dynamic>));
                } else if (item['id'] != null) {
                  idsToFetch.add(item['id'] as int);
                }
              }

              if (idsToFetch.isNotEmpty) {
                for (int i = 0; i < idsToFetch.length; i += 50) {
                  final end = (i + 50 < idsToFetch.length) ? i + 50 : idsToFetch.length;
                  final chunk = idsToFetch.sublist(i, end);
                  try {
                    final tRes = await http.get(Uri.parse(
                        'https://api-v2.soundcloud.com/tracks?ids=${chunk.join(',')}&client_id=$_soundcloudClientId'));
                    if (tRes.statusCode == 200) {
                      final List fetchedTracks = jsonDecode(tRes.body);
                      for (var ft in fetchedTracks) {
                        tracks.add(AppTrack.fromSoundcloud(ft as Map<String, dynamic>));
                      }
                    }
                  } catch (_) {}
                }
              }

              final List<AppTrack> sortedTracks = [];
              for (var raw in rawTracks) {
                final id = raw['id'].toString();
                final match = tracks.firstWhere((t) => t.id == id, orElse: () => AppTrack(id: '', title: '', artistName: '', coverUrl: '', source: AudioSourceType.soundcloud));
                if (match.id.isNotEmpty) sortedTracks.add(match);
              }

              final playlistMap = {
                'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
                'title': data['title'] ?? 'Imported SC Playlist',
                'coverUri': data['artwork_url']?.toString().replaceAll('-large', '-t500x500') ?? '',
                'tracks': sortedTracks
                    .map((t) => {
                          'id': t.id,
                          'title': t.title,
                          'artistName': t.artistName,
                          'coverUrl': t.coverUrl,
                          'durationMs': t.duration?.inMilliseconds,
                          'source': 'soundcloud',
                          'originalObject': t.originalObject,
                          'streamUrl': t.streamUrl
                        })
                    .toList(),
              };
              _localPlaylists.add(playlistMap);
              await _saveLocalPlaylistsData();
              if (mounted) {
                setState(() {});
                loadingToast.remove();
                _showGlassToast(loc.playlistImported);
                return;
              }
            }
          }
        }
      } else if (finalUrl.contains('music.yandex.ru')) {
        final uri = Uri.parse(finalUrl);
        final pathSegments = uri.pathSegments;
        String? user = pageOwner;
        String? kind = pageKind;
        bool isAlbum = false;

        if (kind == null) {
          if (pathSegments.contains('playlists')) {
            int idx = pathSegments.indexOf('playlists');
            if (idx > 0) user = pathSegments[idx - 1];
            if (idx + 1 < pathSegments.length) kind = pathSegments[idx + 1];
          } else if (pathSegments.contains('album')) {
            int idx = pathSegments.indexOf('album');
            if (idx + 1 < pathSegments.length) {
              kind = pathSegments[idx + 1];
              isAlbum = true;
            }
          }
        }

        if (kind != null && _yandexClient != null) {
          if (kind!.contains('-') && !isAlbum) {
            try {
              final searchRes = await _yandexClient!.playlists.api.search(kind!, 0, 'playlist', false);
              if (searchRes != null && searchRes['result'] != null && searchRes['result']['playlists'] != null) {
                final playlists = searchRes['result']['playlists']['results'] as List;
                if (playlists.isNotEmpty) {
                  final p = playlists.first;
                  user = p['owner']?['uid']?.toString();
                  kind = p['kind']?.toString();
                }
              }
            } catch (_) {}
          }

          dynamic result;
          final kindInt = int.tryParse(kind ?? '');
          if (kindInt != null) {
            if (isAlbum) {
              result = await _yandexClient!.albums.getAlbum(kindInt);
            } else {
              result = await _yandexClient!.playlists.getPlaylist(kindInt);
            }
          }

          if (result == null && !isAlbum && kind != null) {
            final ownersToTry = [user, 'me', 'yamusic-daily', 'yamusic-personal', 'yamusic-bestseller', 'yamusic-top', 'yamusic-charts'];
            for (var owner in ownersToTry) {
              if (owner == null && user == null && ownersToTry.indexOf(owner) == 0) continue;
              final plUrl = Uri.parse('https://api.music.yandex.net/users/${owner ?? 'me'}/playlists/$kind');
              final req = await http.get(plUrl, headers: {
                'Authorization': 'OAuth ${_yandexToken}',
                'X-Yandex-Music-Client': 'WindowsPhone/1.23',
              });
              if (req.statusCode == 200) {
                final json = jsonDecode(req.body);
                if (json['result'] != null) {
                  final res = json['result'];
                  final trackIds = (res['tracks'] as List?)?.map((t) => t['id']?.toString() ?? (t['track']?['id']?.toString())).whereType<String>().toList() ?? [];
                  if (trackIds.isNotEmpty) {
                    final tracks = await _yandexClient!.tracks.getTracks(trackIds.take(150).toList());
                    final appTracks = tracks.whereType<ym.Track>().map((t) => AppTrack.fromYandex(t)).toList();
                    final playlistMap = {
                      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
                      'title': res['title'] ?? 'Imported Yandex Playlist',
                      'coverUri': 'https://${(res['cover']?['uri'] ?? res['ogImage'] ?? '').toString().replaceAll('%%', '400x400')}',
                      'tracks': appTracks.map((t) => {'id': t.id, 'title': t.title, 'artistName': t.artistName, 'coverUrl': t.coverUrl, 'durationMs': t.duration?.inMilliseconds, 'source': 'yandex', 'originalObject': t.originalObject?.toJson()}).toList(),
                    };
                    _localPlaylists.add(playlistMap);
                    await _saveLocalPlaylistsData();
                    if (mounted) {
                      setState(() {});
                      loadingToast.remove();
                      _showGlassToast(loc.playlistImported);
                    }
                    return;
                  }
                }
              }
            }
          }

          if (result != null) {
            final List<dynamic> rawTracks = result.tracks ?? [];
            final trackIds = rawTracks.map((t) {
              if (t is ym.Track) return t.id.toString();
              if (t is Map) return t['id']?.toString() ?? (t['track']?['id']?.toString());
              try { return (t as dynamic).id?.toString() ?? (t as dynamic).track?.id?.toString(); } catch(_) { return null; }
            }).whereType<String>().toList();

            if (trackIds.isNotEmpty) {
              final tracks = await _yandexClient!.tracks.getTracks(trackIds.take(150).toList());
              final appTracks = tracks.whereType<ym.Track>().map((t) => AppTrack.fromYandex(t)).toList();
              final playlistMap = {
                'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
                'title': result.title ?? 'Imported Yandex Playlist',
                'coverUri': 'https://${result.coverUri?.replaceAll('%%', '400x400')}',
                'tracks': appTracks
                    .map((t) => {
                          'id': t.id,
                          'title': t.title,
                          'artistName': t.artistName,
                          'coverUrl': t.coverUrl,
                          'durationMs': t.duration?.inMilliseconds,
                          'source': 'yandex',
                          'originalObject': t.originalObject?.toJson()
                        })
                    .toList(),
              };
              _localPlaylists.add(playlistMap);
              await _saveLocalPlaylistsData();
              if (mounted) {
                setState(() {});
                loadingToast.remove();
                _showGlassToast(loc.playlistImported);
                return;
              }
            }
          }
        }
      }
      loadingToast.remove();
      if (mounted) _showGlassToast(loc.importFailed, isError: true);
    } catch (e) {
      debugPrint("Import failed: $e");
      loadingToast.remove();
      if (mounted) _showGlassToast("Ошибка: $e", isError: true);
    }
  }

  void _showCreatePlaylistDialog() {
    final titleController = TextEditingController();
    final imageController = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    final scale = ref.read(scaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.read(glassEnabledProvider);
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

    _showAnimatedDialog(
      context: context,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(30 * scale),
          scale: scale,
          child: Padding(
            padding: EdgeInsets.all(24 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.createPlaylist, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold))),
                SizedBox(height: 24 * scale),
                _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(16 * scale),
                  scale: scale,
                  child: TextField(
                    controller: titleController,
                    cursorColor: effectiveAccent,
                    decoration: InputDecoration(
                      hintText: loc.playlistName,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                      hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                    ),
                    style: TextStyle(fontSize: 15 * scale, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                SizedBox(height: 16 * scale),
                _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(16 * scale),
                  scale: scale,
                  child: TextField(
                    controller: imageController,
                    cursorColor: effectiveAccent,
                    decoration: InputDecoration(
                      hintText: loc.coverUrlHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                      hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                    ),
                    style: TextStyle(fontSize: 15 * scale, color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                SizedBox(height: 24 * scale),
                Row(
                  children: [
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: glassEnabled,
                            isDark: isDark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: scale,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                child: Text(loc.cancel, style: TextStyle(fontSize: 16 * scale, color: Colors.grey)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16 * scale),
                    Expanded(
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: () {
                            if (titleController.text.trim().isNotEmpty) {
                              setState(() {
                                _localPlaylists.add({
                                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                  'title': titleController.text.trim(),
                                  'coverUri': imageController.text.trim(),
                                  'tracks': [],
                                });
                              });
                              _saveLocalPlaylistsData();
                              Navigator.pop(context);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _buildGlassContainer(
                            glassEnabled: glassEnabled,
                            isDark: isDark,
                            borderRadius: BorderRadius.circular(50 * scale),
                            scale: scale,
                            borderColor: effectiveAccent.withOpacity(0.5),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                child: Text(loc.save, style: s(TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(AppTrack track) {
    final scale = ref.read(scaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.read(glassEnabledProvider);
    final loc = AppLocalizations.of(context)!;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        scale: scale,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44 * scale, height: 6 * scale, margin: EdgeInsets.symmetric(vertical: 14 * scale), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.35), borderRadius: BorderRadius.circular(10 * scale))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
                child: Row(
                  children: [
                    Text(loc.addToPlaylist, style: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, letterSpacing: -0.5 * scale)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showCreatePlaylistDialog();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
                        decoration: BoxDecoration(color: effectiveAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(12 * scale)),
                        child: Text(loc.create, style: TextStyle(color: effectiveAccent, fontWeight: FontWeight.bold, fontSize: 13.5 * scale)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8 * scale),
              if (_localPlaylists.isEmpty)
                Padding(
                  padding: EdgeInsets.all(48 * scale),
                  child: Column(
                    children: [
                      Icon(Icons.queue_music_rounded, size: 64 * scale, color: Colors.grey.withOpacity(0.3)),
                      SizedBox(height: 16 * scale),
                      Text(loc.playlistEmpty, style: TextStyle(color: Colors.grey, fontSize: 16 * scale)),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 24 * scale),
                    itemCount: _localPlaylists.length,
                    itemBuilder: (context, index) {
                      final pl = _localPlaylists[index];
                      final cover = pl['coverUri'] ?? '';
                      final tracksCount = (pl['tracks'] as List).length;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 10 * scale),
                        child: HoverScale(
                          child: InkWell(
                            onTap: () {
                              final trackId = track.source == AudioSourceType.yandex ? 'ya:${track.id}' : 'sc:${track.id}';
                              setState(() {
                                if (!(pl['tracks'] as List).contains(trackId)) {
                                  (pl['tracks'] as List).insert(0, trackId);
                                  _saveLocalPlaylistsData();
                                  
                                  final plId = pl['id']?.toString() ?? pl['title']?.toString() ?? '';
                                  if (plId.isNotEmpty && _localPlaylistTracksCache.containsKey(plId)) {
                                    _localPlaylistTracksCache[plId]!.insert(0, track);
                                  }
                                }
                              });
                              Navigator.pop(context);
                              _showGlassToast(loc.trackAdded);
                            },
                            borderRadius: BorderRadius.circular(20 * scale),
                            child: Container(
                              padding: EdgeInsets.all(12 * scale),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                                borderRadius: BorderRadius.circular(20 * scale),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12 * scale),
                                    child: CachedNetworkImage(
                                      imageUrl: cover,
                                      width: 54 * scale,
                                      height: 54 * scale,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: effectiveAccent.withOpacity(0.12),
                                        width: 54 * scale,
                                        height: 54 * scale,
                                        child: Icon(Icons.music_note_rounded, color: effectiveAccent, size: 26 * scale),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16 * scale),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pl['title'], style: s(TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                        SizedBox(height: 4 * scale),
                                        Text('$tracksCount ${loc.tracks}', style: s(TextStyle(fontSize: 13.5 * scale, color: Colors.grey.shade500))),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.add_circle_outline_rounded, color: effectiveAccent, size: 24 * scale),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadLocalPlaylistTracksDetail(Map<String, dynamic> pl) async {
    final plId = pl['id']?.toString() ?? pl['title']?.toString() ?? '';
    
    if (_localPlaylistTracksCache.containsKey(plId) && _localPlaylistTracksCache[plId]!.isNotEmpty) {
      setState(() {
        _selectedLocalPlaylist = pl;
        _localPlaylistTracks = _localPlaylistTracksCache[plId]!;
        _isLoadingLocalPlaylist = false;
      });
      return;
    }

    setState(() {
      _selectedLocalPlaylist = pl;
      _isLoadingLocalPlaylist = true;
    });

    try {
      final rawTracks = pl['tracks'] as List? ?? [];
      List<AppTrack> tracks = [];

      if (rawTracks.isNotEmpty && rawTracks.first is Map) {
        tracks = rawTracks.map((e) {
          final sourceStr = e['source']?.toString();
          AudioSourceType sourceType = sourceStr == 'soundcloud' ? AudioSourceType.soundcloud : AudioSourceType.yandex;

          return AppTrack(
            id: e['id']?.toString() ?? '',
            title: e['title']?.toString() ?? '',
            artistName: e['artistName']?.toString() ?? '',
            coverUrl: e['coverUrl']?.toString() ?? '',
            duration: e['durationMs'] != null ? Duration(milliseconds: e['durationMs']) : null,
            source: sourceType,
            originalObject: e['originalObject'],
            streamUrl: e['streamUrl']?.toString(),
          );
        }).toList();
      } else {
        final storedIds = List<String>.from(rawTracks);
        tracks = await _fetchTracksByIds(storedIds);
      }

      if (plId.isNotEmpty) {
        _localPlaylistTracksCache[plId] = tracks;
      }

      if (mounted) {
        setState(() {
          _localPlaylistTracks = tracks;
          _isLoadingLocalPlaylist = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading playlist tracks: $e");
      if (mounted) {
        setState(() {
          _isLoadingLocalPlaylist = false;
        });
        _showGlassToast("Ошибка при загрузке треков", isError: true);
      }
    }
  }

  Future<void> _loadYandexPlaylists() async {
    if (_yandexClient == null || _yandexToken == null || _yandexToken!.isEmpty) return;
    final loc = AppLocalizations.of(context)!;

    setState(() {
      _loadingPlaylists = true;
    });

    try {
      final statusReq = await HttpClient().getUrl(Uri.parse('https://api.music.yandex.net/account/status'));
      statusReq.headers.add('Authorization', 'OAuth ${_yandexToken}');
      final statusRes = await statusReq.close();
      final statusBody = await statusRes.transform(utf8.decoder).join();

      if (statusRes.statusCode == 200) {
        final uid = jsonDecode(statusBody)['result']['account']['uid'];

        List<dynamic> fetchedPlaylists = [];
        try {
          final likesReq = await HttpClient().getUrl(Uri.parse('https://api.music.yandex.net/users/$uid/playlists/3'));
          likesReq.headers.add('Authorization', 'OAuth ${_yandexToken}');
          final likesRes = await likesReq.close();
          if (likesRes.statusCode == 200) {
            final likesBody = await likesRes.transform(utf8.decoder).join();
            final likesData = jsonDecode(likesBody);
            if (likesData['result'] != null) {
              final pl = likesData['result'];
              pl['title'] = loc.yandexLikes;
              pl['isYandexLikes'] = true;
              fetchedPlaylists.add(pl);
            }
          }
        } catch (e) {
          debugPrint("Error fetching Yandex Likes: $e");
        }
        try {
          final plReq = await HttpClient().getUrl(Uri.parse('https://api.music.yandex.net/users/$uid/playlists/list'));
          plReq.headers.add('Authorization', 'OAuth ${_yandexToken}');
          final plRes = await plReq.close();
          final plBody = await plRes.transform(utf8.decoder).join();
          if (plRes.statusCode == 200) {
            final plData = jsonDecode(plBody);
            if (plData['result'] != null) {
              fetchedPlaylists.addAll(plData['result'] as List<dynamic>);
            }
          }
        } catch (e) {
          debugPrint("Error fetching Yandex Playlists: $e");
        }

        if (mounted) {
          setState(() {
            _userPlaylists = fetchedPlaylists;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading Yandex playlists: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlaylists = false;
        });
      }
    }
  }

  Future<void> _loadPlaylistTracks(dynamic playlist) async {
    if (_yandexClient == null || _yandexToken == null) return;

    setState(() {
      _loadingPlaylistTracks = true;
      _selectedPlaylistTracks = [];
      _pendingPlaylistTrackIds = [];
      _loadingMorePlaylistTracks = false;
      _selectedUserPlaylist = playlist;
    });

    try {
      final uid = playlist['uid'];
      final kind = playlist['kind'];

      final req = await HttpClient().getUrl(Uri.parse('https://api.music.yandex.net/users/$uid/playlists/$kind'));
      req.headers.add('Authorization', 'OAuth ${_yandexToken}');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();

      if (res.statusCode == 200) {
        final data = jsonDecode(body);
        final tracksData = data['result']['tracks'] as List<dynamic>? ?? [];

        List<String> trackIds = [];
        List<AppTrack> preloadedTracks = [];

        for (var t in tracksData) {
          if (t['track'] != null && t['track']['id'] != null) {
            try {
              final ymTrack = ym.Track(t['track'] as Map<String, dynamic>);
              preloadedTracks.add(AppTrack.fromYandex(ymTrack));
            } catch (e) {
              final trackId = t['track']['id'].toString();
              final albumId = (t['track']['albums'] != null && (t['track']['albums'] as List).isNotEmpty) ? t['track']['albums'][0]['id'].toString() : '';
              trackIds.add(albumId.isNotEmpty ? '$trackId:$albumId' : trackId);
            }
          } else if (t['id'] != null) {
            final trackId = t['id'].toString();
            final albumId = t['albumId']?.toString() ?? '';
            trackIds.add(albumId.isNotEmpty ? '$trackId:$albumId' : trackId);
          }
        }
        
        if (mounted && preloadedTracks.isNotEmpty) {
          setState(() {
            _selectedPlaylistTracks.addAll(preloadedTracks);
          });
        }

        if (trackIds.isNotEmpty) {
          _pendingPlaylistTrackIds = List.from(trackIds);
          await _loadNextPlaylistChunk();
        }
      }
    } catch (e) {
      debugPrint("Error loading playlist tracks: $e");
    } finally {
      if (mounted && _loadingPlaylistTracks && _selectedPlaylistTracks.isNotEmpty) {
        setState(() {
          _loadingPlaylistTracks = false;
        });
      }
    }
  }

  Future<void> _loadNextPlaylistChunk() async {
    if (_pendingPlaylistTrackIds.isEmpty || _loadingMorePlaylistTracks) return;

    if (mounted) {
      setState(() {
        _loadingMorePlaylistTracks = true;
      });
    }

    bool success = false;
    while (!success && _pendingPlaylistTrackIds.isNotEmpty) {
      const int chunkSize = 50;
      int count = (_pendingPlaylistTrackIds.length < chunkSize) ? _pendingPlaylistTrackIds.length : chunkSize;
      List<String> chunk = _pendingPlaylistTrackIds.sublist(0, count);

      try {
        final tracks = await _yandexClient!.tracks.getTracks(chunk);
        final newTracks = tracks.whereType<ym.Track>().map((t) => AppTrack.fromYandex(t)).toList();
        
        if (mounted) {
          setState(() {
            _selectedPlaylistTracks.addAll(newTracks);
            _pendingPlaylistTrackIds.removeRange(0, count);
          });
        }
        success = true;
      } catch (e) {
        debugPrint("Error fetching chunk of playlist tracks, skipping chunk: $e");
        if (mounted) {
          setState(() {
            _pendingPlaylistTrackIds.removeRange(0, count);
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _loadingMorePlaylistTracks = false;
        _loadingPlaylistTracks = false;
      });
    }
  }


  Future<void> _likeAllTracks(List<AppTrack> tracks) async {
    final loc = AppLocalizations.of(context)!;
    final tracksToLike = tracks.where((t) => !_likedTracks.any((lt) => lt.id == t.id)).toList();
    if (tracksToLike.isEmpty) {
      _showGlassToast(loc.noResultsFound, isError: true);
      return;
    }

    setState(() {
      _likedTracks.insertAll(0, tracksToLike);
    });

    final currentIds = _likedTracks.map((t) {
      if (t.source == AudioSourceType.yandex) return 'ya:${t.id}';
      return 'sc:${t.id}';
    }).toList();
    await TokenStorage.saveLikedTrackIds(currentIds);

    final syncYandex = ref.read(syncYandexLikesProvider);
    if (syncYandex && _yandexToken != null) {
      final yandexTracksToLike = tracksToLike.where((t) => t.source == AudioSourceType.yandex).toList();
      if (yandexTracksToLike.isNotEmpty) {
        try {
          final ids = yandexTracksToLike.map((t) => t.id).join(',');
          final url = Uri.parse('https://api.music.yandex.net/users/me/likes/tracks/add-multiple?track-ids=$ids');
          final request = await HttpClient().postUrl(url);
          request.headers.add('Authorization', 'OAuth ${_yandexToken}');
          request.headers.add('X-Yandex-Music-Client', 'WindowsPhone/1.23');
          await request.close();
        } catch (e) {
          debugPrint('Error syncing Yandex Like (Multiple): $e');
        }
      }
    }
    _showGlassToast('${loc.trackAdded} (${tracksToLike.length})');
  }

  Future<void> _toggleLike([AppTrack? track]) async {
    final trackToToggle = track ?? _playerService.currentTrack;
    if (trackToToggle == null) return;
    final id = trackToToggle.id;
    final willBeLiked = !_likedTracks.any((t) => t.id == id);
    setState(() {
      if (willBeLiked) {
        _likedTracks.insert(0, trackToToggle);
      } else {
        _likedTracks.removeWhere((t) => t.id == id);
      }
    });
    final currentIds = _likedTracks.map((t) {
      if (t.source == AudioSourceType.yandex) return 'ya:${t.id}';
      return 'sc:${t.id}';
    }).toList();
    await TokenStorage.saveLikedTrackIds(currentIds);

    final syncYandex = ref.read(syncYandexLikesProvider);
    if (syncYandex && trackToToggle.source == AudioSourceType.yandex && _yandexToken != null) {
      try {
        final action = willBeLiked ? 'add-multiple' : 'remove';
        final url = Uri.parse('https://api.music.yandex.net/users/me/likes/tracks/$action?track-ids=${trackToToggle.id}');
        final request = await HttpClient().postUrl(url);
        request.headers.add('Authorization', 'OAuth ${_yandexToken}');
        request.headers.add('X-Yandex-Music-Client', 'WindowsPhone/1.23');
        await request.close();
      } catch (e) {
        debugPrint('Error syncing Yandex Like: $e');
      }
    }
  }

  Widget _buildSourceIcon(AudioSourceType? source, double scale) {
    if (source == null) return SizedBox(width: 20 * scale, height: 20 * scale);
    if (source == AudioSourceType.yandex) {
      return SvgPicture.asset(
        'assets/yandex_music_icon.svg',
        width: 20 * scale,
        height: 20 * scale,
      );
    } else {
      return SvgPicture.asset(
        'assets/soundcloud_icon.svg',
        width: 20 * scale,
        height: 20 * scale,
      );
    }
  }

  void _showTrackContextMenu(BuildContext context, Offset position, AppTrack track, AppLocalizations loc, bool isDark, double passedScale) {
    final scale = ref.read(scaleProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    
    String originalLink = '';
    if (track.source == AudioSourceType.yandex) {
      String tId = track.id;
      String aId = '';
      if (track.originalObject != null && track.originalObject is ym.Track) {
        final yt = track.originalObject as ym.Track;
        if (yt.albums.isNotEmpty) {
          aId = yt.albums.first.id.toString();
        }
      }
      if (aId.isNotEmpty) {
        originalLink = 'https://music.yandex.ru/album/$aId/track/$tId';
      } else {
        originalLink = 'https://music.yandex.ru/track/$tId';
      }
    } else if (track.source == AudioSourceType.soundcloud) {
      if (track.originalObject != null && track.originalObject is Map) {
        originalLink = (track.originalObject as Map)['permalink_url']?.toString() ?? '';
      }
    }

    String playerLink = 'lizaplayer://track/${track.id}?source=${track.source == AudioSourceType.yandex ? 'yandex' : 'soundcloud'}';

    final glassEnabled = ref.read(glassEnabledProvider);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: Colors.transparent,
      elevation: 0,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(16 * scale),
            scale: scale,
            customOpacity: isDark ? 0.3 : 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context, 'start_wave'),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16 * scale)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                    child: Row(
                      children: [
                        Icon(Icons.waves_rounded, color: effectiveAccent, size: 20 * scale),
                        SizedBox(width: 12 * scale),
                        Text(loc.startWave, style: s(TextStyle(fontSize: 14 * scale, color: isDark ? Colors.white : Colors.black))),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context, 'player_link'),
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, color: effectiveAccent, size: 20 * scale),
                        SizedBox(width: 12 * scale),
                        Text(loc.copyPlayerLink, style: s(TextStyle(fontSize: 14 * scale, color: isDark ? Colors.white : Colors.black))),
                      ],
                    ),
                  ),
                ),
                if (originalLink.isNotEmpty)
                  InkWell(
                    onTap: () => Navigator.pop(context, 'original_link'),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16 * scale)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                      child: Row(
                        children: [
                          Icon(Icons.open_in_browser_rounded, color: effectiveAccent, size: 20 * scale),
                          SizedBox(width: 12 * scale),
                          Text(loc.copyOriginalLink, style: s(TextStyle(fontSize: 14 * scale, color: isDark ? Colors.white : Colors.black))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ).then((value) {
      final locValue = AppLocalizations.of(context)!;
      if (value == 'start_wave') {
        _startWaveFromTrack(track);
      } else if (value == 'player_link') {
        Clipboard.setData(ClipboardData(text: playerLink));
        _showGlassToast(locValue.copied, isError: false);
      } else if (value == 'original_link') {
        Clipboard.setData(ClipboardData(text: originalLink));
        _showGlassToast(locValue.copied, isError: false);
      }
    });
  }

  Widget _buildV2SearchResultsContent(bool glassEnabled, bool isDark, double scale, AppLocalizations loc, Color effectiveAccent) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _isSearching 
        ? Center(key: const ValueKey('searching'), child: Padding(padding: EdgeInsets.all(40 * scale), child: CircularProgressIndicator(color: effectiveAccent)))
        : SmoothScrollWrapper(
            key: const ValueKey('results'),
            builder: (context, controller) => CustomScrollView(
              controller: controller,
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_searchResultsArtists.isNotEmpty) ...[
                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24 * scale, 16 * scale, 24 * scale, 12 * scale), child: Text(loc.artists, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))))),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140 * scale,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                        itemCount: _searchResultsArtists.length,
                        itemBuilder: (context, index) {
                          final artist = _searchResultsArtists[index];
                          String name = '';
                          if (artist is Map) name = artist['username']?.toString() ?? '';
                          else try { name = (artist as dynamic).title?.toString() ?? (artist as dynamic).name?.toString() ?? ''; } catch (_) {}
                          String cover = '';
                          if (artist is Map) cover = artist['avatar_url']?.replaceAll('-large', '-t500x500') ?? '';
                          else try { cover = _getCoverUrl((artist as dynamic).coverUri); } catch (_) {}
                          final isSc = artist is Map;
                          return Padding(
                            padding: EdgeInsets.only(right: 12 * scale),
                            child: HoverScale(
                              child: GestureDetector(
                                onTap: () { setState(() => _isSearchOpen = false); _showArtistCard(artist); },
                                child: _buildGlassContainer(
                                  glassEnabled: glassEnabled,
                                  isDark: isDark,
                                  borderRadius: BorderRadius.circular(24 * scale),
                                  scale: scale,
                                  child: Container(
                                    width: 100 * scale,
                                    padding: EdgeInsets.all(12 * scale),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 32 * scale,
                                              backgroundColor: effectiveAccent.withOpacity(0.12),
                                              backgroundImage: cover.isNotEmpty ? CachedNetworkImageProvider(cover) : null,
                                              child: cover.isEmpty ? Icon(Icons.person_rounded, size: 30 * scale, color: effectiveAccent) : null,
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: EdgeInsets.all(3 * scale),
                                                decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                                                child: SvgPicture.asset(isSc ? 'assets/soundcloud_icon.svg' : 'assets/yandex_music_icon.svg', width: 14 * scale, height: 14 * scale),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10 * scale),
                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: s(TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13 * scale, fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (_searchResultsAlbums.isNotEmpty) ...[
                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24 * scale, 20 * scale, 24 * scale, 12 * scale), child: Text(loc.albums, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))))),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160 * scale,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                        itemCount: _searchResultsAlbums.length,
                        itemBuilder: (context, index) {
                          final album = _searchResultsAlbums[index];
                          String name = '';
                          if (album is Map) name = album['title']?.toString() ?? '';
                          else try { name = (album as dynamic).title?.toString() ?? ''; } catch (_) {}
                          String cover = '';
                          if (album is Map) cover = album['artwork_url']?.replaceAll('-large', '-t500x500') ?? '';
                          else try { cover = _getCoverUrl((album as dynamic).coverUri); } catch (_) {}
                          final isSc = album is Map;
                          return Padding(
                            padding: EdgeInsets.only(right: 12 * scale),
                            child: HoverScale(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _isSearchOpen = false);
                                  _showAlbumCard(context, album, scale, isDark, glassEnabled, isDark ? Colors.white : Colors.black87, loc);
                                },
                                child: _buildGlassContainer(
                                  glassEnabled: glassEnabled,
                                  isDark: isDark,
                                  borderRadius: BorderRadius.circular(24 * scale),
                                  scale: scale,
                                  child: Container(
                                    width: 120 * scale,
                                    padding: EdgeInsets.all(12 * scale),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(14 * scale),
                                              child: Container(
                                                width: 96 * scale,
                                                height: 96 * scale,
                                                color: effectiveAccent.withOpacity(0.12),
                                                child: cover.isNotEmpty 
                                                  ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.album_rounded, size: 40 * scale, color: effectiveAccent))
                                                  : Icon(Icons.album_rounded, size: 40 * scale, color: effectiveAccent),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 4 * scale,
                                              right: 4 * scale,
                                              child: Container(
                                                padding: EdgeInsets.all(4 * scale),
                                                decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(8 * scale), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                                                child: SvgPicture.asset(isSc ? 'assets/soundcloud_icon.svg' : 'assets/yandex_music_icon.svg', width: 14 * scale, height: 14 * scale),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10 * scale),
                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13 * scale, fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (_searchResultsTracks.isNotEmpty) ...[
                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24 * scale, 20 * scale, 24 * scale, 12 * scale), child: Text(loc.tracksTitle, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))))),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final i = index ~/ 2;
                          if (index.isEven) {
                            return _buildTrackTile(_searchResultsTracks[i], i, _searchResultsTracks, scale);
                          } else {
                            return Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale);
                          }
                        },
                        childCount: _searchResultsTracks.isNotEmpty ? _searchResultsTracks.length * 2 - 1 : 0,
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: 24 * scale)),
              ],
            ),
          ),
    );
  }
  Widget _buildTrackTile(AppTrack track, int index, List<AppTrack> list, double scale, {VoidCallback? onRemove, bool animate = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isPlaying = _playerService.currentTrack?.id == track.id;
    final durationText = _formatDuration(track.duration);
    final loc = AppLocalizations.of(context)!;
    final isLiked = _likedTracks.any((t) => t.id == track.id);

    Widget tile = HoverScale(
      scale: 1.015,
      child: Container(
        decoration: BoxDecoration(
          color: isPlaying ? effectiveAccent.withOpacity(isDark ? 0.13 : 0.08) : null,
          borderRadius: BorderRadius.circular(22 * scale),
        ),
        child: GestureDetector(
          onSecondaryTapDown: (details) => _showTrackContextMenu(context, details.globalPosition, track, loc, isDark, scale),
          child: InkWell(
            borderRadius: BorderRadius.circular(22 * scale),
            onTap: () => _playFromList(list, index),
            child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 13 * scale),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13 * scale),
                  child: CachedNetworkImage(
                    imageUrl: track.coverUrl,
                    width: 56 * scale,
                    height: 56 * scale,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5 * scale)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 56 * scale,
                      height: 56 * scale,
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey,
                      child: Icon(Icons.music_note_rounded, color: Colors.grey, size: 32 * scale),
                    ),
                  ),
                ),
                SizedBox(width: 18 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title.isEmpty ? loc.untitledTrack : track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: s(TextStyle(
                          fontSize: 17 * scale,
                          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                          color: isPlaying ? effectiveAccent : null,
                        )),
                      ),
                      SizedBox(height: 4 * scale),
                      ClickableArtistsText(
                        artistName: track.artistName,
                        originalArtistData: track.source == AudioSourceType.yandex
                            ? (track.originalObject is ym.Track ? (track.originalObject as ym.Track).artists : null)
                            : (track.originalObject != null && track.originalObject['user'] != null ? [track.originalObject['user']] : null),
                        fontSize: 14.5 * scale,
                        color: Colors.grey,
                        onArtistTap: _showArtistCard,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12 * scale),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(durationText, style: s(TextStyle(fontSize: 13.5 * scale, color: Colors.grey))),
                    SizedBox(width: 12 * scale),
                    _TrackTileLikeButton(
                      isLiked: isLiked,
                      onTap: () => _toggleLike(track),
                      scale: scale,
                      accentColor: effectiveAccent,
                    ),
                    SizedBox(width: 12 * scale),
                    _buildTrackSourceBadge(track.source, scale),
                    if (onRemove != null) ...[
                      SizedBox(width: 8 * scale),
                      IconButton(icon: Icon(Icons.close_rounded, size: 20 * scale, color: Colors.redAccent.withOpacity(0.7)), onPressed: onRemove),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );

    if (!animate) return tile;

    return FadeSlideEntrance(
      key: ValueKey('track_${track.id}_$index'),
      index: index,
      child: tile,
    );
  }

  Widget _buildTrackSourceBadge(AudioSourceType source, double scale) {
    return _buildSourceIcon(source, scale);
  }

  Widget _buildGlassContainer({
    required bool glassEnabled,
    required bool isDark,
    required Widget child,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(28.0)),
    double? customOpacity,
    bool enableBlur = true,
    required double scale,
    Border? customBorder,
    Color? borderColor,
    bool gradientEnabled = false,
    Color? gradientColor1,
    Color? gradientColor2,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final accent = Theme.of(context).colorScheme.primary;
        final isNone = accent.value == 0;
        
        Color glassColor;
        if (isNone) {
          glassColor = isDark 
              ? Colors.transparent 
              : (customOpacity != null ? Colors.white.withOpacity(customOpacity) : Colors.white.withOpacity(0.6));
        } else {
          final tintOpacity = customOpacity ?? (isDark ? 0.12 : 0.18);
          final baseGlass = isDark ? Colors.transparent : Colors.white.withOpacity(0.5);
          glassColor = Color.alphaBlend(accent.withOpacity(tintOpacity), baseGlass);
        }

        final color = glassEnabled ? glassColor : (isDark ? const Color(0xFF1C1C1E) : Colors.white);
        
        final effectiveBorderColor = borderColor ?? ref.watch(borderColorProvider);
        final effectiveGradientEnabled = gradientEnabled || ref.watch(borderGradientEnabledProvider);
        final Color effectiveGradientColor1 = gradientColor1 ?? ref.watch(borderGradientColor1Provider);
        final Color effectiveGradientColor2 = gradientColor2 ?? ref.watch(borderGradientColor2Provider);

        final double strokeWidth = 1.5 * scale;
        Border? border;
        if (customBorder != null) {
          border = customBorder;
        } else if (glassEnabled) {
          if (!effectiveGradientEnabled && effectiveBorderColor != Colors.transparent) {
            border = Border.all(
              color: effectiveBorderColor ?? Colors.white.withOpacity(isDark ? 0.18 : 0.25),
              width: strokeWidth,
            );
          }
        }

        Widget container = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(glassEnabled ? 0.22 : (isDark ? 0.3 : 0.08)),
                blurRadius: glassEnabled ? 35 * scale : 20 * scale,
                offset: Offset(0, 8 * scale),
              ),
            ],
          ),
          child: child,
        );

        if (glassEnabled && effectiveGradientEnabled) {
          double radius = 28.0;
          if (borderRadius is BorderRadius) {
            radius = borderRadius.topLeft.x;
          }
          container = _GradientBorderContainer(
            strokeWidth: strokeWidth,
            radius: radius,
            colors: [effectiveGradientColor1, effectiveGradientColor2],
            child: container,
          );
        }

        if (glassEnabled && enableBlur) {
          return ClipRRect(
            borderRadius: borderRadius,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _isFrozen ? 0.0 : 10.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                if (value == 0 && _isFrozen) return child!;
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: value * scale, sigmaY: value * scale),
                  child: child!,
                );
              },
              child: container,
            ),
          );
        }
        return container;
      },
    );
  }

  Widget _buildAnimatedIcon({
    required IconData icon,
    required Color color,
    required double size,
    required double containerSize,
    required double scale,
    required Color accent,
  }) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final phase = (_waveController.value + i * 0.33) % 1.0;
                final opacity = 1 - phase;
                final waveScale = 1 + phase * 0.8;
                return Transform.scale(
                  scale: waveScale,
                  child: Opacity(
                    opacity: opacity * 0.4,
                    child: Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.5 * scale),
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.09),
            ),
            child: Icon(icon, size: size, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMyWaveStart(bool isDark, AppLocalizations loc, bool glassEnabled, double scale) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primaryColor.opacity == 0 ? Colors.grey : primaryColor;
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 20 * scale),
      child: _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: BorderRadius.circular(40 * scale),
        scale: scale,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SmoothScrollWrapper(
              builder: (context, controller) => FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40 * scale, vertical: 60 * scale),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAnimatedIcon(
                            icon: Icons.waves_rounded,
                            color: effectiveAccent,
                            size: 165 * scale,
                            containerSize: 280 * scale,
                            scale: scale,
                            accent: effectiveAccent,
                          ),
                          SizedBox(height: 56 * scale),
                          Text(loc.myWave, style: s(TextStyle(fontSize: 44 * scale, fontWeight: FontWeight.bold, letterSpacing: -1.2 * scale, color: isDark ? Colors.white : Colors.black87))),
                          SizedBox(height: 16 * scale),
                          SizedBox(
                            width: 340 * scale,
                            child: Text(
                              loc.personalRecommendations,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 19.5 * scale, height: 1.35, color: Colors.grey.shade500),
                            ),
                          ),
                          SizedBox(height: 40 * scale),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGlassSourceChip(
                                sourceId: 'yandex',
                                title: 'Yandex',
                                iconColor: Colors.redAccent,
                                isSelected: _waveSource == 'yandex',
                                scale: scale,
                                isDark: isDark,
                                glassEnabled: glassEnabled,
                              ),
                              SizedBox(width: 16 * scale),
                              _buildGlassSourceChip(
                                sourceId: 'soundcloud',
                                title: 'SoundCloud',
                                iconColor: const Color(0xFFFF5500),
                                isSelected: _waveSource == 'soundcloud',
                                scale: scale,
                                isDark: isDark,
                                glassEnabled: glassEnabled,
                              ),
                            ],
                          ),
                          SizedBox(height: 60 * scale),
                          HoverScale(
                            scale: 1.05,
                            child: _buildGlassContainer(
                              glassEnabled: glassEnabled,
                              isDark: isDark,
                              borderRadius: BorderRadius.circular(40 * scale),
                              customOpacity: isDark ? 0.3 : 0.9,
                              scale: scale,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(40 * scale),
                                onTap: _loading ? null : _startMyWave,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 72 * scale, vertical: 26 * scale),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_loading)
                                        SizedBox(width: 30 * scale, height: 30 * scale, child: CircularProgressIndicator(strokeWidth: 3 * scale, color: isDark ? Colors.white : Colors.black))
                                      else
                                        Icon(Icons.play_arrow_rounded, size: 42 * scale, color: isDark ? Colors.white : Colors.black),
                                      SizedBox(width: 12 * scale),
                                      Text(_loading ? loc.loading : loc.startMyWave, style: s(TextStyle(fontSize: 23 * scale, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassSourceChip({required String sourceId, required String title, required Color iconColor, required bool isSelected, required double scale, required bool isDark, required bool glassEnabled}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accent = primaryColor.opacity == 0 ? Colors.grey : primaryColor;
    return HoverScale(
      child: InkWell(
        onTap: () => setState(() => _waveSource = sourceId),
        borderRadius: BorderRadius.circular(30 * scale),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(30 * scale),
          scale: scale,
          customOpacity: isSelected ? (isDark ? 0.3 : 0.8) : (isDark ? 0.1 : 0.4),
          customBorder: isSelected ? Border.all(color: accent, width: 2 * scale) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 12 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12 * scale, height: 12 * scale, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle)),
                SizedBox(width: 10 * scale),
                Text(title, style: s(TextStyle(fontSize: 16 * scale, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyWavePlaylist(bool isDark, AppLocalizations loc, bool glassEnabled, double scale) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final current = _playerService.currentTrack;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 20 * scale),
      child: _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: BorderRadius.circular(40 * scale),
        scale: scale,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: WavePainter(
                      _waveController.value * 2.0,
                      thin: false,
                      color: effectiveAccent,
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: WavePainter(
                      _waveController.value * 3.0,
                      thin: true,
                      color: effectiveAccent,
                    ),
                  );
                },
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40 * scale),
                  Text(
                    loc.myWave,
                    style: s(TextStyle(fontSize: 48 * scale, fontWeight: FontWeight.w900, letterSpacing: -1.5 * scale, color: isDark ? Colors.white : Colors.black87)),
                  ),
                  SizedBox(height: 8 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 6 * scale),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(20 * scale),
                    ),
                    child: Text(
                      _waveSource == 'yandex' ? loc.yandexMusic : loc.soundCloud,
                      style: s(TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                    ),
                  ),
                  SizedBox(height: 60 * scale),
                  if (current != null) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40 * scale),
                      child: Column(
                        children: [
                          Text(
                            current.title,
                            textAlign: TextAlign.center,
                            style: s(TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.bold, letterSpacing: -0.5 * scale)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 12 * scale),
                          Text(
                            current.artistName,
                            textAlign: TextAlign.center,
                            style: s(TextStyle(fontSize: 18 * scale, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 60 * scale),
                  HoverScale(
                    child: GestureDetector(
                      onTap: _startMyWave,
                      child: _buildGlassContainer(
                        glassEnabled: glassEnabled,
                        isDark: isDark,
                        borderRadius: BorderRadius.circular(30 * scale),
                        scale: scale,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32 * scale, vertical: 18 * scale),
                          child: Text(
                            loc.newWave,
                            style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, letterSpacing: 0.5 * scale)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 24 * scale,
              left: 24 * scale,
              child: HoverScale(
                child: GestureDetector(
                  onTap: () => setState(() => _isWaveActive = false),
                  child: Container(
                    padding: EdgeInsets.all(12 * scale),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87, size: 28 * scale),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyWaveTab(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    if (_isWaveActive && waveTracks.isNotEmpty) {
      return _buildMyWavePlaylist(isDark, loc, glassEnabled, scale);
    }
    return _buildMyWaveStart(isDark, loc, glassEnabled, scale);
  }

  Widget _buildPlaylistSearchField(bool glassEnabled, bool isDark, double scale, AppLocalizations loc) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      child: _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: BorderRadius.circular(30 * scale),
        scale: scale,
        child: Row(
          children: [
            SizedBox(width: 18 * scale),
            Icon(Icons.search_rounded, color: Colors.grey, size: 22 * scale),
            Expanded(
              child: TextField(
                controller: _playlistSearchController,
                onChanged: (v) => setState(() {}),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16 * scale),
                cursorColor: effectiveAccent,
                decoration: InputDecoration(
                  hintText: loc.searchTracks,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16 * scale),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 15 * scale),
                ),
              ),
            ),
            if (_playlistSearchController.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: 8 * scale),
                child: HoverScale(
                  child: IconButton(
                    icon: Icon(Icons.close_rounded, size: 20 * scale, color: Colors.grey),
                    onPressed: () => setState(() => _playlistSearchController.clear()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikesPlaylist(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final loc = AppLocalizations.of(context)!;

    var tracks = List<AppTrack>.from(_likedTracks);
    if (_trackFilter == 'yandex') {
      tracks = tracks.where((t) => t.source == AudioSourceType.yandex).toList();
    } else if (_trackFilter == 'soundcloud') {
      tracks = tracks.where((t) => t.source == AudioSourceType.soundcloud).toList();
    }

    final query = _playlistSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      tracks = tracks.where((t) => 
        t.title.toLowerCase().contains(query) || 
        t.artistName.toLowerCase().contains(query)
      ).toList();
    }

    if (_trackSort == 'title') {
      tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_trackSort == 'artist') {
      tracks.sort((a, b) => a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
    }

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40 * scale),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 20 * scale),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 24 * scale, 8 * scale, 0),
              child: Row(
                children: [
                  HoverScale(child: IconButton(onPressed: () => setState(() { _isLikesOpen = false; _trackFilter = 'all'; _trackSort = 'default'; _playlistSearchController.clear(); }), icon: Icon(Icons.arrow_back_rounded, color: effectiveAccent, size: 32 * scale))),
                  SizedBox(width: 16 * scale),
                  Container(
                    padding: EdgeInsets.all(14 * scale),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(22 * scale)),
                    child: Icon(Icons.favorite_rounded, size: 46 * scale, color: Colors.redAccent),
                  ),
                  SizedBox(width: 22 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.myLikes, style: s(TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.8 * scale))),
                        Text('${tracks.length} ${loc.tracks}', style: s(TextStyle(fontSize: 16.5 * scale, color: Colors.grey))),
                      ],
                    ),
                  ),
                  if (tracks.isNotEmpty)
                    HoverScale(
                      child: InkWell(
                        onTap: () {
                          final tList = List<AppTrack>.from(tracks)..shuffle();
                          _playFromList(tList, 0);
                        },
                        borderRadius: BorderRadius.circular(20 * scale),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                          decoration: BoxDecoration(color: effectiveAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20 * scale)),
                          child: Row(
                            children: [
                              Icon(Icons.shuffle_rounded, color: effectiveAccent, size: 20 * scale),
                              SizedBox(width: 8 * scale),
                              Text(loc.shuffleAll, style: s(TextStyle(color: effectiveAccent, fontWeight: FontWeight.bold, fontSize: 14 * scale))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              child: Row(
                children: [
                  Text(loc.filter, style: s(TextStyle(fontSize: 14 * scale, color: Colors.grey, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12 * scale),
                  _buildMiniOption(label: loc.all, selected: _trackFilter == 'all', onTap: () => setState(() => _trackFilter = 'all'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: 'Yandex', selected: _trackFilter == 'yandex', onTap: () => setState(() => _trackFilter = 'yandex'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: 'SoundCloud', selected: _trackFilter == 'soundcloud', onTap: () => setState(() => _trackFilter = 'soundcloud'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  const Spacer(),
                  Text(loc.sort, style: s(TextStyle(fontSize: 14 * scale, color: Colors.grey, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12 * scale),
                  _buildMiniOption(label: loc.none, selected: _trackSort == 'default', onTap: () => setState(() => _trackSort = 'default'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: loc.sortByTitle, selected: _trackSort == 'title', onTap: () => setState(() => _trackSort = 'title'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: loc.sortByArtist, selected: _trackSort == 'artist', onTap: () => setState(() => _trackSort = 'artist'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                ],
              ),
            ),
            SizedBox(height: 16 * scale),
            _buildPlaylistSearchField(glassEnabled, isDark, scale, loc),
            SizedBox(height: 12 * scale),
            Expanded(
              child: tracks.isEmpty && _trackFilter == 'all'
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: 120 * scale, color: Colors.redAccent.withOpacity(0.4)),
                          SizedBox(height: 40 * scale),
                          Text(loc.noLikesYet, style: s(TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))),
                          SizedBox(height: 16 * scale),
                          SizedBox(width: 280 * scale, child: Text(loc.likeToFill, textAlign: TextAlign.center, style: s(TextStyle(fontSize: 17.5 * scale, height: 1.4, color: Colors.grey.shade500)))),
                        ],
                      ),
                    )
                  : tracks.isEmpty
                      ? Center(child: Text(loc.noResultsFound, style: s(TextStyle(fontSize: 20 * scale, color: Colors.grey))))
                      : SmoothScrollWrapper(
                          builder: (context, controller) => ListView.separated(
                            controller: controller,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                            itemCount: tracks.length,
                            separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                            itemBuilder: (context, index) => _buildTrackTile(tracks[index], index, tracks, scale),
                          ),
                        ),
            ),
          ],
        ),
      ),
      scale: scale,
    );
  }

  Widget _buildUserPlaylistsList(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final loc = AppLocalizations.of(context)!;
    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40 * scale),
      scale: scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 20 * scale),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 24 * scale, 8 * scale, 0),
              child: Row(
                children: [
                  HoverScale(child: IconButton(onPressed: () => setState(() => _isPlaylistsListOpen = false), icon: Icon(Icons.arrow_back_rounded, color: effectiveAccent, size: 32 * scale))),
                  SizedBox(width: 16 * scale),
                  Container(
                    padding: EdgeInsets.all(14 * scale),
                    decoration: BoxDecoration(color: effectiveAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(22 * scale)),
                    child: Icon(Icons.queue_music_rounded, size: 46 * scale, color: effectiveAccent),
                  ),
                  SizedBox(width: 22 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.myPlaylists, style: s(TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.8 * scale))),
                        Text('${_userPlaylists.length} ${loc.playlists}', style: TextStyle(fontSize: 16.5 * scale, color: Colors.grey)),
                      ],
                    ),
                  ),
                  HoverScale(
                    child: IconButton(
                      onPressed: _loadingPlaylists ? null : _loadYandexPlaylists,
                      icon: _loadingPlaylists 
                        ? SizedBox(width: 24 * scale, height: 24 * scale, child: CircularProgressIndicator(strokeWidth: 2.5 * scale, color: effectiveAccent)) 
                        : Icon(Icons.refresh_rounded, color: effectiveAccent, size: 32 * scale)
                    )
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingPlaylists && _userPlaylists.isEmpty
                  ? Center(child: CircularProgressIndicator(color: effectiveAccent))
                  : SmoothScrollWrapper(
                      builder: (context, controller) => GridView.builder(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.all(24 * scale),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ((MediaQuery.of(context).size.width * 0.85) / (160 * scale)).floor() < 2 ? 2 : ((MediaQuery.of(context).size.width * 0.85) / (160 * scale)).floor(),
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 24 * scale,
                          mainAxisSpacing: 24 * scale,
                        ),
                        itemCount: _userPlaylists.length,
                        itemBuilder: (context, index) {
                          final pl = _userPlaylists[index];
                          final title = pl['title'] ?? loc.untitledPlaylist;
                          final trackCount = pl['trackCount']?.toString() ?? '0';
                          final isYandexLikes = pl['isYandexLikes'] == true;
                          
                          String coverUrl = '';
                          if (pl['cover'] != null && pl['cover']['uri'] != null) {
                            coverUrl = _getCoverUrl(pl['cover']['uri'], size: '400x400');
                          } else if (pl['ogImage'] != null) {
                            coverUrl = _getCoverUrl(pl['ogImage'], size: '400x400');
                          }
                          return FadeSlideEntrance(
                            index: index,
                            child: InkWell(
                              onTap: () => _loadPlaylistTracks(pl),
                              borderRadius: BorderRadius.circular(24 * scale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10 * scale, offset: Offset(0, 5 * scale))]),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24 * scale),
                                        child: CachedNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.withOpacity(0.3), 
                                            child: Icon(
                                              isYandexLikes ? Icons.favorite_rounded : Icons.queue_music_rounded, 
                                              size: 50 * scale, 
                                              color: isYandexLikes ? Colors.redAccent : Colors.grey
                                            )
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12 * scale),
                                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(TextStyle(fontWeight: FontWeight.w700, fontSize: 16 * scale, color: isDark ? Colors.white : Colors.black87))),
                                  SizedBox(height: 4 * scale),
                                  Text('$trackCount ${loc.tracks}', style: s(TextStyle(color: Colors.grey, fontSize: 14 * scale, fontWeight: FontWeight.w500))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPlaylistDetail(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final loc = AppLocalizations.of(context)!;
    
    final title = _selectedUserPlaylist?['title'] ?? loc.untitledPlaylist;
    final trackCount = _selectedUserPlaylist?['trackCount']?.toString() ?? '0';
    final isYandexLikes = _selectedUserPlaylist?['isYandexLikes'] == true;
    
    String coverUrl = '';
    if (_selectedUserPlaylist != null) {
      if (_selectedUserPlaylist['cover'] != null && _selectedUserPlaylist['cover']['uri'] != null) {
        coverUrl = _getCoverUrl(_selectedUserPlaylist['cover']['uri'], size: '400x400');
      } else if (_selectedUserPlaylist['ogImage'] != null) {
        coverUrl = _getCoverUrl(_selectedUserPlaylist['ogImage'], size: '400x400');
      }
    }

    var tracks = List<AppTrack>.from(_selectedPlaylistTracks);
    if (_trackFilter == 'yandex') {
      tracks = tracks.where((t) => t.source == AudioSourceType.yandex).toList();
    } else if (_trackFilter == 'soundcloud') {
      tracks = tracks.where((t) => t.source == AudioSourceType.soundcloud).toList();
    }

    final query = _playlistSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      tracks = tracks.where((t) => 
        t.title.toLowerCase().contains(query) || 
        t.artistName.toLowerCase().contains(query)
      ).toList();
    }

    if (_trackSort == 'title') {
      tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_trackSort == 'artist') {
      tracks.sort((a, b) => a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
    }

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40 * scale),
      scale: scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 20 * scale),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 24 * scale, 8 * scale, 0),
              child: Row(
                children: [
                  HoverScale(child: IconButton(onPressed: () => setState(() { _selectedUserPlaylist = null; _trackFilter = 'all'; _trackSort = 'default'; _playlistSearchController.clear(); }), icon: Icon(Icons.arrow_back_rounded, color: effectiveAccent, size: 32 * scale))),
                  SizedBox(width: 16 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16 * scale),
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      width: 64 * scale,
                      height: 64 * scale,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: effectiveAccent.withOpacity(0.15), 
                        child: Icon(
                          isYandexLikes ? Icons.favorite_rounded : Icons.queue_music_rounded, 
                          size: 32 * scale, 
                          color: isYandexLikes ? Colors.redAccent : effectiveAccent
                        )
                      ),
                    ),
                  ),
                  SizedBox(width: 22 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: s(TextStyle(fontSize: 30 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.5 * scale)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('$trackCount ${loc.tracks}', style: s(TextStyle(fontSize: 16.5 * scale, color: Colors.grey))),
                      ],
                    ),
                  ),
                  if (tracks.isNotEmpty && !_loadingPlaylistTracks)
                    HoverScale(
                      child: InkWell(
                        onTap: () {
                          final tList = List<AppTrack>.from(tracks)..shuffle();
                          _playFromList(tList, 0);
                        },
                        borderRadius: BorderRadius.circular(20 * scale),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                          decoration: BoxDecoration(color: effectiveAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20 * scale)),
                          child: Row(
                            children: [
                              Icon(Icons.shuffle_rounded, color: effectiveAccent, size: 20 * scale),
                              SizedBox(width: 8 * scale),
                              Text(loc.shuffleAll, style: s(TextStyle(color: effectiveAccent, fontWeight: FontWeight.bold, fontSize: 14 * scale))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              child: Row(
                children: [
                  Text(loc.filter, style: s(TextStyle(fontSize: 14 * scale, color: Colors.grey, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12 * scale),
                  _buildMiniOption(label: loc.all, selected: _trackFilter == 'all', onTap: () => setState(() => _trackFilter = 'all'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: 'Yandex', selected: _trackFilter == 'yandex', onTap: () => setState(() => _trackFilter = 'yandex'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: 'SoundCloud', selected: _trackFilter == 'soundcloud', onTap: () => setState(() => _trackFilter = 'soundcloud'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  const Spacer(),
                  Text(loc.sort, style: s(TextStyle(fontSize: 14 * scale, color: Colors.grey, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12 * scale),
                  _buildMiniOption(label: loc.none, selected: _trackSort == 'default', onTap: () => setState(() => _trackSort = 'default'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: loc.sortByTitle, selected: _trackSort == 'title', onTap: () => setState(() => _trackSort = 'title'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: loc.sortByArtist, selected: _trackSort == 'artist', onTap: () => setState(() => _trackSort = 'artist'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                ],
              ),
            ),
            SizedBox(height: 16 * scale),
            _buildPlaylistSearchField(glassEnabled, isDark, scale, loc),
            SizedBox(height: 12 * scale),
            Expanded(
              child: _loadingPlaylistTracks
                  ? Center(child: CircularProgressIndicator(color: effectiveAccent))
                  : tracks.isEmpty
                      ? Center(child: Text(query.isNotEmpty ? loc.noResultsFound : loc.playlistEmpty, style: TextStyle(fontSize: 20 * scale, color: Colors.grey)))
                      : SmoothScrollWrapper(
                          builder: (context, controller) => ListView.separated(
                            controller: controller,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                            itemCount: tracks.length + (_pendingPlaylistTrackIds.isNotEmpty ? 1 : 0),
                            separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                            itemBuilder: (context, index) {
                              if (index == tracks.length) {
                                if (!_loadingMorePlaylistTracks) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextPlaylistChunk());
                                }
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                    child: CircularProgressIndicator(color: effectiveAccent),
                                  ),
                                );
                              }
                              return _buildTrackTile(tracks[index], index, tracks, scale);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniOption({required String label, required bool selected, required VoidCallback onTap, required double scale, required bool glassEnabled, required bool isDark}) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
      child: Text(label, style: s(TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)))),    );

    return Padding(
      padding: EdgeInsets.only(right: 8 * scale),
      child: HoverScale(
        child: GestureDetector(
          onTap: onTap,
          child: glassEnabled
            ? _buildGlassContainer(
                glassEnabled: true,
                isDark: isDark,
                borderRadius: BorderRadius.circular(12 * scale),
                scale: scale,
                customBorder: selected ? Border.all(color: effectiveAccent, width: 1.5 * scale) : null,
                child: content,
              )
            : Container(
                decoration: BoxDecoration(
                  color: selected ? effectiveAccent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: content,
              ),
        ),
      ),
    );
  }

  Widget _buildLocalPlaylistDetail(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final loc = AppLocalizations.of(context)!;
    
    final title = _selectedLocalPlaylist?['title'] ?? loc.untitledPlaylist;
    final coverUrl = _selectedLocalPlaylist?['coverUri'] ?? '';

    var tracks = List<AppTrack>.from(_localPlaylistTracks);
    if (_trackFilter == 'yandex') {
      tracks = tracks.where((t) => t.source == AudioSourceType.yandex).toList();
    } else if (_trackFilter == 'soundcloud') {
      tracks = tracks.where((t) => t.source == AudioSourceType.soundcloud).toList();
    }

    final query = _playlistSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      tracks = tracks.where((t) => 
        t.title.toLowerCase().contains(query) || 
        t.artistName.toLowerCase().contains(query)
      ).toList();
    }

    if (_trackSort == 'title') {
      tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_trackSort == 'artist') {
      tracks.sort((a, b) => a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
    }

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40 * scale),
      scale: scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 20 * scale),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 24 * scale, 8 * scale, 0),
              child: Row(
                children: [
                  HoverScale(child: IconButton(onPressed: () => setState(() { _selectedLocalPlaylist = null; _trackFilter = 'all'; _trackSort = 'default'; _playlistSearchController.clear(); }), icon: Icon(Icons.arrow_back_rounded, color: effectiveAccent, size: 32 * scale))),
                  SizedBox(width: 8 * scale),
                  HoverScale(
                    child: GestureDetector(
                      onTap: () => _editLocalPlaylist(_selectedLocalPlaylist!),
                      child: Container(
                        width: 48 * scale,
                        height: 48 * scale,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16 * scale),
                        ),
                        child: Icon(Icons.edit_rounded, size: 24 * scale, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  HoverScale(
                    child: GestureDetector(
                      onTap: () => _deleteLocalPlaylist(_selectedLocalPlaylist!),
                      child: Container(
                        width: 48 * scale,
                        height: 48 * scale,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16 * scale),
                        ),
                        child: Icon(Icons.delete_rounded, size: 24 * scale, color: Colors.redAccent.withOpacity(0.8)),
                      ),
                    ),
                  ),
                  SizedBox(width: 16 * scale),                  ClipRRect(
                    borderRadius: BorderRadius.circular(16 * scale),
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      width: 64 * scale,
                      height: 64 * scale,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: effectiveAccent.withOpacity(0.15), child: Icon(Icons.queue_music_rounded, size: 32 * scale, color: effectiveAccent)),
                    ),
                  ),
                  SizedBox(width: 22 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: s(TextStyle(fontSize: 30 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.5 * scale)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${tracks.length} ${loc.tracks}', style: s(TextStyle(fontSize: 16.5 * scale, color: Colors.grey))),
                      ],
                    ),
                  ),
                  if (tracks.isNotEmpty && !_isLoadingLocalPlaylist)
                    HoverScale(
                      child: InkWell(
                        onTap: () {
                          final tList = List<AppTrack>.from(tracks)..shuffle();
                          _playFromList(tList, 0);
                        },
                        borderRadius: BorderRadius.circular(20 * scale),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                          decoration: BoxDecoration(color: effectiveAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20 * scale)),
                          child: Row(
                            children: [
                              Icon(Icons.shuffle_rounded, color: effectiveAccent, size: 20 * scale),
                              SizedBox(width: 8 * scale),
                              Text(loc.shuffleAll, style: s(TextStyle(color: effectiveAccent, fontWeight: FontWeight.bold, fontSize: 14 * scale))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (tracks.isNotEmpty && !_isLoadingLocalPlaylist)
                    SizedBox(width: 12 * scale),
                  if (tracks.isNotEmpty && !_isLoadingLocalPlaylist)
                    HoverScale(
                      child: InkWell(
                        onTap: () => _likeAllTracks(tracks),
                        borderRadius: BorderRadius.circular(20 * scale),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                          decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20 * scale)),
                          child: Row(
                            children: [
                              Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20 * scale),
                              SizedBox(width: 8 * scale),
                              Text(loc.likeAll, style: s(TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 14 * scale))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              child: Row(
                children: [
                  Text(loc.filter, style: s(TextStyle(fontSize: 14 * scale, color: Colors.grey, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12 * scale),
                  _buildMiniOption(label: loc.all, selected: _trackFilter == 'all', onTap: () => setState(() => _trackFilter = 'all'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: 'Yandex', selected: _trackFilter == 'yandex', onTap: () => setState(() => _trackFilter = 'yandex'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: 'SoundCloud', selected: _trackFilter == 'soundcloud', onTap: () => setState(() => _trackFilter = 'soundcloud'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  const Spacer(),
                  Text(loc.sort, style: s(TextStyle(fontSize: 14 * scale, color: Colors.grey, fontWeight: FontWeight.bold))),
                  SizedBox(width: 12 * scale),
                  _buildMiniOption(label: loc.none, selected: _trackSort == 'default', onTap: () => setState(() => _trackSort = 'default'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: loc.sortByTitle, selected: _trackSort == 'title', onTap: () => setState(() => _trackSort = 'title'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                  _buildMiniOption(label: loc.sortByArtist, selected: _trackSort == 'artist', onTap: () => setState(() => _trackSort = 'artist'), scale: scale, glassEnabled: glassEnabled, isDark: isDark),
                ],
              ),
            ),
            SizedBox(height: 16 * scale),
            _buildPlaylistSearchField(glassEnabled, isDark, scale, loc),
            SizedBox(height: 12 * scale),
            Expanded(
              child: _isLoadingLocalPlaylist
                  ? Center(child: CircularProgressIndicator(color: effectiveAccent))
                  : tracks.isEmpty
                      ? Center(child: Text(loc.noResultsFound, style: s(TextStyle(fontSize: 20 * scale, color: Colors.grey))))
                      : SmoothScrollWrapper(
                          builder: (context, controller) => ListView.separated(
                            controller: controller,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                            itemCount: tracks.length,
                            separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                            itemBuilder: (context, index) => _buildTrackTile(
                              tracks[index], 
                              index, 
                              tracks, 
                              scale,
                              onRemove: () {
                                final id = tracks[index].id;
                                final tid = tracks[index].source == AudioSourceType.yandex ? 'ya:$id' : 'sc:$id';
                                setState(() {
                                  (_selectedLocalPlaylist!['tracks'] as List).remove(tid);
                                  _localPlaylistTracks.removeWhere((t) => t.id == id);
                                  
                                  final plId = _selectedLocalPlaylist!['id']?.toString() ?? _selectedLocalPlaylist!['title']?.toString() ?? '';
                                  if (plId.isNotEmpty && _localPlaylistTracksCache.containsKey(plId)) {
                                    _localPlaylistTracksCache[plId]!.removeWhere((t) => t.id == id);
                                  }
                                  
                                  _saveLocalPlaylistsData();
                                });
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final loc = AppLocalizations.of(context)!;

    Widget content;

    if (_isLikesOpen) {
      content = Padding(
        key: const ValueKey('likes'),
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildLikesPlaylist(glassEnabled, scale),
      );
    } else if (_selectedUserPlaylist != null) {
      content = Padding(
        key: const ValueKey('user_playlist'),
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildUserPlaylistDetail(glassEnabled, scale),
      );
    } else if (_selectedLocalPlaylist != null) {
      content = Padding(
        key: const ValueKey('local_playlist'),
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildLocalPlaylistDetail(glassEnabled, scale),
      );
    } else if (_isPlaylistsListOpen) {
      content = Padding(
        key: const ValueKey('playlists_list'),
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildUserPlaylistsList(glassEnabled, scale),
      );
    } else {
      content = Padding(
        key: const ValueKey('main_playlists'),
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(40 * scale),
          scale: scale,
          child: SmoothScrollWrapper(
            builder: (context, controller) => FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: SingleChildScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 4 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlaylistCard(
                      title: loc.myLikes,
                      subtitle: '${_likedTracks.length} ${loc.tracks}',
                      icon: Icons.favorite_rounded,
                      iconColor: Colors.redAccent,
                      onTap: () => setState(() => _isLikesOpen = true),
                      onLongPress: () => _startWaveFromPlaylist(_likedTracks),
                      glassEnabled: glassEnabled,
                      isDark: isDark,
                      scale: scale,
                    ),
                    _buildPlaylistCard(
                      title: loc.myPlaylists,
                      subtitle: _userPlaylists.isNotEmpty ? '${_userPlaylists.length} ${loc.playlists}' : loc.syncYandex,
                      icon: Icons.queue_music_rounded,
                      iconColor: effectiveAccent,
                      onTap: () {
                        setState(() => _isPlaylistsListOpen = true);
                        if (_userPlaylists.isEmpty) {
                          _loadYandexPlaylists();
                        }
                      },
                      glassEnabled: glassEnabled,
                      isDark: isDark,
                      scale: scale,
                    ),
                    SizedBox(height: 24 * scale),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.localPlaylists, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold))),
                          Row(
                            children: [
                              HoverScale(
                                child: InkWell(
                                  onTap: _showCreatePlaylistDialog,
                                  borderRadius: BorderRadius.circular(14 * scale),
                                  child: _buildGlassContainer(
                                    glassEnabled: glassEnabled,
                                    isDark: isDark,
                                    borderRadius: BorderRadius.circular(14 * scale),
                                    scale: scale,
                                    child: Padding(
                                      padding: EdgeInsets.all(8 * scale),
                                      child: Icon(Icons.add_rounded, color: effectiveAccent, size: 28 * scale),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12 * scale),
                              HoverScale(
                                child: InkWell(
                                  onTap: _showImportPlaylistDialog,
                                  borderRadius: BorderRadius.circular(14 * scale),
                                  child: _buildGlassContainer(
                                    glassEnabled: glassEnabled,
                                    isDark: isDark,
                                    borderRadius: BorderRadius.circular(14 * scale),
                                    scale: scale,
                                    child: Padding(
                                      padding: EdgeInsets.all(8 * scale),
                                      child: Icon(Icons.link_rounded, color: effectiveAccent, size: 28 * scale),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    if (_localPlaylists.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                        child: Text(loc.playlistEmpty, style: TextStyle(color: Colors.grey, fontSize: 16 * scale)),
                      )
                    else
                      for (var pl in _localPlaylists)
                        _buildPlaylistCard(
                          title: pl['title'] ?? loc.untitledPlaylist,
                          subtitle: '${(pl['tracks'] as List).length} ${loc.tracks}',
                          icon: Icons.my_library_music_rounded,
                          iconColor: effectiveAccent,
                          onTap: () => _loadLocalPlaylistTracksDetail(pl),
                          onLongPress: () => _startWaveFromPlaylist((pl['tracks'] as List).map((e) => AppTrack(
                                id: e['id'],
                                title: e['title'],
                                artistName: e['artistName'],
                                coverUrl: e['coverUrl'] ?? '',
                                duration: Duration(milliseconds: e['durationMs'] ?? 0),
                                source: e['source'] == 'soundcloud' ? AudioSourceType.soundcloud : AudioSourceType.yandex,
                                streamUrl: e['streamUrl'],
                              )).toList()),
                          onEdit: () => _editLocalPlaylist(pl),
                          onDelete: () => _deleteLocalPlaylist(pl),
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          scale: scale,
                          coverUrl: pl['coverUri'],
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: content,
    );
  }


  Widget _buildPlaylistCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap, VoidCallback? onLongPress, required bool glassEnabled, required bool isDark, required double scale, String? coverUrl, VoidCallback? onEdit, VoidCallback? onDelete}) {
    final effectiveIconColor = iconColor.opacity == 0 ? Colors.grey : iconColor;
    return Padding(
      padding: EdgeInsets.only(bottom: 16 * scale),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(28 * scale),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(28 * scale),
          scale: scale,
          child: Padding(
            padding: EdgeInsets.all(20 * scale),
            child: Row(
                children: [
                  if (coverUrl != null && coverUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18 * scale),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        width: 64 * scale,
                        height: 64 * scale,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 64 * scale, height: 64 * scale,
                          decoration: BoxDecoration(color: effectiveIconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(18 * scale)),
                          child: Icon(icon, size: 34 * scale, color: effectiveIconColor),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 64 * scale,
                      height: 64 * scale,
                      decoration: BoxDecoration(color: effectiveIconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(18 * scale)),
                      child: Icon(icon, size: 34 * scale, color: effectiveIconColor),
                    ),
                  SizedBox(width: 20 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: s(TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w600))),
                        SizedBox(height: 4 * scale),
                        Text(subtitle, style: s(TextStyle(fontSize: 15.5 * scale, color: Colors.grey.shade500))),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    Padding(
                      padding: EdgeInsets.only(left: 8 * scale),
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            width: 44 * scale,
                            height: 44 * scale,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14 * scale),
                            ),
                            child: Icon(Icons.edit_rounded, size: 20 * scale, color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    Padding(
                      padding: EdgeInsets.only(left: 8 * scale),
                      child: HoverScale(
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: 44 * scale,
                            height: 44 * scale,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14 * scale),
                            ),
                            child: Icon(Icons.delete_rounded, size: 20 * scale, color: Colors.redAccent.withOpacity(0.8)),
                          ),
                        ),
                      ),
                    ),
                  if (onEdit == null && onDelete == null)
                    Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24 * scale),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Future<Map<String, dynamic>> _getScArtistDetails(Map user) async {
    final artistId = user['id']?.toString() ?? user['urn']?.toString().split(':').last;
    if (artistId == null || _soundcloudClientId == null) return {};

    List<AppTrack> loadedTracks = [];
    List<dynamic> loadedAlbums = [];
    String? bio = user['description'];

    try {
      final tracksUrl = Uri.parse('https://api-v2.soundcloud.com/users/$artistId/tracks?client_id=${_soundcloudClientId}&limit=50');
      final res = await http.get(tracksUrl);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['collection'] != null) {
          loadedTracks = (data['collection'] as List)
              .where((item) => item['kind'] == 'track' || item['stream_url'] != null)
              .map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>))
              .where((t) => t.streamUrl != null)
              .toList();
        } else if (data is List) {
          loadedTracks = data
              .where((item) => item['kind'] == 'track' || item['stream_url'] != null)
              .map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>))
              .where((t) => t.streamUrl != null)
              .toList();
        }
      }

      final albumsUrl = Uri.parse('https://api-v2.soundcloud.com/users/$artistId/playlists?client_id=${_soundcloudClientId}&limit=20');
      final aRes = await http.get(albumsUrl);
      if (aRes.statusCode == 200) {
        final aData = jsonDecode(aRes.body);
        if (aData['collection'] != null) {
          loadedAlbums = (aData['collection'] as List).map((p) {
            return {
              'id': p['id'],
              'title': p['title'],
              'year': p['created_at']?.toString().substring(0, 4) ?? '',
              'coverUri': p['artwork_url']?.toString().replaceAll('-large', '-t500x500') ?? '',
              'isSc': true,
              'track_count': p['track_count']
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching SoundCloud artist details: $e");
    }

    return {
      'tracks': loadedTracks,
      'albums': loadedAlbums,
      'bio': bio,
    };
  }

  Future<Map<String, dynamic>> _getArtistDetails(dynamic artist) async {
    if (artist is Map) {
      return _getScArtistDetails(artist);
    }

    final artistId = artist.id?.toString();
    if (artistId == null || _yandexClient == null) return {};

    List<AppTrack> loadedTracks = [];
    List<dynamic> loadedAlbums = [];
    String? bio;

    try {
      final infoUrl = Uri.parse('https://api.music.yandex.net/artists/$artistId/brief-info');
      final infoReq = await HttpClient().getUrl(infoUrl);
      infoReq.headers.add('Authorization', 'OAuth ${_yandexToken}');
      final infoRes = await infoReq.close();
      final infoBody = await infoRes.transform(utf8.decoder).join();
      
      if (infoRes.statusCode == 200) {
        final data = jsonDecode(infoBody)['result'];
        if (data != null) {
          if (data['albums'] != null) loadedAlbums = data['albums'] as List;
          if (data['artist'] != null && data['artist']['description'] != null && data['artist']['description']['text'] != null) {
            bio = data['artist']['description']['text'];
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching Yandex artist brief info: $e");
    }

    try {
      final tracksUrl = Uri.parse('https://api.music.yandex.net/artists/$artistId/tracks');
      final tracksReq = await HttpClient().getUrl(tracksUrl);
      tracksReq.headers.add('Authorization', 'OAuth ${_yandexToken}');
      final tracksRes = await tracksReq.close();
      final tracksBody = await tracksRes.transform(utf8.decoder).join();

      if (tracksRes.statusCode == 200) {
        final data = jsonDecode(tracksBody);
        final result = data['result'];
        if (result != null && result['tracks'] != null) {
          final trackIds = (result['tracks'] as List).map((t) => t['id']?.toString()).where((id) => id != null).cast<String>().toList();
          if (trackIds.isNotEmpty) {
            final idsToLoad = trackIds.take(200).toList();
            final tracks = await _yandexClient!.tracks.getTracks(idsToLoad);
            loadedTracks = tracks.whereType<ym.Track>().map((t) => AppTrack.fromYandex(t)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching Yandex artist tracks: $e");
    }

    return {
      'tracks': loadedTracks,
      'albums': loadedAlbums,
      'bio': bio,
    };
  }

  Future<List<AppTrack>> _getAlbumTracks(dynamic album) async {
    if (album is Map && (album['isSc'] == true || album['permalink'] != null)) {
      try {
        final playlistId = album['id'];
        final url = Uri.parse('https://api-v2.soundcloud.com/playlists/$playlistId?client_id=${_soundcloudClientId}');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['tracks'] != null) {
            return (data['tracks'] as List)
                .where((item) => item['media'] != null)
                .map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>))
                .where((t) => t.streamUrl != null)
                .toList();
          }
        }
      } catch (e) {
        debugPrint("Error fetching SoundCloud album tracks: $e");
      }
      return [];
    }

    try {
      String? albumId;
      if (album is Map) {
        albumId = album['id']?.toString();
      } else {
        try {
          albumId = (album as dynamic).id?.toString();
        } catch (_) {}
      }
      if (albumId == null || _yandexClient == null) return [];

      final url = Uri.parse('https://api.music.yandex.net/albums/$albumId/with-tracks');
      final request = await HttpClient().getUrl(url);
      request.headers.add('Authorization', 'OAuth ${_yandexToken}');
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final result = data['result'];
        if (result != null && result['volumes'] != null) {
          final volumes = result['volumes'] as List;
          List<String> trackIds = [];
          for (var volume in volumes) {
            for (var track in volume) {
              if (track['id'] != null) trackIds.add(track['id'].toString());
            }
          }
          if (trackIds.isNotEmpty) {
            final tracks = await _yandexClient!.tracks.getTracks(trackIds);
            return tracks.whereType<ym.Track>().map((t) => AppTrack.fromYandex(t)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching Yandex album tracks: $e");
    }
    return [];
  }

  void _showAnimatedDialog({required BuildContext context, required Widget child}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => child,
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  void _showAllAlbums(BuildContext context, String artistName, List albums, double scale, bool isDark, bool glassEnabled, Color textColor, AppLocalizations loc) {
    final fallBackTitle = loc.untitledPlaylist;
    _showAnimatedDialog(
      context: context,
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          int crossAxisCount = (screenWidth * 0.85 / (160 * scale)).floor();
          if (crossAxisCount < 2) crossAxisCount = 2;
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(32 * scale),
            child: SizedBox(
              width: screenWidth * 0.85,
              height: screenHeight * 0.85,
              child: _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                scale: scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50 * scale),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: HoverScale(child: IconButton(icon: Icon(Icons.arrow_back_rounded, color: textColor), onPressed: () => Navigator.pop(context))),
                      title: Text("${loc.popularReleases}: $artistName", style: s(TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                    ),
                    body: SmoothScrollWrapper(
                      builder: (context, controller) => GridView.builder(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.all(24 * scale),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 24 * scale,
                          mainAxisSpacing: 24 * scale,
                        ),
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final album = albums[index];
                          final title = album['title'] ?? fallBackTitle;
                          final year = album['year']?.toString() ?? '';
                          final isSc = album is Map && album['isSc'] == true;
                          final coverUrl = isSc ? (album['coverUri'] ?? '') : _getCoverUrl(album['coverUri'], size: '400x400');
                          return FadeSlideEntrance(
                            index: index,
                            child: HoverScale(
                              child: InkWell(
                                onTap: () => _showAlbumCard(context, album, scale, isDark, glassEnabled, textColor, loc),
                                borderRadius: BorderRadius.circular(24 * scale),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10 * scale, offset: Offset(0, 5 * scale))]),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(24 * scale),
                                          child: CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(color: isDark ? const Color(0xFF2C2C2E) : Colors.grey, child: Icon(Icons.album, size: 50 * scale, color: Colors.grey)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12 * scale),
                                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(TextStyle(fontWeight: FontWeight.w700, fontSize: 16 * scale, color: textColor))),
                                    SizedBox(height: 4 * scale),
                                    Text(year, style: s(TextStyle(color: Colors.grey, fontSize: 14 * scale, fontWeight: FontWeight.w500))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      )
    );
  }

  void _showAllTracks(BuildContext context, String title, List<AppTrack> tracks, double scale, bool isDark, bool glassEnabled, Color textColor) {
    _showAnimatedDialog(
      context: context,
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(32 * scale),
            child: SizedBox(
              width: screenWidth * 0.85,
              height: screenHeight * 0.85,
              child: _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                scale: scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50 * scale),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: HoverScale(child: IconButton(icon: Icon(Icons.arrow_back_rounded, color: textColor), onPressed: () => Navigator.pop(context))),
                      title: Text(title, style: s(TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                    ),
                    body: SmoothScrollWrapper(
                      builder: (context, controller) => ListView.separated(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                        itemCount: tracks.length,
                        separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                        itemBuilder: (context, index) => _buildTrackTile(tracks[index], index, tracks, scale),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      )
    );
  }

  void _showAlbumCard(BuildContext context, dynamic album, double scale, bool isDark, bool glassEnabled, Color textColor, AppLocalizations loc) {
    String title = loc.untitledPlaylist;
    String year = '';
    String coverUrl = '';

    if (album is Map) {
      title = album['title']?.toString() ?? loc.untitledPlaylist;
      year = album['year']?.toString() ?? album['created_at']?.toString().substring(0, 4) ?? '';
      final isSc = album['isSc'] == true || album['permalink'] != null;
      coverUrl = isSc 
          ? (album['artwork_url']?.toString().replaceAll('-large', '-t500x500') ?? album['coverUri'] ?? '') 
          : _getCoverUrl(album['coverUri'], size: '400x400');
    } else {
      try {
        title = (album as dynamic).title?.toString() ?? loc.untitledPlaylist;
        year = (album as dynamic).year?.toString() ?? '';
        coverUrl = _getCoverUrl((album as dynamic).coverUri, size: '400x400');
      } catch (_) {}
    }

    _showAnimatedDialog(
      context: context,
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(32 * scale),
            child: SizedBox(
              width: screenWidth * 0.85,
              height: screenHeight * 0.85,
              child: _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                scale: scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50 * scale),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: FutureBuilder<List<AppTrack>>(
                      future: _getAlbumTracks(album),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final tracks = snapshot.data ?? [];
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(32 * scale),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24 * scale),
                                    child: CachedNetworkImage(
                                      imageUrl: coverUrl,
                                      width: 120 * scale,
                                      height: 120 * scale,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey, child: Center(child: CircularProgressIndicator(strokeWidth: 2 * scale))),
                                      errorWidget: (_, __, ___) => Container(color: isDark ? const Color(0xFF2C2C2E) : Colors.grey, child: Icon(Icons.album, color: Colors.grey, size: 60 * scale)),
                                    ),
                                  ),
                                  SizedBox(width: 24 * scale),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(title, style: s(TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.bold, color: textColor)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        SizedBox(height: 8 * scale),
                                        Text('${loc.playlists} • $year', style: s(TextStyle(fontSize: 16 * scale, color: Colors.grey))),
                                      ],
                                    ),
                                  ),
                                  HoverScale(child: IconButton(icon: Icon(Icons.close_rounded, size: 36 * scale, color: isDark ? Colors.white70 : Colors.black54), onPressed: () => Navigator.of(context).pop())),
                                ],
                              ),
                            ),
                            Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08)),
                            Expanded(
                              child: tracks.isEmpty
                                  ? Center(child: Text(loc.noResultsFound, style: TextStyle(color: Colors.grey, fontSize: 18 * scale)))
                                  : SmoothScrollWrapper(
                                      builder: (context, controller) => ListView.separated(
                                        controller: controller,
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                                        itemCount: tracks.length,
                                        separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                                        itemBuilder: (context, index) => _buildTrackTile(tracks[index], index, tracks, scale),
                                      ),
                                    ),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      )
    );
  }

  Future<void> _showArtistCard(dynamic artist) async {
    final scale = ref.read(scaleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassEnabled = ref.read(glassEnabledProvider);
    final loc = AppLocalizations.of(context)!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = Theme.of(context).colorScheme.primary;

    _showAnimatedDialog(
      context: context,
      child: Builder(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(32 * scale),
            child: SizedBox(
              width: screenWidth * 0.85,
              height: screenHeight * 0.85,
              child: _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                scale: scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50 * scale),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: FutureBuilder<Map<String, dynamic>>(
                      future: _getArtistDetails(artist),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final data = snapshot.data ?? {};
                        final tracks = (data['tracks'] as List<AppTrack>?) ?? [];
                        final albums = (data['albums'] as List<dynamic>?) ?? [];
                        final bio = data['bio'] as String?;

                        String artistName = 'Unknown Artist';
                        String coverUrl = '';
                        if (artist is Map) {
                          artistName = artist['username']?.toString() ?? artist['title']?.toString() ?? 'Unknown Artist';
                          coverUrl = artist['avatar_url']?.toString().replaceAll('-large', '-t500x500') ?? '';
                        } else {
                          try {
                            artistName = (artist as dynamic).title ?? (artist as dynamic).name ?? 'Unknown Artist';
                            coverUrl = _getCoverUrl((artist as dynamic).coverUri, size: '200x200');
                          } catch (_) {}
                        }
                        
                        final previewTracks = tracks.take(10).toList();

                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(32 * scale),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(50 * scale),
                                    child: CachedNetworkImage(
                                      imageUrl: coverUrl,
                                      width: 80 * scale,
                                      height: 80 * scale,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey, child: Center(child: CircularProgressIndicator(strokeWidth: 2 * scale))),
                                      errorWidget: (_, __, ___) => Container(color: isDark ? const Color(0xFF2C2C2E) : Colors.grey, child: Icon(Icons.person, color: Colors.grey, size: 40 * scale)),
                                    ),
                                  ),
                                  SizedBox(width: 24 * scale),
                                  Expanded(child: Text(artistName, style: s(TextStyle(fontSize: 32 * scale, fontWeight: FontWeight.bold, color: textColor)), maxLines: 2, overflow: TextOverflow.ellipsis)),                                  HoverScale(child: IconButton(icon: Icon(Icons.close_rounded, size: 36 * scale, color: isDark ? Colors.white70 : Colors.black54), onPressed: () => Navigator.of(context).pop())),
                                ],
                              ),
                            ),
                            Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08)),
                            Expanded(
                              child: SmoothScrollWrapper(
                                builder: (context, controller) => SingleChildScrollView(
                                  controller: controller,
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (bio != null && bio.isNotEmpty) ...[
                                        Padding(padding: EdgeInsets.fromLTRB(32 * scale, 24 * scale, 32 * scale, 8 * scale), child: Text(loc.aboutArtist, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor)))),
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 32 * scale), child: Text(bio, style: TextStyle(fontSize: 16.5 * scale, color: isDark ? Colors.grey : Colors.grey, height: 1.4))),
                                        SizedBox(height: 16 * scale),
                                      ],
                                      if (albums.isNotEmpty) ...[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(32 * scale, 24 * scale, 32 * scale, 16 * scale),
                                          child: HoverScale(
                                            child: InkWell(
                                              onTap: () => _showAllAlbums(context, artistName, albums, scale, isDark, glassEnabled, textColor, loc),
                                              borderRadius: BorderRadius.circular(12 * scale),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(loc.popularReleases, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor))),
                                                  SizedBox(width: 8 * scale),
                                                  Icon(Icons.chevron_right_rounded, size: 26 * scale, color: primaryColor.opacity == 0 ? Colors.grey : primaryColor),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: 230 * scale,
                                          child: SmoothScrollWrapper(
                                            builder: (context, hController) => ListView.separated(
                                              controller: hController,
                                              padding: EdgeInsets.symmetric(horizontal: 32 * scale),
                                              scrollDirection: Axis.horizontal,
                                              physics: const BouncingScrollPhysics(),
                                              itemCount: albums.length,
                                              separatorBuilder: (_, __) => SizedBox(width: 20 * scale),
                                              itemBuilder: (ctx, i) {
                                                final album = albums[i];
                                                final title = album['title'] ?? loc.untitledPlaylist;
                                                final year = album['year']?.toString() ?? '';
                                                final isSc = album is Map && album['isSc'] == true;
                                                final cover = isSc ? (album['coverUri'] ?? '') : _getCoverUrl(album['coverUri'], size: '400x400');
                                                return FadeSlideEntrance(
                                                  index: i,
                                                  child: HoverScale(
                                                    child: InkWell(
                                                      onTap: () => _showAlbumCard(context, album, scale, isDark, glassEnabled, textColor, loc),
                                                      borderRadius: BorderRadius.circular(24 * scale),
                                                      child: SizedBox(
                                                        width: 150 * scale,
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Container(
                                                              decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10 * scale, offset: Offset(0, 5 * scale))]),
                                                              child: ClipRRect(
                                                                borderRadius: BorderRadius.circular(24 * scale),
                                                                child: CachedNetworkImage(
                                                                  imageUrl: cover,
                                                                  width: 150 * scale,
                                                                  height: 150 * scale,
                                                                  fit: BoxFit.cover,
                                                                  errorWidget: (_, __, ___) => Container(color: isDark ? const Color(0xFF2C2C2E) : Colors.grey, height: 150 * scale),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(height: 12 * scale),
                                                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(TextStyle(fontWeight: FontWeight.w700, fontSize: 16 * scale, color: textColor))),
                                                            SizedBox(height: 4 * scale),
                                                            Text(year, style: s(TextStyle(color: Colors.grey, fontSize: 14 * scale, fontWeight: FontWeight.w500))),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (previewTracks.isNotEmpty) ...[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(32 * scale, 24 * scale, 32 * scale, 8 * scale),
                                          child: HoverScale(
                                            child: InkWell(
                                              onTap: () => _showAllTracks(context, "${loc.popularTracks}: $artistName", tracks, scale, isDark, glassEnabled, textColor),
                                              borderRadius: BorderRadius.circular(12 * scale),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(loc.popularTracks, style: s(TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor))),
                                                  SizedBox(width: 8 * scale),
                                                  Icon(Icons.chevron_right_rounded, size: 26 * scale, color: primaryColor.opacity == 0 ? Colors.grey : primaryColor),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const BouncingScrollPhysics(),
                                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                                          itemCount: previewTracks.length,
                                          separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                                          itemBuilder: (context, index) => _buildTrackTile(previewTracks[index], index, previewTracks, scale),
                                        ),
                                        SizedBox(height: 40 * scale),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _searchTracks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (_isSearchOpen) {
        setState(() {
          _isSearchOpen = false;
          _searchResultsTracks.clear();
          _searchResultsArtists.clear();
          _searchResultsAlbums.clear();
        });
      }
      return;
    }

    if (query.startsWith('lizaplayer://')) {
      _searchController.clear();
      _handleDeepLink(Uri.parse(query));
      return;
    } else if (query.startsWith('https://music.yandex.ru/')) {
      final uri = Uri.parse(query);
      if (uri.pathSegments.contains('track')) {
        final trackIndex = uri.pathSegments.indexOf('track');
        if (trackIndex != -1 && trackIndex + 1 < uri.pathSegments.length) {
          final trackId = uri.pathSegments[trackIndex + 1];
          _searchController.clear();
          _handleDeepLink(Uri.parse('lizaplayer://track/$trackId?source=yandex'));
          return;
        }
      }
    }

    final isV2 = ref.read(uiModeProvider) == 'v2';
    final loc = AppLocalizations.of(context)!;

    if (isV2) {
      setState(() {
        _isSearching = true;
        _isSearchOpen = true;
        _lastSearchQuery = query;
        _searchResultsTracks = [];
        _searchResultsArtists = [];
        _searchResultsAlbums = [];
      });
    } else {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    }

    List<AppTrack> combinedTracks = [];
    List<dynamic> yaArtists = [];
    List<dynamic> scArtists = [];
    List<dynamic> combinedAlbums = [];

    final qLower = query.toLowerCase();
    List<Future<void>> searchTasks = [];

    if (_yandexClient != null) {
      searchTasks.add(() async {
        try {
          final yaResTracks = await _yandexClient!.search.tracks(query);
          combinedTracks.addAll(yaResTracks.map((t) => AppTrack.fromYandex(t)));
        } catch (e) { debugPrint("Error searching Yandex tracks: $e"); }
      }());
      searchTasks.add(() async {
        try {
          final artistsRes = await _yandexClient!.search.artists(query);
          yaArtists.addAll(artistsRes);
        } catch (e) { debugPrint("Error searching Yandex artists: $e"); }
      }());
      searchTasks.add(() async {
        try {
          final albumsRes = await _yandexClient!.search.albums(query);
          combinedAlbums.addAll(albumsRes);
        } catch (e) { debugPrint("Error searching Yandex albums: $e"); }
      }());
    }
    if (_soundcloudClientId != null && _soundcloudClientId!.isNotEmpty) {
      searchTasks.add(() async {
        try {
          final scUrl = Uri.parse('https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(query)}&client_id=${_soundcloudClientId}&limit=20');
          final response = await http.get(scUrl);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['collection'] != null) {
              combinedTracks.addAll((data['collection'] as List)
                  .where((item) => item['kind'] == 'track' || item['stream_url'] != null)
                  .map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>))
                  .where((t) => t.streamUrl != null));
            }
          }
        } catch (e) { debugPrint("Error searching SoundCloud tracks: $e"); }
      }());
      searchTasks.add(() async {
        try {
          final scUsersUrl = Uri.parse('https://api-v2.soundcloud.com/search/users?q=${Uri.encodeComponent(query)}&client_id=${_soundcloudClientId}&limit=10');
          final uRes = await http.get(scUsersUrl);
          if (uRes.statusCode == 200) {
            final uData = jsonDecode(uRes.body);
            if (uData['collection'] != null) scArtists.addAll(uData['collection']);
          }
        } catch (e) { debugPrint("Error searching SoundCloud artists: $e"); }
      }());
      searchTasks.add(() async {
        try {
          final scAlbumsUrl = Uri.parse('https://api-v2.soundcloud.com/search/playlists_without_albums?q=${Uri.encodeComponent(query)}&client_id=${_soundcloudClientId}&limit=10');
          final aRes = await http.get(scAlbumsUrl);
          if (aRes.statusCode == 200) {
            final aData = jsonDecode(aRes.body);
            if (aData['collection'] != null) combinedAlbums.addAll(aData['collection']);
          }
        } catch (e) { debugPrint("Error searching SoundCloud albums: $e"); }
      }());
    }

    await Future.wait(searchTasks);

    String getArtistName(dynamic a) {
      if (a is Map) return a['username']?.toString() ?? '';
      try { return (a as dynamic).title?.toString() ?? (a as dynamic).name?.toString() ?? ''; } catch (_) { return ''; }
    }

    final validArtistNames = {qLower};
    if (yaArtists.isNotEmpty) validArtistNames.add(getArtistName(yaArtists.first).toLowerCase().trim());
    if (scArtists.isNotEmpty) {
      scArtists.sort((a, b) => ((b['followers_count'] ?? 0) as int).compareTo((a['followers_count'] ?? 0) as int));
      validArtistNames.add(getArtistName(scArtists.first).toLowerCase().trim());
    }
    
    final seenYaArtists = <String>{};
    final uniqueYaArtists = <dynamic>[];
    for (final a in yaArtists) {
      final name = getArtistName(a).trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seenYaArtists.contains(key)) {
        seenYaArtists.add(key);
        if (uniqueYaArtists.isEmpty || validArtistNames.contains(key)) {
          uniqueYaArtists.add(a);
        }
      }
    }

    final seenScArtists = <String>{};
    final uniqueScArtists = <dynamic>[];
    for (final a in scArtists) {
      final name = getArtistName(a).trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seenScArtists.contains(key)) {
        seenScArtists.add(key);
        if (uniqueScArtists.isEmpty || validArtistNames.contains(key)) {
          uniqueScArtists.add(a);
        }
      }
    }

    List<dynamic> finalArtists = [];
    int artistIdx = 0;
    while (artistIdx < uniqueYaArtists.length || artistIdx < uniqueScArtists.length) {
      if (artistIdx < uniqueYaArtists.length) finalArtists.add(uniqueYaArtists[artistIdx]);
      if (artistIdx < uniqueScArtists.length) finalArtists.add(uniqueScArtists[artistIdx]);
      artistIdx++;
    }
    List<dynamic> combinedArtists = finalArtists;

    String getAlbumName(dynamic a) {
      if (a is Map) return a['title']?.toString() ?? '';
      try { return (a as dynamic).title?.toString() ?? ''; } catch (_) { return ''; }
    }
    
    final seenAlbums = <String>{};
    final uniqueAlbums = <dynamic>[];
    for (final a in combinedAlbums) {
      final name = getAlbumName(a).trim();
      if (name.isEmpty) continue;
      final source = a is Map ? 'sc' : 'ya';
      final key = '${name.toLowerCase()}-$source';
      if (!seenAlbums.contains(key)) {
        seenAlbums.add(key);
        if (uniqueAlbums.length < 6 || name.toLowerCase() == qLower) {
          uniqueAlbums.add(a);
        }
      }
    }

    if (!isV2) Navigator.of(context).pop();

    if (mounted) {
      if (combinedTracks.isEmpty && combinedArtists.isEmpty && uniqueAlbums.isEmpty) {
        _showGlassToast(loc.noResultsFound, isError: true);
        if (isV2) setState(() => _isSearchOpen = false);
      } else {
        if (isV2) {
          setState(() {
            _isSearching = false;
            _searchResultsTracks = combinedTracks;
            _searchResultsArtists = combinedArtists;
            _searchResultsAlbums = uniqueAlbums;
          });
          _searchFocusNode.requestFocus();
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Consumer(
              builder: (context, ref, child) {
                final glassEnabled = ref.watch(glassEnabledProvider);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final scale = ref.watch(scaleProvider);
                final primary = Theme.of(context).colorScheme.primary;
                final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
                final loc = AppLocalizations.of(context)!;

                return DraggableScrollableSheet(
                  expand: false, initialChildSize: 0.85, minChildSize: 0.4, maxChildSize: 0.95,
                  builder: (context, scrollController) => _buildGlassContainer(
                    glassEnabled: glassEnabled, isDark: isDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(36)), scale: scale,
                    child: Column(
                      children: [
                        Container(width: 44 * scale, height: 6 * scale, margin: EdgeInsets.symmetric(vertical: 14 * scale), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.35), borderRadius: BorderRadius.circular(10 * scale))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
                          child: Row(
                            children: [
                              Text(loc.searchResultsFor(query), style: s(TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold, letterSpacing: -0.5 * scale))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SmoothScrollWrapper(
                            controller: scrollController,
                            builder: (context, controller) => CustomScrollView(
                              controller: controller,
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                if (combinedArtists.isNotEmpty) ...[
                                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24 * scale, 16 * scale, 24 * scale, 12 * scale), child: Text(loc.artists, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))))),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 140 * scale,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                                        itemCount: combinedArtists.length,
                                        itemBuilder: (context, index) {
                                          final artist = combinedArtists[index];
                                          String name = getArtistName(artist);
                                          String cover = '';
                                          if (artist is Map) {
                                            cover = artist['avatar_url']?.replaceAll('-large', '-t500x500') ?? '';
                                          } else {
                                            try { cover = _getCoverUrl((artist as dynamic).coverUri); } catch (_) {}
                                          }
                                          final isSc = artist is Map;
                                          return Padding(
                                            padding: EdgeInsets.only(right: 12 * scale),
                                            child: HoverScale(
                                              child: GestureDetector(
                                                onTap: () { Navigator.pop(context); _showArtistCard(artist); },
                                                child: _buildGlassContainer(
                                                  glassEnabled: glassEnabled,
                                                  isDark: isDark,
                                                  borderRadius: BorderRadius.circular(24 * scale),
                                                  scale: scale,
                                                  child: Container(
                                                    width: 100 * scale,
                                                    padding: EdgeInsets.all(12 * scale),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Stack(
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 32 * scale,
                                                              backgroundColor: effectiveAccent.withOpacity(0.12),
                                                              backgroundImage: cover.isNotEmpty ? CachedNetworkImageProvider(cover) : null,
                                                              child: cover.isEmpty ? Icon(Icons.person_rounded, size: 30 * scale, color: effectiveAccent) : null,
                                                            ),
                                                            Positioned(
                                                              bottom: 0,
                                                              right: 0,
                                                              child: Container(
                                                                padding: EdgeInsets.all(3 * scale),
                                                                decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                                                                child: SvgPicture.asset(isSc ? 'assets/soundcloud_icon.svg' : 'assets/yandex_music_icon.svg', width: 14 * scale, height: 14 * scale),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 10 * scale),
                                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: s(TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13 * scale, fontWeight: FontWeight.w600))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                                if (uniqueAlbums.isNotEmpty) ...[
                                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24 * scale, 20 * scale, 24 * scale, 12 * scale), child: Text(loc.albums, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))))),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 160 * scale,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                                        itemCount: uniqueAlbums.length,
                                        itemBuilder: (context, index) {
                                          final album = uniqueAlbums[index];
                                          String name = getAlbumName(album);
                                          String cover = '';
                                          if (album is Map) {
                                            cover = album['artwork_url']?.replaceAll('-large', '-t500x500') ?? '';
                                          } else {
                                            try { cover = _getCoverUrl((album as dynamic).coverUri); } catch (_) {}
                                          }
                                          final isSc = album is Map;
                                          return Padding(
                                            padding: EdgeInsets.only(right: 12 * scale),
                                            child: HoverScale(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _showAlbumCard(context, album, scale, isDark, glassEnabled, isDark ? Colors.white : Colors.black87, loc);
                                                },
                                                child: _buildGlassContainer(
                                                  glassEnabled: glassEnabled,
                                                  isDark: isDark,
                                                  borderRadius: BorderRadius.circular(24 * scale),
                                                  scale: scale,
                                                  child: Container(
                                                    width: 120 * scale,
                                                    padding: EdgeInsets.all(12 * scale),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Stack(
                                                          children: [
                                                            ClipRRect(
                                                              borderRadius: BorderRadius.circular(14 * scale),
                                                              child: Container(
                                                                width: 96 * scale,
                                                                height: 96 * scale,
                                                                color: effectiveAccent.withOpacity(0.12),
                                                                child: cover.isNotEmpty 
                                                                  ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.album_rounded, size: 40 * scale, color: effectiveAccent))
                                                                  : Icon(Icons.album_rounded, size: 40 * scale, color: effectiveAccent),
                                                              ),
                                                            ),
                                                            Positioned(
                                                              bottom: 4 * scale,
                                                              right: 4 * scale,
                                                              child: Container(
                                                                padding: EdgeInsets.all(4 * scale),
                                                                decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(8 * scale), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                                                                child: SvgPicture.asset(isSc ? 'assets/soundcloud_icon.svg' : 'assets/yandex_music_icon.svg', width: 14 * scale, height: 14 * scale),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 10 * scale),
                                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13 * scale, fontWeight: FontWeight.w600))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                                if (combinedTracks.isNotEmpty) ...[
                                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(24 * scale, 20 * scale, 24 * scale, 12 * scale), child: Text(loc.tracksTitle, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: effectiveAccent))))),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final i = index ~/ 2;
                                          if (index.isEven) {
                                            return _buildTrackTile(combinedTracks[i], i, combinedTracks, scale);
                                          } else {
                                            return Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale);
                                          }
                                        },
                                        childCount: combinedTracks.length > 0 ? combinedTracks.length * 2 - 1 : 0,
                                      ),
                                    ),
                                  ),
                                ],
                                SliverToBoxAdapter(child: SizedBox(height: 20 * scale)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      }
    }
  }

  String? _yandexRadioSessionId;
  String? _yandexRadioBatchId;
  List<String> _currentWaveBatchTrackIds = [];
  final List<String> _waveHistoryTrackIds = [];
  final Map<String, String> _waveTrackBatchIds = {};
  final Map<String, List<String>> _waveTrackQueues = {};
  final Map<String, AppTrack> _scWaveYandexTracks = {};
  String _yandexWaveSeed = 'user:onyourwave';
  AppTrack? _currentWaveTrack;
  DateTime? _currentWaveTrackStartTime;

  Future<void> _sendYandexWaveFeedback(AppTrack track, String type, {double playedSeconds = 0}) async {
    if (_yandexToken == null || _yandexRadioSessionId == null) return;
    try {
      AppTrack feedbackTrack = track;
      if (_waveSource == 'soundcloud') {
        feedbackTrack = _scWaveYandexTracks[track.id] ?? track;
      }
      String trackIdStr = feedbackTrack.id;
      if (feedbackTrack.originalObject is ym.Track) {
        final yt = feedbackTrack.originalObject as ym.Track;
        if (yt.albums.isNotEmpty) {
          trackIdStr = '${feedbackTrack.id}:${yt.albums.first.id}';
        }
      }
      
      if (!_waveHistoryTrackIds.contains(trackIdStr)) {
        _waveHistoryTrackIds.add(trackIdStr);
        if (_waveHistoryTrackIds.length > 1000) _waveHistoryTrackIds.removeAt(0);
        TokenStorage.saveRecentWaveTracks(_waveHistoryTrackIds);
      }
      
      final trackBatchId = _waveTrackBatchIds[feedbackTrack.id] ?? _yandexRadioBatchId;
      
      if (trackBatchId == null) return;
      
      final isTrackStarted = type == 'trackStarted';
      final uri = isTrackStarted
          ? Uri.parse('https://api.music.yandex.net/rotor/session/$_yandexRadioSessionId/feedback')
          : Uri.parse('https://api.music.yandex.net/rotor/session/$_yandexRadioSessionId/tracks');

      final event = {
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'trackId': trackIdStr,
        'type': type,
        if (playedSeconds > 0) 'totalPlayedSeconds': playedSeconds.toInt(),
      };

      final bodyData = isTrackStarted
          ? {
              'batchId': trackBatchId,
              'from': 'web-home-rup_main-radio-default',
              'event': event,
            }
          : {
              'queue': _waveHistoryTrackIds,
              'feedbacks': [
                {
                  'batchId': trackBatchId,
                  'from': 'web-home-rup_main-radio-default',
                  'event': event,
                }
              ]
            };

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'OAuth ${_yandexToken}',
          'X-Yandex-Music-Client': 'YandexMusicAndroid/24023621',
          'User-Agent': 'Yandex-Music-API',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode != 200 && response.statusCode != 202) {
        debugPrint("Yandex Wave feedback failed: ${response.statusCode} ${response.body}");
      }

      if (!isTrackStarted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        if (result != null) {
          final newBatchId = result['batchId'];
          final sequence = result['sequence'] as List?;
          if (sequence != null && sequence.isNotEmpty) {
            List<AppTrack> newTracks = [];
            _currentWaveBatchTrackIds.clear();
            
            final List<String> currentQueue = [];
            for (var item in sequence) {
              final trackData = item['track'];
              if (trackData != null) {
                try {
                  final ymTrack = ym.Track(trackData as Map<String, dynamic>);
                  final track = AppTrack.fromYandex(ymTrack);
                  
                  String tId = track.id;
                  if (ymTrack.albums.isNotEmpty) {
                    tId = '${track.id}:${ymTrack.albums.first.id}';
                  }
                  currentQueue.add(tId);
                  _currentWaveBatchTrackIds.add(tId);
                } catch (_) {}
              }
            }

            for (var item in sequence) {
              final trackData = item['track'];
              if (trackData != null) {
                try {
                  final ymTrack = ym.Track(trackData as Map<String, dynamic>);
                  final track = AppTrack.fromYandex(ymTrack);
                  
                  if (newBatchId != null) {
                    _waveTrackBatchIds[track.id] = newBatchId;
                  }
                  _waveTrackQueues[track.id] = List.from(currentQueue);
                  
                  final isAlreadyInHistory = _waveHistoryTrackIds.any((id) => id == track.id || id.startsWith('${track.id}:'));
                  if (!waveTracks.any((t) => t.id == track.id) && !isAlreadyInHistory) {
                    newTracks.add(track);
                  }
                } catch (_) {}
              }
            }
            
            if (newTracks.isNotEmpty && mounted && _isWaveActive) {
              if (_waveSource == 'soundcloud') {
                List<AppTrack> scNewTracks = [];
                for (var yaT in newTracks) {
                  final scT = await _searchSoundcloudForWave(yaT, scNewTracks);
                  if (scT != null) {
                    _scWaveYandexTracks[scT.id] = yaT;
                    scNewTracks.add(scT);
                  } else {
                    String trackIdStr = yaT.id;
                    if (yaT.originalObject is ym.Track) {
                      final yt = yaT.originalObject as ym.Track;
                      if (yt.albums.isNotEmpty) {
                        trackIdStr = '${yaT.id}:${yt.albums.first.id}';
                      }
                    }
                    if (!_waveHistoryTrackIds.contains(trackIdStr)) {
                      _waveHistoryTrackIds.add(trackIdStr);
                      if (_waveHistoryTrackIds.length > 1000) _waveHistoryTrackIds.removeAt(0);
                    }
                  }
                }
                newTracks = scNewTracks;
              }
              setState(() {
                waveTracks = [...waveTracks, ...newTracks];
                _currentPlaylist = [..._currentPlaylist, ...newTracks];
              });
              _playerService.updatePlaylist(_currentPlaylist);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error sending Yandex Wave feedback: $e");
    }
  }

  Future<AppTrack?> _searchSoundcloudForWave(AppTrack yaTrack, List<AppTrack> excludeTracks) async {
    if (_soundcloudClientId == null || _soundcloudClientId!.isEmpty) return null;
    try {
      final query = '${yaTrack.title} ${yaTrack.artistName}';
      final scUrl = Uri.parse('https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(query)}&client_id=${_soundcloudClientId}&limit=10');
      final response = await http.get(scUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['collection'] != null) {
          final list = (data['collection'] as List)
              .where((item) => item['kind'] == 'track' || item['stream_url'] != null)
              .map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>))
              .where((t) => t.streamUrl != null)
              .toList();
          for (var t in list) {
            if (!waveTracks.any((wt) => wt.id == t.id) && !excludeTracks.any((et) => et.id == t.id)) {
              return t;
            }
          }
        }
      }
    } catch (e) {}
    return null;
  }

  Future<List<AppTrack>> _fetchYandexWaveBatch() async {
    if (_yandexToken == null) return [];
    try {
      final isNewSession = _yandexRadioSessionId == null;
      final uri = isNewSession 
          ? Uri.parse('https://api.music.yandex.net/rotor/session/new')
          : Uri.parse('https://api.music.yandex.net/rotor/session/$_yandexRadioSessionId/tracks');

      final bodyData = isNewSession 
          ? {
              'seeds': [_yandexWaveSeed],
              'includeTracksInResponse': true,
              'queue': _waveHistoryTrackIds,
            }
          : {
              'queue': _waveHistoryTrackIds,
            };

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'OAuth ${_yandexToken}',
          'X-Yandex-Music-Client': 'YandexMusicAndroid/24023621',
          'User-Agent': 'Yandex-Music-API',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        if (result != null) {
          _yandexRadioSessionId = result['radioSessionId'] ?? _yandexRadioSessionId;
          _yandexRadioBatchId = result['batchId'] ?? _yandexRadioBatchId;
          final sequence = result['sequence'] as List?;
          if (sequence != null && sequence.isNotEmpty) {
            final List<AppTrack> tracks = [];
            _currentWaveBatchTrackIds.clear();
            
            final List<String> currentQueue = [];
            for (var item in sequence) {
              final trackData = item['track'];
              if (trackData != null) {
                try {
                  final ymTrack = ym.Track(trackData as Map<String, dynamic>);
                  final track = AppTrack.fromYandex(ymTrack);
                  
                  String tId = track.id;
                  if (ymTrack.albums.isNotEmpty) {
                    tId = '${track.id}:${ymTrack.albums.first.id}';
                  }
                  currentQueue.add(tId);
                  _currentWaveBatchTrackIds.add(tId);
                } catch (_) {}
              }
            }

            for (var item in sequence) {
              final trackData = item['track'];
              if (trackData != null) {
                try {
                  final ymTrack = ym.Track(trackData as Map<String, dynamic>);
                  final track = AppTrack.fromYandex(ymTrack);
                  
                  if (_yandexRadioBatchId != null) {
                    _waveTrackBatchIds[track.id] = _yandexRadioBatchId!;
                  }
                  _waveTrackQueues[track.id] = List.from(currentQueue);
                  
                  final isAlreadyInHistory = _waveHistoryTrackIds.any((id) => id == track.id || id.startsWith('${track.id}:'));
                  if (!waveTracks.any((t) => t.id == track.id) && !isAlreadyInHistory) {
                    tracks.add(track);
                  }
                } catch (_) {}
              }
            }
            return tracks;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching Yandex Wave batch: $e");
    }
    return [];
  }

  Future<void> _startMyWave({AppTrack? seedTrack}) async {
    if (_loading) return;
    final loc = AppLocalizations.of(context)!;
    
    String newSeed = seedTrack != null && seedTrack.source == AudioSourceType.yandex
        ? 'track:${seedTrack.id}'
        : 'user:onyourwave';

    if (seedTrack != null) {
      _waveSource = seedTrack.source == AudioSourceType.yandex ? 'yandex' : 'soundcloud';
      _yandexWaveSeed = newSeed;
    } else {
      _yandexWaveSeed = 'user:onyourwave';
    }

    setState(() {
      _loading = true;
      waveTracks = [];
      _yandexRadioSessionId = null;
      _yandexRadioBatchId = null;
      _waveTrackBatchIds.clear();
      _waveTrackQueues.clear();
      _isWaveActive = false;
    });

    final int sessionId = ++_waveSessionId;
    await _playerService.stop();

    if (_waveSource == 'yandex') {
      try {
        final tracks = await _fetchYandexWaveBatch();
        if (sessionId != _waveSessionId) return;

        if (mounted && tracks.isNotEmpty) {
          setState(() {
            waveTracks = tracks;
          });
          _playFromList(waveTracks, 0, isWave: true);
        } else {
          _showGlassToast(loc.noResultsFound, isError: true);
        }
      } catch (e) {
        debugPrint("Error starting Yandex Wave: $e");
        _showGlassToast(loc.noResultsFound, isError: true);
      } finally {
        if (mounted && sessionId == _waveSessionId) setState(() => _loading = false);
      }
    } else if (_waveSource == 'soundcloud') {
      try {
        final yaTracks = await _fetchYandexWaveBatch();
        if (sessionId != _waveSessionId) return;

        List<AppTrack> finalTracks = [];
        for (var yaT in yaTracks) {
          final scT = await _searchSoundcloudForWave(yaT, finalTracks);
          if (scT != null) {
            _scWaveYandexTracks[scT.id] = yaT;
            finalTracks.add(scT);
          } else {
             String trackIdStr = yaT.id;
             if (yaT.originalObject is ym.Track) {
               final yt = yaT.originalObject as ym.Track;
               if (yt.albums.isNotEmpty) {
                 trackIdStr = '${yaT.id}:${yt.albums.first.id}';
               }
             }
             if (!_waveHistoryTrackIds.contains(trackIdStr)) {
               _waveHistoryTrackIds.add(trackIdStr);
               if (_waveHistoryTrackIds.length > 1000) _waveHistoryTrackIds.removeAt(0);
             }
          }
        }
        
        if (seedTrack != null && seedTrack.source == AudioSourceType.soundcloud) {
          finalTracks.removeWhere((t) => t.id == seedTrack.id);
          finalTracks.insert(0, seedTrack);
        }

        if (sessionId != _waveSessionId) return;

        if (finalTracks.isNotEmpty) {
          if (mounted) {
            setState(() {
              waveTracks = finalTracks;
            });
          }
          _playFromList(waveTracks, 0, isWave: true);
        } else {
          _showGlassToast(loc.noResultsFound, isError: true);
        }
      } catch (e) {
        debugPrint("Error starting SoundCloud Wave: $e");
      } finally {
        if (mounted && sessionId == _waveSessionId) setState(() => _loading = false);
      }
    }
  }

  void _playFromList(List<AppTrack> list, int index, {bool isWave = false}) {
    if (index < 0 || index >= list.length) return;
    setState(() {
      _isWaveActive = isWave;
      _currentPlaylist = list;
      _currentIndex = index;
      _queueTracks = _currentPlaylist.skip(_currentIndex + 1).toList();
    });
    _playerService.playPlaylist(_currentPlaylist, _currentIndex);
  }

  void _playCurrentTrack() {
    _playerService.playPlaylist(_currentPlaylist, _currentIndex);
  }

  void _nextTrack() {
    if (_playerService.hasNext) {
      _playerService.next();
      setState(() {});
    }
  }

  void _prevTrack() {
    if (_playerService.position > const Duration(seconds: 3)) {
      _playerService.seek(Duration.zero);
    } else {
      if (_playerService.hasPrevious) {
        _playerService.previous();
        setState(() {});
      }
    }
  }

  void _playAtPlaylistIndex(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _currentPlaylist.length) return;
    _playerService.seekToIndex(globalIndex);
    setState(() {});
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '0:00';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _getCoverUrl(String? coverUri, {String size = '400x400'}) {
    if (coverUri == null || coverUri.isEmpty) return '';
    return 'https://${coverUri.replaceAll('%%', size)}';
  }

  Future<void> _clearCache() async {
    final dir = await getTemporaryDirectory();
    final loc = AppLocalizations.of(context)!;
    if (await dir.exists()) await dir.delete(recursive: true);
    if (mounted) {
      _showGlassToast(loc.cacheCleared);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.deleteAllTokens();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  Widget _buildApiKeysSelector(double scale, bool isDark, bool glassEnabled, AppLocalizations loc) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(50 * scale),
            scale: scale,
            child: TextField(
              controller: _yandexTokenController,
              obscureText: _obscureYandexToken,
              cursorColor: effectiveAccent,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15 * scale),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.all(14 * scale),
                  child: SvgPicture.asset(
                    'assets/yandex_music_icon.svg',
                    width: 20 * scale,
                    height: 20 * scale,
                  ),
                ),
                suffixIcon: HoverScale(
                  child: IconButton(
                    icon: Icon(_obscureYandexToken ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20 * scale),
                    onPressed: () => setState(() => _obscureYandexToken = !_obscureYandexToken),
                  ),
                ),
                hintText: loc.yandexTokenHint,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15 * scale),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 16 * scale),
              ),
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(50 * scale),
            scale: scale,
            child: TextField(
              controller: _soundcloudIdController,
              obscureText: _obscureScToken,
              cursorColor: effectiveAccent,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15 * scale),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.all(14 * scale),
                  child: SvgPicture.asset(
                    'assets/soundcloud_icon.svg',
                    width: 20 * scale,
                    height: 20 * scale,
                  ),
                ),
                suffixIcon: HoverScale(
                  child: IconButton(
                    icon: Icon(_obscureScToken ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20 * scale),
                    onPressed: () => setState(() => _obscureScToken = !_obscureScToken),
                  ),
                ),
                hintText: loc.soundcloudIdHint,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15 * scale),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 16 * scale),
              ),
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: Row(
            children: [
              Expanded(
                child: HoverScale(
                  child: GestureDetector(
                    onTap: () async {
                      final loc = AppLocalizations.of(context)!;
                      final loadingToast = _showGlassToast(loc.loading, isLoading: true);
                      
                      final ya = _yandexTokenController.text.trim();
                      final sc = _soundcloudIdController.text.trim();
                      
                      try {
                        if (ya.isNotEmpty) {
                          await TokenStorage.saveYandexToken(ya);
                          _yandexToken = ya;
                          _yandexClient = ym.YandexMusic(token: ya);
                          await _yandexClient!.init();
                          _playerService.setYandexClient(_yandexClient!);
                        }
                        if (sc.isNotEmpty) {
                          await TokenStorage.saveSoundcloudClientId(sc);
                          _soundcloudClientId = sc;
                          _playerService.setSoundcloudClientId(sc);
                        }
                        await _loadLikedTracks();
                        
                        loadingToast.remove();
                        _showGlassToast(loc.tokensSaved);
                        setState(() {});
                      } catch (e) {
                        loadingToast.remove();
                        _showGlassToast("Ошибка: $e", isError: true);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: _buildGlassContainer(
                      glassEnabled: glassEnabled,
                      isDark: isDark,
                      borderRadius: BorderRadius.circular(50 * scale),
                      scale: scale,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16 * scale),
                          child: Text(loc.save, style: s(TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
          child: Row(
            children: [
              Text(loc.syncYandex, style: TextStyle(fontSize: 15 * scale, color: Colors.grey)),
              SizedBox(width: 8 * scale),
              Tooltip(
                message: loc.syncYandexTooltip,
                preferBelow: false,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(glassEnabled ? 0.8 : 1.0),
                  borderRadius: BorderRadius.circular(12 * scale),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    width: 1 * scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10 * scale,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                textStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w500,
                ),
                padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
                margin: EdgeInsets.symmetric(horizontal: 24 * scale),
                child: Icon(Icons.info_outline_rounded, size: 16 * scale, color: Colors.grey),
              ),
            ],
          ),
        ),
        Consumer(
          builder: (context, ref, child) {
            final syncEnabled = ref.watch(syncYandexLikesProvider);
            
            Widget buildOption({required String label, required bool selected, required VoidCallback onTap}) {
              final content = Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
              );

              final button = glassEnabled
                  ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectiveAccent, width: 2 * scale) : null)
                  : Container(decoration: BoxDecoration(color: selected ? (effectiveAccent.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectiveAccent) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);

              return Padding(
                padding: EdgeInsets.only(right: 8 * scale),
                child: HoverScale(child: GestureDetector(onTap: onTap, child: button)),
              );
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Row(
                children: [
                  buildOption(label: loc.off, selected: !syncEnabled, onTap: () {
                    ref.read(syncYandexLikesProvider.notifier).state = false;
                    TokenStorage.saveSyncYandexLikes(false);
                  }),
                  buildOption(label: loc.on, selected: syncEnabled, onTap: () {
                    ref.read(syncYandexLikesProvider.notifier).state = true;
                    TokenStorage.saveSyncYandexLikes(true);
                  }),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 16 * scale),
      ],
    );
  }

  Widget _buildThemeSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentMode = ref.watch(themeModeProvider);
        final modes = [
          {'mode': ThemeMode.light, 'title': AppLocalizations.of(context)!.light},
          {'mode': ThemeMode.dark, 'title': AppLocalizations.of(context)!.dark},
          {'mode': ThemeMode.system, 'title': AppLocalizations.of(context)!.system},
        ];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final loc = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.dark_mode_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.theme, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SmoothScrollWrapper(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: modes.map((m) {
                      final selected = currentMode == m['mode'];
                      final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                      final buttonContent = Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                        child: Text(m['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                      );
                      final button = glassEnabled
                          ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                          : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                      return Padding(
                        padding: EdgeInsets.only(right: 8 * scale),
                        child: HoverScale(
                          child: GestureDetector(
                            onTap: () async {
                              ref.read(themeModeProvider.notifier).state = m['mode'] as ThemeMode;
                              await TokenStorage.saveThemeMode(m['mode'] as ThemeMode);
                            },
                            child: button,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildColorSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final colorMap = [
          {'color': Colors.cyanAccent, 'label': loc.cyan},
          {'color': Colors.redAccent, 'label': loc.red},
          {'color': Colors.orangeAccent, 'label': loc.orange},
          {'color': Colors.purpleAccent, 'label': loc.purple},
          {'color': Colors.greenAccent, 'label': loc.green},
          {'color': Colors.blueAccent, 'label': loc.blue},
          {'color': Colors.pinkAccent, 'label': loc.pink},
          {'color': Colors.indigoAccent, 'label': loc.indigo},
          {'color': Colors.amberAccent, 'label': loc.amber},
          {'color': Colors.tealAccent, 'label': loc.teal},
          {'color': Colors.grey, 'label': loc.grey},
          {'color': Colors.transparent, 'label': loc.none},
        ];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final currentColor = ref.watch(accentColorProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.palette_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.mainColor, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SmoothScrollWrapper(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: colorMap.where((cm) => glassEnabled || cm['color'] != Colors.transparent).map((cm) {
                      final color = cm['color'] as Color;
                      final label = cm['label'] as String;
                      final selected = currentColor == color;
                      final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                      final buttonContent = Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                        child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                      );
                      final button = glassEnabled
                          ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                          : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                      return Padding(
                        padding: EdgeInsets.only(right: 8 * scale),
                        child: HoverScale(
                          child: GestureDetector(
                            onTap: () async {
                              ref.read(accentColorProvider.notifier).state = color;
                              await TokenStorage.saveAccentColor(color.value);
                            },
                            child: button,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentLocale = ref.watch(localeProvider);
        final languages = [
          {'locale': const Locale('en'), 'title': AppLocalizations.of(context)!.english},
          {'locale': const Locale('ru'), 'title': AppLocalizations.of(context)!.russian},
        ];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final loc = AppLocalizations.of(context)!;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: SmoothScrollWrapper(
            builder: (context, controller) => SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: languages.map((l) {
                  final selected = currentLocale == l['locale'];
                  final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                  final buttonContent = Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                    child: Text(l['title'] as String, style: s(TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black)))),
                  );
                  final button = glassEnabled
                      ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                      : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                  return Padding(
                    padding: EdgeInsets.only(right: 8 * scale),
                    child: HoverScale(
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(localeProvider.notifier).state = l['locale'] as Locale;
                          await TokenStorage.saveLanguage((l['locale'] as Locale).languageCode);
                        },
                        child: button,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalOptions<T>({
    required String title,
    required List<Map<String, dynamic>> options,
    required T currentValue,
    required void Function(T) onSelected,
    required double scale,
    required bool isDark,
    required bool glassEnabled,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
          child: Text(title, style: s(TextStyle(fontSize: 15 * scale, color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: SmoothScrollWrapper(
            builder: (context, controller) => SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: options.map((o) {
                  final T val = o['value'] as T;
                  final selected = val == currentValue;
                  final label = o['label'] as String;
                  final content = Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                    child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                  );
                  final button = glassEnabled
                      ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: accent, width: 2 * scale) : null)
                      : Container(decoration: BoxDecoration(color: selected ? (accent.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : accent) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);
                  return Padding(
                    padding: EdgeInsets.only(right: 8 * scale),
                    child: HoverScale(child: GestureDetector(onTap: () => onSelected(val), child: button)),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFontSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final fontFamily = ref.watch(fontFamilyProvider);
        final customPath = ref.watch(customFontPathProvider);
        final weight = ref.watch(fontWeightProvider);
        final spacing = ref.watch(letterSpacingProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final loc = AppLocalizations.of(context)!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsSubHeader(loc.fontSettings, Icons.font_download_rounded, scale),
            _buildHorizontalOptions<String?>(
              title: loc.fontFamily,
              currentValue: fontFamily,
              scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
              options: [
                {'value': null, 'label': loc.defaultFont},
                {'value': 'monospace', 'label': 'Monospace'},
                {'value': 'serif', 'label': 'Serif'},
                {'value': 'sans-serif', 'label': 'Sans-serif'},
                {'value': 'system-ui', 'label': 'System-ui'},
                {'value': 'Inter', 'label': 'Inter'},
                {'value': 'Roboto', 'label': 'Roboto'},
              ],
              onSelected: (v) {
                ref.read(fontFamilyProvider.notifier).state = v;
                TokenStorage.saveFontFamily(v);
                ref.read(appKeyProvider.notifier).state = UniqueKey();
              },
            ),
            _settingsTile(
              icon: Icons.upload_file_rounded,
              title: loc.customFontFile,
              subtitle: customPath != null ? customPath.split(Platform.pathSeparator).last : loc.notSelected,
              scale: scale,
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ttf', 'otf']);
                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path!;
                  await loadCustomFont(path);
                  ref.read(customFontPathProvider.notifier).state = path;
                  ref.read(fontFamilyProvider.notifier).state = 'CustomFont';
                  await TokenStorage.saveCustomFontPath(path);
                  await TokenStorage.saveFontFamily('CustomFont');
                  ref.read(appKeyProvider.notifier).state = UniqueKey();
                }
              },
            ),
            _buildHorizontalOptions<int>(
              title: loc.fontWeight,
              currentValue: weight,
              scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
              options: List.generate(9, (i) => {'value': i, 'label': ((i + 1) * 100).toString()}),
              onSelected: (v) {
                ref.read(fontWeightProvider.notifier).state = v;
                TokenStorage.saveFontWeight(v);
              },
            ),
            _buildHorizontalOptions<double>(
              title: loc.letterSpacing,
              currentValue: spacing,
              scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
              options: [-1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0].map((v) => {'value': v, 'label': v.toString()}).toList(),
              onSelected: (v) {
                ref.read(letterSpacingProvider.notifier).state = v;
                TokenStorage.saveLetterSpacing(v);
              },
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }


  Widget _buildCustomBackgroundSelector(double scale) {
    final controller = TextEditingController(text: _customBackgroundUrl);
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final glassEnabled = ref.watch(glassEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
          child: Row(
            children: [
              Icon(Icons.wallpaper_rounded, color: effectiveAccent, size: 24 * scale),
              SizedBox(width: 16 * scale),
              Text(loc.customBackground, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(24 * scale),
            scale: scale,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        cursorColor: effectiveAccent,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15 * scale),
                        decoration: InputDecoration(
                          hintText: loc.urlExample,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                          hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.check_circle_rounded, color: effectiveAccent, size: 22 * scale),
                      onPressed: () async {
                        final url = controller.text.trim();
                        final newUrl = url.isEmpty ? null : url;
                        await TokenStorage.saveCustomGifUrl(newUrl);
                        setState(() => _customBackgroundUrl = newUrl);
                      },
                    ),
                    if (_customBackgroundUrl != null && _customBackgroundUrl!.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.cancel_rounded, color: Colors.redAccent.withOpacity(0.8), size: 22 * scale),
                        onPressed: () async {
                          await TokenStorage.saveCustomGifUrl(null);
                          controller.clear();
                          setState(() => _customBackgroundUrl = null);
                        },
                      ),
                    SizedBox(width: 8 * scale),
                  ],
                ),
                Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white10 : Colors.black12),
                InkWell(
                  onTap: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
                      if (result != null && result.files.single.path != null) {
                        final path = result.files.single.path!;
                        await TokenStorage.saveCustomBackgroundPath(path);
                        setState(() => _customBackgroundPath = path);
                      }
                    } catch (e) {
                      debugPrint("Error picking background: $e");
                    }
                  },
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24 * scale), bottomRight: Radius.circular(24 * scale)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                    child: Row(
                      children: [
                        Icon(Icons.folder_open_rounded, size: 20 * scale, color: effectiveAccent),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Text(
                            _customBackgroundPath != null ? _customBackgroundPath!.split('/').last : loc.selectFile,
                            style: s(TextStyle(fontSize: 15 * scale, color: _customBackgroundPath != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_customBackgroundPath != null)
                          GestureDetector(
                            onTap: () async {
                              await TokenStorage.saveCustomBackgroundPath(null);
                              setState(() => _customBackgroundPath = null);
                            },
                            child: Icon(Icons.close_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20 * scale),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
      ],
    );
  }

  Widget _buildCustomTrackCoverSelector(double scale) {
    final urlController = TextEditingController(text: _customTrackCoverUrl);
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    final glassEnabled = ref.watch(glassEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
          child: Row(
            children: [
              Icon(Icons.album_rounded, color: effectiveAccent, size: 24 * scale),
              SizedBox(width: 16 * scale),
              Text(loc.customTrackCover, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(24 * scale),
            scale: scale,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: urlController,
                        decoration: InputDecoration(
                          hintText: loc.coverUrl,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                          hintStyle: TextStyle(fontSize: 15 * scale, color: Colors.grey),
                        ),
                        style: TextStyle(fontSize: 15 * scale),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.check_circle_rounded, color: effectiveAccent, size: 22 * scale),
                      onPressed: () async {
                        final url = urlController.text.trim();
                        final newUrl = url.isEmpty ? null : url;
                        await TokenStorage.saveCustomTrackCoverUrl(newUrl);
                        setState(() => _customTrackCoverUrl = newUrl);
                      },
                    ),
                    if (_customTrackCoverUrl != null && _customTrackCoverUrl!.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.cancel_rounded, color: Colors.redAccent.withOpacity(0.8), size: 22 * scale),
                        onPressed: () async {
                          await TokenStorage.saveCustomTrackCoverUrl(null);
                          urlController.clear();
                          setState(() => _customTrackCoverUrl = null);
                        },
                      ),
                    SizedBox(width: 8 * scale),
                  ],
                ),
                Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white10 : Colors.black12),
                InkWell(
                  onTap: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
                      if (result != null && result.files.single.path != null) {
                        final path = result.files.single.path!;
                        await TokenStorage.saveCustomTrackCoverPath(path);
                        setState(() => _customTrackCoverPath = path);
                      }
                    } catch (e) {
                      debugPrint("Error picking track cover: $e");
                    }
                  },
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24 * scale), bottomRight: Radius.circular(24 * scale)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                    child: Row(
                      children: [
                        Icon(Icons.folder_open_rounded, size: 20 * scale, color: effectiveAccent),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Text(
                            _customTrackCoverPath != null ? _customTrackCoverPath!.split('/').last : loc.coverFile,
                            style: TextStyle(fontSize: 15 * scale, color: _customTrackCoverPath != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_customTrackCoverPath != null)
                          GestureDetector(
                            onTap: () async {
                              await TokenStorage.saveCustomTrackCoverPath(null);
                              setState(() => _customTrackCoverPath = null);
                            },
                            child: Icon(Icons.close_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20 * scale),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
      ],
    );
  }

  Widget _buildGlassSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final enabled = ref.watch(glassEnabledProvider);
        final options = [{'value': false, 'title': loc.off}, {'value': true, 'title': loc.on}];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.blur_on_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.glassInterface, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SmoothScrollWrapper(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: options.map((o) {
                      final selected = enabled == o['value'];
                      final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                      final buttonContent = Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                        child: Text(o['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                      );
                      final button = glassEnabled
                          ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                          : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                      return Padding(
                        padding: EdgeInsets.only(right: 8 * scale),
                        child: HoverScale(
                          child: GestureDetector(
                            onTap: () async {
                              final newValue = o['value'] as bool;
                              ref.read(glassEnabledProvider.notifier).state = newValue;
                              await TokenStorage.saveGlassEnabled(newValue);
                              
                              if (!newValue) {
                                if (ref.read(accentColorProvider) == Colors.transparent) {
                                  await TokenStorage.saveWasTransparentColor(true);
                                  ref.read(accentColorProvider.notifier).state = Colors.grey;
                                  await TokenStorage.saveAccentColor(Colors.grey.value);
                                } else {
                                  await TokenStorage.saveWasTransparentColor(false);
                                }
                              } else {
                                final wasTransparent = await TokenStorage.getWasTransparentColor();
                                if (wasTransparent) {
                                  ref.read(accentColorProvider.notifier).state = Colors.transparent;
                                  await TokenStorage.saveAccentColor(Colors.transparent.value);
                                  await TokenStorage.saveWasTransparentColor(false);
                                }
                              }
                            },
                            child: button,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildTelemetrySelector(double scale) {
    return FutureBuilder<Map<String, dynamic>>(
      future: TokenStorage.getTelemetryData(),
      builder: (context, snapshot) {
        final loc = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

        final tracksPlayed = snapshot.data?['tracksPlayed'] ?? 0;
        final totalSeconds = snapshot.data?['totalListeningTime'] ?? 0;
        final totalHours = totalSeconds ~/ 3600;
        final totalMinutes = (totalSeconds % 3600) ~/ 60;
        final daysInstalled = snapshot.data?['daysInstalled'] ?? 0;
        final favoriteArtist = snapshot.data?['favoriteArtist'];
        final favoriteTrack = snapshot.data?['favoriteTrack'];
        final favoritePlatform = snapshot.data?['favoritePlatform'];
        final lastReset = snapshot.data?['lastResetDate'];

        Widget buildStatCard({
          required IconData icon,
          required String label,
          required String value,
          required Color color,
          int flex = 1,
        }) {
          return Expanded(
            flex: flex,
            child: _buildGlassContainer(
              glassEnabled: glassEnabled,
              isDark: isDark,
              borderRadius: BorderRadius.circular(24 * scale),
              scale: scale,
              child: Padding(
                padding: EdgeInsets.all(20 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8 * scale),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          child: Icon(icon, color: color, size: 20 * scale),
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Text(
                            label,
                            style: s(TextStyle(
                              fontSize: 13 * scale,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            )),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16 * scale),
                    Text(
                      value,
                      style: s(TextStyle(
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      )),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        String formattedTime = '${totalHours}h ${totalMinutes}m';
        if (totalHours == 0) formattedTime = '${totalMinutes}m';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.analytics_rounded, color: effectiveAccent, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.telemetry, style: s(TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold))),
                      if (lastReset != null)
                        Text(
                          'Last reset: ${DateTime.parse(lastReset).day}.${DateTime.parse(lastReset).month}.${DateTime.parse(lastReset).year}',
                          style: s(TextStyle(fontSize: 11 * scale, color: Colors.grey)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Column(
                children: [
                  Row(
                    children: [
                      buildStatCard(
                        icon: Icons.play_circle_filled_rounded,
                        label: loc.tracksPlayed,
                        value: '$tracksPlayed',
                        color: Colors.blueAccent,
                      ),
                      SizedBox(width: 16 * scale),
                      buildStatCard(
                        icon: Icons.timer_rounded,
                        label: loc.listeningTime,
                        value: formattedTime,
                        color: Colors.orangeAccent,
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),
                  Row(
                    children: [
                      buildStatCard(
                        icon: Icons.calendar_today_rounded,
                        label: loc.daysInstalled,
                        value: '$daysInstalled',
                        color: Colors.purpleAccent,
                      ),
                      SizedBox(width: 16 * scale),
                      buildStatCard(
                        icon: Icons.star_rounded,
                        label: loc.favoritePlatform,
                        value: favoritePlatform == 'Yandex' ? loc.yandexMusic : (favoritePlatform == 'SoundCloud' ? loc.soundCloud : '—'),
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),
                  Row(
                    children: [
                      buildStatCard(
                        icon: Icons.person_rounded,
                        label: loc.favoriteArtist,
                        value: favoriteArtist ?? '—',
                        color: Colors.pinkAccent,
                      ),
                      SizedBox(width: 16 * scale),
                      buildStatCard(
                        icon: Icons.music_note_rounded,
                        label: loc.favoriteTrack,
                        value: favoriteTrack ?? '—',
                        color: Colors.cyanAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * scale),
            Center(
              child: HoverScale(
                child: GestureDetector(
                  onTap: () async {
                    await TokenStorage.clearTelemetry();
                    if (mounted) {
                      setState(() {});
                      _showGlassToast(loc.statisticsCleared);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: _buildGlassContainer(
                    glassEnabled: glassEnabled,
                    isDark: isDark,
                    borderRadius: BorderRadius.circular(50 * scale),
                    scale: scale,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32 * scale, vertical: 14 * scale),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            loc.clearStatistics,
                            style: s(TextStyle(
                              fontSize: 15 * scale,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            )),                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24 * scale),
          ],
        );
      },
    );
  }

  Widget _buildPlayerSliderStyleSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final currentMode = ref.watch(uiModeProvider);
        final style = ref.watch(playerSliderStyleProvider);
        final options = [
          {'value': 'standard', 'title': loc.standard},
          {'value': 'wavy', 'title': loc.wavy},
          {'value': 'dashed', 'title': loc.dashed},
          {'value': 'dots', 'title': loc.dots},
        ];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final isDisabled = currentMode == 'v2';

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                  child: Row(
                    children: [
                      Icon(Icons.linear_scale_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                      SizedBox(width: 16 * scale),
                      Text(loc.playerSliderStyle, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: SmoothScrollWrapper(
                    builder: (context, controller) => SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: options.map((o) {
                          final selected = style == o['value'];
                          final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                          final buttonContent = Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                            child: Text(o['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                          );
                          final button = glassEnabled
                              ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                              : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                          return Padding(
                            padding: EdgeInsets.only(right: 8 * scale),
                            child: HoverScale(
                              child: GestureDetector(
                                onTap: isDisabled ? null : () async {
                                  ref.read(playerSliderStyleProvider.notifier).state = o['value'] as String;
                                  await TokenStorage.savePlayerSliderStyle(o['value'] as String);
                                },
                                child: button,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16 * scale),
              ],
            ),
            if (isDisabled)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  child: AbsorbPointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20 * scale),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCoverEffectSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentEffect = ref.watch(coverEffectProvider);
        final loc = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectivePrimary = primary.opacity == 0 ? Colors.grey : primary;

        buildOption({required String label, required bool selected, required VoidCallback onTap}) {
          final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
            child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
          );

          final button = glassEnabled
              ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
              : Container(decoration: BoxDecoration(color: selected ? effectivePrimary : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);

          return Padding(
            padding: EdgeInsets.only(right: 8 * scale),
            child: HoverScale(child: GestureDetector(onTap: onTap, child: button)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.coverEffect, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Row(
                children: [
                  buildOption(label: loc.none, selected: currentEffect == 'none', onTap: () {
                    ref.read(coverEffectProvider.notifier).state = 'none';
                    TokenStorage.saveCoverEffect('none');
                  }),
                  buildOption(label: loc.blood, selected: currentEffect == 'blood', onTap: () {
                    ref.read(coverEffectProvider.notifier).state = 'blood';
                    TokenStorage.saveCoverEffect('blood');
                  }),
                  buildOption(label: loc.slime, selected: currentEffect == 'slime', onTap: () {
                    ref.read(coverEffectProvider.notifier).state = 'slime';
                    TokenStorage.saveCoverEffect('slime');
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildV2FloatingSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentMode = ref.watch(uiModeProvider);
        final floatingEnabled = ref.watch(v2FloatingEnabledProvider);
        final loc = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectivePrimary = primary.opacity == 0 ? Colors.grey : primary;
        final isDisabled = currentMode != 'v2';

        buildOption({required String label, required bool selected, required VoidCallback onTap}) {
          final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
            child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
          );

          final button = glassEnabled
              ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
              : Container(decoration: BoxDecoration(color: selected ? effectivePrimary : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);

          return Padding(
            padding: EdgeInsets.only(right: 8 * scale),
            child: HoverScale(child: GestureDetector(onTap: isDisabled ? null : onTap, child: button)),
          );
        }

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                  child: Row(
                    children: [
                      Icon(Icons.animation_rounded, color: effectivePrimary, size: 24 * scale),
                      SizedBox(width: 16 * scale),
                      Text(loc.v2Floating, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: Row(
                    children: [
                      buildOption(label: loc.v2Static, selected: !floatingEnabled, onTap: () {
                        ref.read(v2FloatingEnabledProvider.notifier).state = false;
                        TokenStorage.saveV2FloatingEnabled(false);
                      }),
                      buildOption(label: loc.v2FloatingAnim, selected: floatingEnabled, onTap: () {
                        ref.read(v2FloatingEnabledProvider.notifier).state = true;
                        TokenStorage.saveV2FloatingEnabled(true);
                      }),
                    ],
                  ),
                ),
              ],
            ),
            if (isDisabled)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  child: AbsorbPointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20 * scale),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(color: color.withOpacity(0.4), width: 1 * scale),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9 * scale,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5 * scale,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double scale,
    required bool isDark,
    required bool glassEnabled,
  }) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(16 * scale),
          scale: scale,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18 * scale, color: effectiveAccent),
                SizedBox(width: 10 * scale),
                Text(
                  label,
                  style: s(TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreezeOptimizationSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final enabled = ref.watch(freezeOptimizationProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

        final options = [
          {'value': false, 'title': loc.off},
          {'value': true, 'title': loc.on}
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.ac_unit_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(loc.freezeOptimization, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                            SizedBox(width: 10 * scale),
                            _buildBadge(loc.recommended, effectivePrimary, scale),
                          ],
                        ),
                        Text(loc.freezeOptimizationSubtitle, style: TextStyle(fontSize: 13 * scale, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Row(
                children: options.map((o) {
                  final selected = enabled == o['value'];
                  final buttonContent = Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                    child: Text(o['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                  );
                  final button = glassEnabled
                      ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                      : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                  return Padding(
                    padding: EdgeInsets.only(right: 8 * scale),
                    child: HoverScale(
                      child: GestureDetector(
                        onTap: () {
                          final newVal = o['value'] as bool;
                          ref.read(freezeOptimizationProvider.notifier).state = newVal;
                          TokenStorage.saveFreezeOptimization(newVal);
                        },
                        child: button,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildMinimizeToTraySelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final enabled = ref.watch(minimizeToTrayEnabledProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

        final options = [
          {'value': false, 'title': loc.off},
          {'value': true, 'title': loc.on}
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.system_update_alt_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.minimizeToTray, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                        Text(loc.minimizeToTraySubtitle, style: TextStyle(fontSize: 13 * scale, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Row(
                children: options.map((o) {
                  final selected = enabled == o['value'];
                  final val = o['value'] as bool;
                  final buttonContent = Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                    child: Text(o['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                  );
                  
                  final button = glassEnabled
                      ? _buildGlassContainer(
                          glassEnabled: true,
                          isDark: isDark,
                          child: buttonContent,
                          borderRadius: BorderRadius.circular(50 * scale),
                          scale: scale,
                          customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: selected 
                                ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary)
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(50 * scale),
                          ),
                          child: buttonContent,
                        );

                  return Padding(
                    padding: EdgeInsets.only(right: 8 * scale),
                    child: HoverScale(
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(minimizeToTrayEnabledProvider.notifier).state = val;
                          await TokenStorage.saveMinimizeToTrayEnabled(val);
                          await windowManager.setPreventClose(val);
                        },
                        child: button,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildDiscordRPCSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final enabled = ref.watch(discordRPCEnabledProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

        final options = [
          {'value': false, 'title': loc.off},
          {'value': true, 'title': loc.on}
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.discord_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.discordRPC, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                        Text(loc.discordRPCSubtitle, style: TextStyle(fontSize: 13 * scale, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: Row(
                children: options.map((o) {
                  final selected = enabled == o['value'];
                  final val = o['value'] as bool;
                  final buttonContent = Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                    child: Text(o['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                  );
                  
                  final button = glassEnabled
                      ? _buildGlassContainer(
                          glassEnabled: true,
                          isDark: isDark,
                          child: buttonContent,
                          borderRadius: BorderRadius.circular(50 * scale),
                          scale: scale,
                          customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: selected 
                                ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary)
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(50 * scale),
                          ),
                          child: buttonContent,
                        );

                  return Padding(
                    padding: EdgeInsets.only(right: 8 * scale),
                    child: HoverScale(
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(discordRPCEnabledProvider.notifier).state = val;
                          await TokenStorage.saveDiscordRPCEnabled(val);
                          DiscordService().setEnabled(val);
                        },
                        child: button,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildBorderSettings(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final gradientEnabled = ref.watch(borderGradientEnabledProvider);
        final borderColor = ref.watch(borderColorProvider);
        final gradientColor1 = ref.watch(borderGradientColor1Provider);
        final gradientColor2 = ref.watch(borderGradientColor2Provider);
        final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

        final colorOptions = [
          {'color': Colors.white, 'label': loc.white},
          {'color': Colors.black, 'label': loc.black},
          {'color': Colors.cyanAccent, 'label': loc.cyan},
          {'color': Colors.redAccent, 'label': loc.red},
          {'color': Colors.orangeAccent, 'label': loc.orange},
          {'color': Colors.purpleAccent, 'label': loc.purple},
          {'color': Colors.greenAccent, 'label': loc.green},
          {'color': Colors.blueAccent, 'label': loc.blue},
          {'color': Colors.pinkAccent, 'label': loc.pink},
        ];

        Widget buildOption({required String label, required bool selected, required VoidCallback onTap}) {
          final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
            child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
          );

          final button = glassEnabled
              ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
              : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);

          return Padding(
            padding: EdgeInsets.only(right: 8 * scale),
            child: HoverScale(child: GestureDetector(onTap: onTap, child: button)),
          );
        }

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                  child: Row(
                    children: [
                      Icon(Icons.border_outer_rounded, color: effectivePrimary, size: 24 * scale),
                      SizedBox(width: 16 * scale),
                      Text(loc.gradientBorder, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: SmoothScrollWrapper(
                    builder: (context, controller) => SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          buildOption(label: loc.off, selected: !gradientEnabled, onTap: () {
                            ref.read(borderGradientEnabledProvider.notifier).state = false;
                            TokenStorage.saveBorderGradientEnabled(false);
                          }),
                          buildOption(label: loc.on, selected: gradientEnabled, onTap: () {
                            ref.read(borderGradientEnabledProvider.notifier).state = true;
                            TokenStorage.saveBorderGradientEnabled(true);
                          }),
                          ],
                          ),
                          ),
                          ),
                          ),
                if (gradientEnabled) ...[
                  _buildHorizontalOptions<double>(
                    title: loc.borderSpeed,
                    currentValue: ref.watch(borderAnimationSpeedProvider),
                    scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectivePrimary,
                    options: [0.5, 1.0, 1.5, 2.0, 3.0, 5.0].map((v) => {'value': v, 'label': "${v.toStringAsFixed(1)}x"}).toList(),
                    onSelected: (v) {
                      ref.read(borderAnimationSpeedProvider.notifier).state = v;
                      TokenStorage.saveBorderAnimationSpeed(v);
                    },
                  ),
                ],
                          if (!gradientEnabled) ...[
                          Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                          child: Text(loc.borderColor, style: TextStyle(fontSize: 15 * scale, color: Colors.grey)),
                          ),                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                    child: SmoothScrollWrapper(
                      builder: (context, controller) => SingleChildScrollView(
                        controller: controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            buildOption(label: loc.defaultColor, selected: borderColor == null, onTap: () {
                              ref.read(borderColorProvider.notifier).state = null;
                              TokenStorage.saveBorderColor(0);
                            }),
                            buildOption(label: loc.none, selected: borderColor == Colors.transparent, onTap: () {
                              ref.read(borderColorProvider.notifier).state = Colors.transparent;
                              TokenStorage.saveBorderColor(1);
                            }),
                            ...colorOptions.map((o) {
                              final color = o['color'] as Color;
                              return buildOption(
                                label: o['label'] as String,
                                selected: borderColor?.value == color.value,
                                onTap: () {
                                  ref.read(borderColorProvider.notifier).state = color;
                                  TokenStorage.saveBorderColor(color.value);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                    child: Text(loc.gradientColor1, style: TextStyle(fontSize: 15 * scale, color: Colors.grey)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                    child: SmoothScrollWrapper(
                      builder: (context, controller) => SingleChildScrollView(
                        controller: controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: colorOptions.map((o) {
                            final color = o['color'] as Color;
                            return buildOption(
                              label: o['label'] as String,
                              selected: gradientColor1.value == color.value,
                              onTap: () {
                                ref.read(borderGradientColor1Provider.notifier).state = color;
                                TokenStorage.saveBorderGradientColor1(color.value);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                    child: Text(loc.gradientColor2, style: TextStyle(fontSize: 15 * scale, color: Colors.grey)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                    child: SmoothScrollWrapper(
                      builder: (context, controller) => SingleChildScrollView(
                        controller: controller,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: colorOptions.map((o) {
                            final color = o['color'] as Color;
                            return buildOption(
                              label: o['label'] as String,
                              selected: gradientColor2.value == color.value,
                              onTap: () {
                                ref.read(borderGradientColor2Provider.notifier).state = color;
                                TokenStorage.saveBorderGradientColor2(color.value);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 16 * scale),
              ],
            ),
            if (!glassEnabled)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  child: AbsorbPointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20 * scale),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTitleBarSettings(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;
        final effectivePrimary = primary.a == 0 ? Colors.grey : primary;
        final glassEnabled = ref.watch(glassEnabledProvider);
        
        final isEnabled = ref.watch(customTitleBarEnabledProvider);

        Widget buildOption({required String label, required bool selected, required VoidCallback onTap}) {
          final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
            child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
          );

          final button = glassEnabled
              ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
              : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);

          return Padding(
            padding: EdgeInsets.only(right: 8 * scale),
            child: HoverScale(child: GestureDetector(onTap: onTap, child: button)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.web_asset_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.customTitleBar, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SmoothScrollWrapper(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      buildOption(label: loc.off, selected: !isEnabled, onTap: () {
                        ref.read(customTitleBarEnabledProvider.notifier).state = false;
                        TokenStorage.saveCustomTitleBarEnabled(false);
                      }),
                      buildOption(label: loc.on, selected: isEnabled, onTap: () {
                        ref.read(customTitleBarEnabledProvider.notifier).state = true;
                        TokenStorage.saveCustomTitleBarEnabled(true);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageFiltersSettings(double scale) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final glassEnabled = ref.watch(glassEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
          child: Row(
            children: [
              Icon(Icons.filter_b_and_w_rounded, color: effectiveAccent, size: 24 * scale),
              SizedBox(width: 16 * scale),
              Text(loc.filterSection, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
        _buildHorizontalOptions<double>(
          title: loc.hueShift,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(hueShiftProvider),
          options: [
            {'value': 0.0, 'label': loc.none},
            {'value': pi / 2, 'label': '90°'},
            {'value': pi, 'label': '180°'},
            {'value': -pi / 2, 'label': '270°'},
          ],
          onSelected: (v) {
            ref.read(hueShiftProvider.notifier).state = v;
            TokenStorage.saveHueShift(v);
          },
        ),
        _buildHorizontalOptions<double>(
          title: loc.saturation,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(saturationProvider),
          options: [
            {'value': 0.0, 'label': '0%'},
            {'value': 0.5, 'label': '50%'},
            {'value': 1.0, 'label': '100%'},
            {'value': 1.5, 'label': '150%'},
            {'value': 2.0, 'label': '200%'},
          ],
          onSelected: (v) {
            ref.read(saturationProvider.notifier).state = v;
            TokenStorage.saveSaturation(v);
          },
        ),
        _buildHorizontalOptions<double>(
          title: loc.contrast,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(contrastProvider),
          options: [
            {'value': 0.5, 'label': '50%'},
            {'value': 1.0, 'label': '100%'},
            {'value': 1.5, 'label': '150%'},
            {'value': 2.0, 'label': '200%'},
          ],
          onSelected: (v) {
            ref.read(contrastProvider.notifier).state = v;
            TokenStorage.saveContrast(v);
          },
        ),
        _buildHorizontalOptions<double>(
          title: loc.brightness,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(brightnessProvider),
          options: [
            {'value': 0.5, 'label': '50%'},
            {'value': 1.0, 'label': '100%'},
            {'value': 1.5, 'label': '150%'},
            {'value': 2.0, 'label': '200%'},
          ],
          onSelected: (v) {
            ref.read(brightnessProvider.notifier).state = v;
            TokenStorage.saveBrightness(v);
          },
        ),
        _buildHorizontalOptions<double>(
          title: loc.grayscale,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(grayscaleProvider),
          options: [
            {'value': 0.0, 'label': loc.off},
            {'value': 0.5, 'label': '50%'},
            {'value': 1.0, 'label': '100%'},
          ],
          onSelected: (v) {
            ref.read(grayscaleProvider.notifier).state = v;
            TokenStorage.saveGrayscale(v);
          },
        ),
        _buildHorizontalOptions<double>(
          title: loc.pixelation,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(pixelationProvider),
          options: [
            {'value': 0.0, 'label': loc.none},
            {'value': 0.4, 'label': 'Low'},
            {'value': 0.7, 'label': 'Med'},
            {'value': 0.9, 'label': 'High'},
          ],
          onSelected: (v) {
            ref.read(pixelationProvider.notifier).state = v;
            TokenStorage.savePixelation(v);
          },
        ),
        _buildHorizontalOptions<bool>(
          title: loc.backgroundBlur,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(blurEnabledProvider),
          options: [
            {'value': false, 'label': loc.off},
            {'value': true, 'label': loc.on},
          ],
          onSelected: (v) {
            ref.read(blurEnabledProvider.notifier).state = v;
            TokenStorage.saveBlurEnabled(v);
          },
        ),
        _buildHorizontalOptions<bool>(
          title: loc.applyFilterToAll,
          scale: scale, isDark: isDark, glassEnabled: glassEnabled, accent: effectiveAccent,
          currentValue: ref.watch(applyFilterToAllProvider),
          options: [
            {'value': false, 'label': loc.off},
            {'value': true, 'label': loc.on},
          ],
          onSelected: (v) {
            ref.read(applyFilterToAllProvider.notifier).state = v;
            TokenStorage.saveApplyFilterToAll(v);
          },
        ),
        SizedBox(height: 16 * scale),
      ],
    );
  }

  Widget _buildUiModeSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentMode = ref.watch(uiModeProvider);
        final loc = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectivePrimary = primary.opacity == 0 ? Colors.grey : primary;

        buildOption({required String label, required String modeValue, required VoidCallback onTap}) {
          final selected = currentMode == modeValue;
          final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
            child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
          );

          final button = glassEnabled
              ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: content, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
              : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: content);

          return Padding(
            padding: EdgeInsets.only(right: 8 * scale),
            child: HoverScale(child: GestureDetector(onTap: onTap, child: button)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.layers_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.uiMode, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SmoothScrollWrapper(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      buildOption(label: loc.uiV1, modeValue: 'v1', onTap: () {
                        ref.read(uiModeProvider.notifier).state = 'v1';
                        TokenStorage.saveUiMode('v1');
                      }),
                      buildOption(label: loc.uiV2, modeValue: 'v2', onTap: () {
                        ref.read(uiModeProvider.notifier).state = 'v2';
                        TokenStorage.saveUiMode('v2');
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScaleSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentScale = ref.watch(scaleProvider);
        final percentages = [70, 80, 90, 100, 110, 120, 130];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        final loc = AppLocalizations.of(context)!;
        final primary = Theme.of(context).colorScheme.primary;
        final effectivePrimary = primary.opacity == 0 ? Colors.grey : primary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.zoom_in_rounded, color: effectivePrimary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.interfaceScale, style: s(TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500))),
                  SizedBox(width: 12 * scale),
                  _buildBadge("${loc.standard} 80%", effectivePrimary, scale),
                  SizedBox(width: 8 * scale),
                  _buildBadge(loc.experimental, Colors.orangeAccent, scale),
                ],
              ),
            ),
            SizedBox(height: 4 * scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SmoothScrollWrapper(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: percentages.map((p) {
                      final selected = (currentScale * 100).round() == p;
                      final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                      final buttonContent = Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                        child: Text('$p%', style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
                      );
                      final button = glassEnabled
                          ? _buildGlassContainer(glassEnabled: true, isDark: isDark, child: buttonContent, borderRadius: BorderRadius.circular(50 * scale), scale: scale, customBorder: selected ? Border.all(color: effectivePrimary, width: 2 * scale) : null)
                          : Container(decoration: BoxDecoration(color: selected ? (effectivePrimary.value == Colors.grey.value ? (isDark ? Colors.white24 : Colors.black87) : effectivePrimary) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(50 * scale)), child: buttonContent);
                      return Padding(
                        padding: EdgeInsets.only(right: 8 * scale),
                        child: HoverScale(
                          child: GestureDetector(
                            onTap: () async {
                              final newScale = p / 100.0;
                              ref.read(scaleProvider.notifier).state = newScale;
                              await TokenStorage.saveScale(newScale);
                            },
                            child: button,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildMainPlayerArea(dynamic current, bool glassEnabled, double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final uiMode = ref.watch(uiModeProvider);
        if (uiMode == 'v2') {
          return _buildV2PlayerView(current, glassEnabled, scale);
        }
        
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;
        final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
        final isLiked = current != null && _likedTracks.any((t) => t.id == current.id);
        
        return Center(
      child: Transform.translate(
        offset: _playerOffset,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: _isPlayerExpanded ? 950 * scale : 500 * scale,
          constraints: _isPlayerExpanded 
              ? BoxConstraints(
                  minHeight: 740 * scale,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                )
              : const BoxConstraints(),
          child: current != null
            ? _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                scale: scale,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: _isPlayerExpanded ? 740 * scale : 0,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 500 * scale,
                            child: Padding(
                              padding: EdgeInsets.only(top: 10 * scale, bottom: 24 * scale, left: 24 * scale, right: 24 * scale),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final newX = _playerOffset.dx + details.delta.dx;
                                        final newY = _playerOffset.dy + details.delta.dy;
                                        _playerOffset = Offset(
                                          newX.clamp(-1500.0, 1500.0),
                                          newY.clamp(-1000.0, 1000.0),
                                        );
                                      });
                                    },
                                    onDoubleTap: () {
                                      setState(() {
                                        _playerOffset = Offset.zero;
                                      });
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.only(bottom: 10 * scale),
                                        child: Center(
                                          child: Container(
                                            width: 40 * scale,
                                            height: 4 * scale,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(isDark ? 0.3 : 0.5),
                                              borderRadius: BorderRadius.circular(10 * scale),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    key: ValueKey(current.id),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isPlayerExpanded = !_isPlayerExpanded;
                                          if (_isPlayerExpanded && _parsedLyrics.isEmpty) {
                                            _fetchLyrics(current.title, current.artistName);
                                          }
                                        });
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          width: 452 * scale,
                                          height: 452 * scale,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(40 * scale),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(40 * scale),
                                            child: _buildCustomTrackCover(current, scale),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 28 * scale),
                                  Text(
                                    current.title,
                                    style: s(TextStyle(fontSize: 26 * scale, fontWeight: FontWeight.bold)),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 8 * scale),
                                  ClickableArtistsText(
                                    artistName: current.artistName,
                                    originalArtistData: current.source == AudioSourceType.yandex
                                        ? (current.originalObject is ym.Track ? (current.originalObject as ym.Track).artists : null)
                                        : (current.originalObject != null && current.originalObject['user'] != null ? [current.originalObject['user']] : null),
                                    fontSize: 17 * scale,
                                    color: Colors.grey,
                                    textAlign: TextAlign.center,
                                    onArtistTap: _showArtistCard,
                                  ),
                                  SizedBox(height: 30 * scale),
                                  StreamBuilder<Duration>(initialData: _playerService.position,
                                    stream: _isFrozen 
                                      ? _playerService.positionStream.distinct((a, b) => a.inSeconds == b.inSeconds)
                                      : _playerService.positionStream,
                                    builder: (context, snapshot) {
                                      final pos = snapshot.data ?? Duration.zero;
                                      final dur = _playerService.duration ?? Duration.zero;
                                      final sliderStyle = ref.watch(playerSliderStyleProvider);
                                      final double val = pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble());
                                      final double mx = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1;
                                      return RepaintBoundary(
                                        child: Column(
                                          children: [
                                            if (sliderStyle == 'wavy')
                                              WavySlider(
                                                value: val,
                                                max: mx,
                                                color: effectiveAccent,
                                                onChanged: (v) => _playerService.seek(Duration(milliseconds: v.toInt())),
                                              )
                                            else if (sliderStyle == 'dashed')
                                              DashedSlider(
                                                value: val,
                                                max: mx,
                                                color: effectiveAccent,
                                                onChanged: (v) => _playerService.seek(Duration(milliseconds: v.toInt())),
                                              )
                                            else if (sliderStyle == 'dots')
                                              DotsSlider(
                                                value: val,
                                                max: mx,
                                                color: effectiveAccent,
                                                onChanged: (v) => _playerService.seek(Duration(milliseconds: v.toInt())),
                                              )
                                            else
                                              SliderTheme(
                                                data: SliderTheme.of(context).copyWith(
                                                  inactiveTrackColor: effectiveAccent.withOpacity(0.2),
                                                  activeTrackColor: effectiveAccent,
                                                  thumbColor: effectiveAccent,
                                                  overlayColor: effectiveAccent.withOpacity(0.12),
                                                  trackHeight: 4,
                                                ),
                                                child: Slider(
                                                  value: val,
                                                  max: mx,
                                                  onChanged: (v) => _playerService.seek(Duration(milliseconds: v.toInt())),
                                                ),
                                              ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(_formatDuration(pos), style: s(TextStyle(fontSize: 13.5 * scale, fontWeight: FontWeight.w500, color: Colors.grey, fontFeatures: const [FontFeature.tabularFigures()]))),
                                                  Text(_formatDuration(dur), style: s(TextStyle(fontSize: 13.5 * scale, fontWeight: FontWeight.w500, color: Colors.grey, fontFeatures: const [FontFeature.tabularFigures()])))
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 12 * scale),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 48 * scale,
                                        height: 48 * scale,
                                        child: Center(child: _buildSourceIcon(current?.source, scale * 1.5)),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 40 * scale,
                                              height: 40 * scale,
                                              child: StreamBuilder<LoopMode>(
                                                stream: _playerService.loopModeStream,
                                                builder: (context, snapshot) {
                                                  final loopMode = snapshot.data ?? _playerService.loopMode;
                                                  return GestureDetector(
                                                    onTap: () {
                                                      if (loopMode == LoopMode.one) {
                                                        _playerService.setLoopMode(LoopMode.off);
                                                      } else {
                                                        _playerService.setLoopMode(LoopMode.one);
                                                      }
                                                    },
                                                    child: Center(
                                                      child: HoverScale(
                                                        child: Icon(
                                                          loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, 
                                                          color: effectiveAccent, 
                                                          size: 26 * scale
                                                        )
                                                      )
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            SizedBox(width: 8 * scale),
                                            SizedBox(
                                              width: 48 * scale,
                                              height: 48 * scale,
                                              child: GestureDetector(
                                                onTapDown: (_) => _prevAnimationController.forward(),
                                                onTapUp: (_) => _prevAnimationController.reverse(),
                                                onTapCancel: () => _prevAnimationController.reverse(),
                                                onTap: _prevTrack,
                                                child: Center(child: ScaleTransition(scale: _prevAnimation, child: HoverScale(scale: 1.1, child: Icon(Icons.skip_previous_rounded, color: effectiveAccent, size: 36 * scale)))),
                                              ),
                                            ),
                                            SizedBox(width: 16 * scale),
                                            SizedBox(
                                              width: 64 * scale,
                                              height: 64 * scale,
                                              child: GestureDetector(
                                                onTapDown: (_) => _pauseAnimationController.forward(),
                                                onTapUp: (_) => _pauseAnimationController.reverse(),
                                                onTapCancel: () => _pauseAnimationController.reverse(),
                                                onTap: () async {
                                                  try {
                                                    if (_playerService.playing) {
                                                      await _playerService.pause();
                                                    } else {
                                                      await _playerService.play();
                                                    }
                                                  } catch (e) {
                                                    debugPrint("Play/Pause error: $e");
                                                  }
                                                },
                                                child: Center(
                                                  child: ScaleTransition(
                                                    scale: _pauseAnimation,
                                                    child: StreamBuilder<PlayerState>(initialData: _playerService.playerState,
                                                      stream: _playerService.playerStateStream,
                                                      builder: (_, snap) => HoverScale(scale: 1.1, child: Icon((snap.data?.playing ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, color: effectiveAccent, size: 54 * scale)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 16 * scale),
                                            SizedBox(
                                              width: 48 * scale,
                                              height: 48 * scale,
                                              child: GestureDetector(
                                                onTapDown: (_) => _nextAnimationController.forward(),
                                                onTapUp: (_) => _nextAnimationController.reverse(),
                                                onTapCancel: () => _nextAnimationController.reverse(),
                                                onTap: _nextTrack,
                                                child: Center(child: ScaleTransition(scale: _nextAnimation, child: HoverScale(scale: 1.1, child: Icon(Icons.skip_next_rounded, color: effectiveAccent, size: 36 * scale)))),
                                              ),
                                            ),
                                            SizedBox(width: 8 * scale),
                                            SizedBox(
                                              width: 40 * scale,
                                              height: 40 * scale,
                                              child: GestureDetector(
                                                onTap: () => _showAddToPlaylistSheet(current),
                                                child: Center(
                                                  child: HoverScale(
                                                    child: Icon(Icons.playlist_add_rounded, color: effectiveAccent, size: 26 * scale)
                                                  )
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 48 * scale,
                                        height: 48 * scale,
                                        child: GestureDetector(
                                          onTapDown: (_) => _likeAnimationController.forward(),
                                          onTapUp: (_) => _likeAnimationController.reverse(),
                                          onTapCancel: () => _likeAnimationController.reverse(),
                                          onTap: _toggleLike,
                                          child: Center(child: ScaleTransition(scale: _likeAnimation, child: HoverScale(scale: 1.1, child: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: effectiveAccent, size: 30 * scale)))),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8 * scale),
                                  Row(
                                    children: [
                                      Icon(Icons.volume_down, size: 24 * scale),
                                      Expanded(
                                        child: StreamBuilder<double>(
                                          stream: _playerService.volumeStream,
                                          builder: (_, snap) => SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              inactiveTrackColor: effectiveAccent.withOpacity(0.2),
                                              activeTrackColor: effectiveAccent,
                                              thumbColor: effectiveAccent,
                                              overlayColor: effectiveAccent.withOpacity(0.12),
                                              trackHeight: 4,
                                            ),
                                            child: Slider(
                                              value: snap.data ?? _playerService.volume,
                                              onChanged: (v) {
                                                _playerService.setVolume(v);
                                                TokenStorage.saveVolume(v);
                                              }
                                            ),
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.volume_up, size: 24 * scale),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isPlayerExpanded)
                            SizedBox(width: 450 * scale),
                        ],
                      ),
                      if (_isPlayerExpanded)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 500 * scale,
                          width: 450 * scale,
                          child: ClipRect(
                            child: Padding(
                              padding: EdgeInsets.only(top: 48 * scale, bottom: 48 * scale, right: 32 * scale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _isLoadingLyrics
                                      ? Center(child: CircularProgressIndicator(color: effectiveAccent))
                                      : _parsedLyrics.isEmpty
                                          ? Center(
                                              child: Text(
                                                AppLocalizations.of(context)!.noLyrics, 
                                                style: TextStyle(color: Colors.grey, fontSize: 18 * scale)
                                              )
                                            )
                                          : SyncedLyricsView(
                                                lyrics: _parsedLyrics,
                                                playerStream: _playerService.positionStream,
                                                isDark: isDark,
                                                scale: scale,
                                                accentColor: effectiveAccent,
                                                hasSyncedTime: _hasSyncedLyrics,
                                                isFrozen: _isFrozen,
                                              ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
        ),
      ),
    );
      }
    );
  }

  Widget _buildV2PlayerView(dynamic current, bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final loc = AppLocalizations.of(context)!;
    final isLiked = current != null && _likedTracks.any((t) => t.id == current.id);

    return Center(
      child: _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: BorderRadius.circular(40 * scale),
        scale: scale,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 48 * scale, vertical: 24 * scale),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 2),
                        builder: (context, value, child) {
                          final coverUrl = (_customTrackCoverUrl != null && _customTrackCoverUrl!.isNotEmpty) 
                              ? _customTrackCoverUrl 
                              : (current != null ? (current is AppTrack ? current.coverUrl : (current as dynamic).coverUrl) : null);

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Consumer(
                                builder: (context, ref, _) {
                                  final effect = ref.watch(coverEffectProvider);
                                  if (effect == 'none') return const SizedBox.shrink();
                                  return _CoverEffectLayer(
                                    effect: effect,
                                    scale: scale,
                                  );
                                },
                              ),
                              if (coverUrl != null || _customTrackCoverPath != null)
                                ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 20 * scale, sigmaY: 20 * scale),
                                  child: Container(
                                    width: 345 * scale,
                                    height: 345 * scale,
                                    child: Opacity(
                                      opacity: 1.0,
                                      child: _FreezableImage(
                                        url: coverUrl,
                                        path: _customTrackCoverPath,
                                        isFrozen: _isFrozen,
                                        scale: scale,
                                      ),
                                    ),
                                  ),
                                ),
                              Container(
                                width: 310 * scale,
                                height: 310 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 30 * scale,
                                      spreadRadius: 5 * scale,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: _toggleLyrics,
                        child: _V2CoverArt(
                          current: current,
                          scale: scale * 0.75,
                          isDark: isDark,
                          effectiveAccent: effectiveAccent,
                          customTrackCoverBuilder: _buildCustomTrackCover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 40 * scale),
              Expanded(
                flex: 6,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _isPlayerExpanded 
                    ? Column(
                        key: const ValueKey('v2_lyrics'),
                        children: [
                          Expanded(
                            child: _isLoadingLyrics
                              ? Center(child: CircularProgressIndicator(color: effectiveAccent))
                              : _parsedLyrics.isEmpty
                                  ? Center(
                                      child: Text(
                                        loc.noLyrics, 
                                        style: TextStyle(color: Colors.grey, fontSize: 18 * scale)
                                      )
                                    )
                                  : SyncedLyricsView(
                                      lyrics: _parsedLyrics,
                                      playerStream: _playerService.positionStream,
                                      isDark: isDark,
                                      scale: scale,
                                      accentColor: effectiveAccent,
                                      hasSyncedTime: _hasSyncedLyrics,
                                      isFrozen: _isFrozen,
                                    ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 16 * scale),
                            child: IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey, size: 28 * scale),
                              onPressed: _toggleLyrics,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('v2_info'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current?.title ?? loc.untitledTrack,
                            style: s(TextStyle(
                              fontSize: 32 * scale,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1 * scale,
                              height: 1.1,
                              color: isDark ? Colors.white : Colors.black87,
                            )),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8 * scale),
                          ClickableArtistsText(
                            artistName: current?.artistName ?? loc.unknownArtist,
                            originalArtistData: current?.source == AudioSourceType.yandex
                                ? (current?.originalObject is ym.Track ? (current?.originalObject as ym.Track).artists : null)
                                : (current?.originalObject != null && current?.originalObject['user'] != null ? [current?.originalObject['user']] : null),
                            fontSize: 18 * scale,
                            color: Colors.grey.shade500,
                            onArtistTap: _showArtistCard,
                          ),
                          SizedBox(height: 32 * scale),
                          StreamBuilder<Duration>(
                            initialData: _playerService.position,
                            stream: _isFrozen 
                              ? _playerService.positionStream.distinct((a, b) => a.inSeconds == b.inSeconds)
                              : _playerService.positionStream,
                            builder: (context, snapshot) {
                              final pos = snapshot.data ?? Duration.zero;
                              final dur = _playerService.duration ?? Duration.zero;
                              final double val = pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble());
                              final double mx = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1;
                              
                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6 * scale,
                                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8 * scale),
                                      overlayShape: RoundSliderOverlayShape(overlayRadius: 16 * scale),
                                      activeTrackColor: effectiveAccent,
                                      inactiveTrackColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                                      thumbColor: Colors.white,
                                      trackShape: const RectangularSliderTrackShape(),
                                    ),
                                    child: Slider(
                                      value: val,
                                      max: mx,
                                      onChanged: (v) => _playerService.seek(Duration(milliseconds: v.toInt())),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 4 * scale),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(pos), style: s(TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w700, color: Colors.grey.shade500, fontFeatures: const [FontFeature.tabularFigures()]))),
                                        Text(_formatDuration(dur), style: s(TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w700, color: Colors.grey.shade500, fontFeatures: const [FontFeature.tabularFigures()])))
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: 24 * scale),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSourceIcon(current?.source, scale * 1.2),
                              StreamBuilder<LoopMode>(
                                stream: _playerService.loopModeStream,
                                builder: (context, snapshot) {
                                  final loopMode = snapshot.data ?? _playerService.loopMode;
                                  return _V2ControlBtn(
                                    icon: loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                    onTap: _toggleRepeat,
                                    scale: scale,
                                    color: effectiveAccent,
                                    size: 28 * scale,
                                  );
                                },
                              ),
                              _V2ControlBtn(
                                icon: Icons.skip_previous_rounded,
                                onTap: _prevTrack,
                                scale: scale,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 44 * scale,
                              ),
                              _V2PlayBtn(
                                onTap: _togglePlayback,
                                scale: scale * 0.85,
                                effectiveAccent: effectiveAccent,
                                playerService: _playerService,
                              ),
                              _V2ControlBtn(
                                icon: Icons.skip_next_rounded,
                                onTap: _nextTrack,
                                scale: scale,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 44 * scale,
                              ),
                              _V2ControlBtn(
                                icon: Icons.playlist_add_rounded,
                                onTap: () => _showAddToPlaylistSheet(current),
                                scale: scale,
                                color: effectiveAccent,
                                size: 28 * scale,
                              ),
                              _V2ControlBtn(
                                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                onTap: _toggleLike,
                                scale: scale,
                                color: isLiked ? effectiveAccent : Colors.grey.shade600,
                                size: 28 * scale,
                              ),
                            ],
                          ),
                          SizedBox(height: 24 * scale),
                          Row(
                            children: [
                              Icon(Icons.volume_down, size: 20 * scale, color: Colors.grey),
                              Expanded(
                                child: StreamBuilder<double>(
                                  stream: _playerService.volumeStream,
                                  builder: (_, snap) => SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: effectiveAccent,
                                      inactiveTrackColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                                      thumbColor: Colors.white,
                                      trackHeight: 4 * scale,
                                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6 * scale),
                                      overlayShape: RoundSliderOverlayShape(overlayRadius: 12 * scale),
                                    ),
                                    child: Slider(
                                      value: snap.data ?? _playerService.volume,
                                      onChanged: (v) {
                                        _playerService.setVolume(v);
                                        TokenStorage.saveVolume(v);
                                      }
                                    ),
                                  ),
                                ),
                              ),
                              Icon(Icons.volume_up, size: 20 * scale, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueuePanel(bool glassEnabled, double scale, {bool isBottom = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40 * scale),
      scale: scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 20 * scale),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 16 * scale, 8 * scale, 0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_isWaveActive ? loc.myWave : loc.queue, style: s(TextStyle(fontSize: isBottom ? 28 * scale : 36 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.8 * scale))),
                    if (!_isWaveActive) Text('${_queueTracks.length} ${loc.tracks}', style: s(TextStyle(fontSize: isBottom ? 14.5 * scale : 16.5 * scale, color: Colors.grey))),
                  ],                ),
              ),
            ),
            SizedBox(height: 10 * scale),
            Expanded(
              child: _isWaveActive
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.waves_rounded, size: isBottom ? 48 * scale : 64 * scale, color: effectiveAccent.withOpacity(0.5)),
                          SizedBox(height: 24 * scale),
                          Text(
                            loc.myWave,
                            style: s(TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            _waveSource == 'yandex' ? loc.yandexMusic : loc.soundCloud,
                            style: s(TextStyle(fontSize: 16 * scale, color: Colors.grey)),
                          ),
                        ],
                      ),
                    )
                  : _queueTracks.isEmpty
                      ? Center(child: Text(loc.queueEmpty, style: s(TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87))))
                      : SmoothScrollWrapper(
                          builder: (context, controller) => ListView.separated(
                            controller: controller,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                            itemCount: _queueTracks.length,
                            separatorBuilder: (context, index) => Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08), indent: 92 * scale, endIndent: 24 * scale),
                            itemBuilder: (context, index) => _buildTrackTile(_queueTracks[index], index, _queueTracks, scale, animate: false),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTrackCover(dynamic current, double scale) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final url = (_customTrackCoverUrl != null && _customTrackCoverUrl!.isNotEmpty) ? _customTrackCoverUrl : (current != null ? current.coverUrl : null);
    
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (current is AppTrack) {
          _showTrackContextMenu(context, details.globalPosition, current, loc, isDark, scale);
        }
      },
      child: url == null && _customTrackCoverPath == null
          ? Container(
              color: Colors.grey.withOpacity(0.1),
              child: Center(
                child: Icon(Icons.music_note_rounded, size: 80 * scale, color: Colors.grey),
              ),
            )
          : _FreezableImage(
              url: url,
              path: _customTrackCoverPath,
              isFrozen: _isFrozen,
              scale: scale,
            ),
    );
  }

  Widget _buildMiniPlayer(dynamic current, bool glassEnabled, double scale) {
    if (current == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isLiked = _likedTracks.any((t) => t.id == current.id);

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(30 * scale),
      scale: scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
        child: Row(
          children: [
            GestureDetector(
              onSecondaryTapDown: (details) {
                if (current is AppTrack) {
                  final loc = AppLocalizations.of(context)!;
                  _showTrackContextMenu(context, details.globalPosition, current, loc, isDark, scale);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16 * scale),
                child: CachedNetworkImage(
                  imageUrl: current.coverUrl,
                  width: 60 * scale,
                  height: 60 * scale,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(Icons.music_note, size: 30 * scale, color: Colors.grey),
                ),
              ),
            ),
            SizedBox(width: 16 * scale),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: s(TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600))),
                  ClickableArtistsText(
                    artistName: current.artistName,
                    originalArtistData: current.source == AudioSourceType.yandex
                        ? (current.originalObject is ym.Track ? (current.originalObject as ym.Track).artists : null)
                        : (current.originalObject != null && current.originalObject['user'] != null ? [current.originalObject['user']] : null),
                    fontSize: 13 * scale,
                    color: Colors.grey,
                    onArtistTap: _showArtistCard,
                  ),
                  SizedBox(height: 4 * scale),
                  StreamBuilder<Duration>(initialData: _playerService.position,
                    stream: _isFrozen 
                      ? _playerService.positionStream.distinct((a, b) => a.inSeconds == b.inSeconds)
                      : _playerService.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data?.inMilliseconds ?? 0;
                      final dur = _playerService.duration?.inMilliseconds ?? 1;
                      return RepaintBoundary(
                        child: LinearProgressIndicator(value: pos / dur, backgroundColor: Colors.grey.withOpacity(0.3), valueColor: AlwaysStoppedAnimation(effectiveAccent), minHeight: 3 * scale),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 32 * scale,
              height: 32 * scale,
              child: Center(child: _buildSourceIcon(current?.source, scale)),
            ),
            SizedBox(width: 8 * scale),
            SizedBox(
              width: 32 * scale,
              height: 32 * scale,
              child: GestureDetector(
                onTapDown: (_) => _prevAnimationController.forward(),
                onTapUp: (_) => _prevAnimationController.reverse(),
                onTapCancel: () => _prevAnimationController.reverse(),
                onTap: _prevTrack,
                child: Center(child: ScaleTransition(scale: _prevAnimation, child: HoverScale(child: Icon(Icons.skip_previous_rounded, color: effectiveAccent, size: 28 * scale)))),
              ),
            ),
            SizedBox(width: 8 * scale),
            SizedBox(
              width: 32 * scale,
              height: 32 * scale,
              child: GestureDetector(
                onTapDown: (_) => _pauseAnimationController.forward(),
                onTapUp: (_) => _pauseAnimationController.reverse(),
                onTapCancel: () => _pauseAnimationController.reverse(),
                onTap: () async {
                  try {
                    if (_playerService.playing) {
                      await _playerService.pause();
                    } else {
                      await _playerService.play();
                    }
                  } catch (e) {
                    debugPrint("Mini-player play/pause error: $e");
                  }
                },
                child: Center(
                  child: ScaleTransition(
                    scale: _pauseAnimation,
                    child: StreamBuilder<PlayerState>(initialData: _playerService.playerState,
                      stream: _playerService.playerStateStream,
                      builder: (_, snap) => HoverScale(child: Icon((snap.data?.playing ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, color: effectiveAccent, size: 28 * scale)),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            SizedBox(
              width: 32 * scale,
              height: 32 * scale,
              child: GestureDetector(
                onTapDown: (_) => _nextAnimationController.forward(),
                onTapUp: (_) => _nextAnimationController.reverse(),
                onTapCancel: () => _nextAnimationController.reverse(),
                onTap: _nextTrack,
                child: Center(child: ScaleTransition(scale: _nextAnimation, child: HoverScale(child: Icon(Icons.skip_next_rounded, color: effectiveAccent, size: 28 * scale)))),
              ),
            ),
            SizedBox(width: 8 * scale),
            SizedBox(
              width: 32 * scale,
              height: 32 * scale,
              child: GestureDetector(
                onTapDown: (_) => _likeAnimationController.forward(),
                onTapUp: (_) => _likeAnimationController.reverse(),
                onTapCancel: () => _likeAnimationController.reverse(),
                onTap: _toggleLike,
                child: Center(child: ScaleTransition(scale: _likeAnimation, child: HoverScale(child: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: effectiveAccent, size: 24 * scale)))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSubHeader(String title, IconData icon, double scale) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(24 * scale, 16 * scale, 24 * scale, 8 * scale),
      child: Row(
        children: [
          Icon(icon, size: 18 * scale, color: effectiveAccent.withOpacity(0.7)),
          SizedBox(width: 12 * scale),
          Text(
            title.toUpperCase(),
            style: s(TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2 * scale,
              color: Colors.grey.shade500,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSubSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required double scale,
    required bool isDark,
    required String sectionKey,
    required bool glassEnabled,
  }) {
    final isExpanded = _expandedSections[sectionKey] ?? false;
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 12 * scale),
      child: _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: BorderRadius.circular(22 * scale),
        scale: scale,
        customOpacity: isDark ? 0.08 : 0.15,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expandedSections[sectionKey] = !isExpanded),
              borderRadius: BorderRadius.circular(22 * scale),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 16 * scale),
                child: Row(
                  children: [
                    Icon(icon, size: 20 * scale, color: effectiveAccent.withOpacity(0.8)),
                    SizedBox(width: 16 * scale),
                    Expanded(
                      child: Text(
                        title,
                        style: s(TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 22 * scale),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: isExpanded
                  ? Column(
                      key: ValueKey('${sectionKey}_content'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), indent: 20 * scale, endIndent: 20 * scale),
                        ...children,
                        SizedBox(height: 12 * scale),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool glassEnabled,
    required bool isDark,
    required double scale,
    required String sectionKey,
  }) {
    final isExpanded = _expandedSections[sectionKey] ?? false;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

    return Padding(
      padding: EdgeInsets.only(bottom: 12 * scale),
      child: _buildGlassContainer(
        glassEnabled: glassEnabled,
        isDark: isDark,
        borderRadius: BorderRadius.circular(28 * scale),
        scale: scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expandedSections[sectionKey] = !isExpanded),
              borderRadius: BorderRadius.circular(28 * scale),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 20 * scale),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10 * scale),
                      decoration: BoxDecoration(
                        color: effectiveAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16 * scale),
                      ),
                      child: Icon(icon, color: effectiveAccent, size: 24 * scale),
                    ),
                    SizedBox(width: 18 * scale),
                    Expanded(
                      child: Text(
                        title,
                        style: s(TextStyle(
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4 * scale,
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(Icons.expand_more_rounded, color: Colors.grey.shade500, size: 24 * scale),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: _isFrozen ? Duration.zero : const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isExpanded
                  ? Column(
                      key: ValueKey('${sectionKey}_content'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1 * scale, thickness: 0.6 * scale, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), indent: 24 * scale, endIndent: 24 * scale),
                        ...children,
                        SizedBox(height: 12 * scale),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsReference(double scale, bool isDark, AppLocalizations loc) {
    final Map<String, String> shortcuts = {
      'Space / K': loc.shortcutSpace,
      'N / P': loc.shortcutNextPrev,
      'J / L': loc.shortcutSeek,
      'Arrow Left / Right': loc.shortcutTabs,
      'Arrow Up / Down': loc.shortcutLists,
      'Enter': loc.shortcutEnter,
      'T': loc.shortcutLyrics,
      'R': loc.shortcutRepeat,
      'A': loc.shortcutArtist,
      'G': loc.shortcutLike,
      'H': loc.shortcutPlaylist,
      'S': loc.shortcutSearch,
      'M': loc.shortcutMute,
      'F11': loc.shortcutFullscreen,
      ', / .': loc.shortcutVolume,
      '1, 2, 3, 4': loc.shortcutDigits,
      'Escape': loc.shortcutEscape,
    };

    return Column(
      children: shortcuts.entries.map((e) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Text(e.key, style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
            SizedBox(width: 16 * scale),
            Expanded(child: Text(e.value, style: TextStyle(fontSize: 14 * scale))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _settingsTile({required IconData icon, required String title, String? subtitle, Widget? trailing, Color? titleColor, VoidCallback? onTap, required double scale}) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return HoverScale(
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
        leading: Icon(icon, color: effectiveAccent, size: 24 * scale),
        title: Text(title, style: s(TextStyle(fontSize: 17 * scale, color: titleColor, fontWeight: FontWeight.w500))),
        subtitle: subtitle != null ? Text(subtitle, style: s(TextStyle(fontSize: 13.5 * scale))) : null,
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, size: 24 * scale),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    required double scale,
    required bool isDark,
    required bool glassEnabled,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 16 * scale),
      child: HoverScale(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(24 * scale),
            scale: scale,
            child: Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12 * scale),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16 * scale),
                    ),
                    child: Icon(icon, color: color, size: 24 * scale),
                  ),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: s(TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          )),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          subtitle,
                          style: s(TextStyle(
                            fontSize: 12 * scale,
                            color: isDark ? Colors.white54 : Colors.black54,
                          )),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14 * scale, color: isDark ? Colors.white24 : Colors.black26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab(AppLocalizations loc, bool glassEnabled, bool isDark, double scale) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    return SmoothScrollWrapper(
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 20 * scale),
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExpandableSection(
                title: loc.integrationsTitle,
                icon: Icons.api_rounded,
                children: [
                  _buildApiKeysSelector(scale, isDark, glassEnabled, loc),
                  _buildDiscordRPCSelector(scale),
                ],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'integrations',
              ),
              _buildExpandableSection(
                title: loc.appearance,
                icon: Icons.palette_rounded,
                children: [
                  _buildSettingsSubSection(
                    title: loc.interfaceSection,
                    icon: Icons.layers_rounded,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                    sectionKey: 'sub_interface',
                    children: [
                      _buildUiModeSelector(scale),
                      _buildThemeSelector(scale),
                      _buildColorSelector(scale),
                      _buildFontSelector(scale),
                      _buildScaleSelector(scale),
                    ],
                  ),
                  _buildSettingsSubSection(
                    title: loc.effectsSection,
                    icon: Icons.auto_fix_high_rounded,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                    sectionKey: 'sub_effects',
                    children: [
                      _buildGlassSelector(scale),
                      _buildBorderSettings(scale),
                      _buildTitleBarSettings(scale),
                    ],
                  ),
                  _buildSettingsSubSection(
                    title: loc.personalizationSection,
                    icon: Icons.auto_awesome_rounded,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                    sectionKey: 'sub_personalization',
                    children: [
                      _buildCustomBackgroundSelector(scale),
                      _buildImageFiltersSettings(scale),
                      _buildCustomTrackCoverSelector(scale),
                    ],
                  ),
                  _buildSettingsSubSection(
                    title: loc.playerSection,
                    icon: Icons.music_note_rounded,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                    sectionKey: 'sub_player',
                    children: [
                      _buildPlayerSliderStyleSelector(scale),
                      _buildV2FloatingSelector(scale),
                      _buildCoverEffectSelector(scale),
                    ],
                  ),
                  _buildSettingsSubSection(
                    title: loc.performanceSection,
                    icon: Icons.speed_rounded,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                    sectionKey: 'sub_performance',
                    children: [
                      _buildFreezeOptimizationSelector(scale),
                      _buildMinimizeToTraySelector(scale),
                    ],
                  ),
                ],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'appearance',
              ),
              _buildExpandableSection(
                title: loc.handbook,
                icon: Icons.menu_book_rounded,
                children: [_buildShortcutsReference(scale, isDark, loc)],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'shortcuts',
              ),
              _buildExpandableSection(
                title: loc.languageSection,
                icon: Icons.translate_rounded,
                children: [_buildLanguageSelector(scale)],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'language',
              ),
              _buildExpandableSection(
                title: loc.telemetrySection,
                icon: Icons.analytics_rounded,
                children: [_buildTelemetrySelector(scale)],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'telemetry',
              ),
              _buildExpandableSection(
                title: loc.dataAndAccount,
                icon: Icons.person_rounded,
                children: [
                  _buildActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: loc.clearCache,
                    subtitle: loc.clearCacheSubtitle,
                    onTap: _clearCache,
                    color: Colors.orangeAccent,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                  ),
                  _buildActionTile(
                    icon: Icons.logout_rounded,
                    title: loc.logout,
                    subtitle: loc.logoutSubtitle,
                    onTap: _logout,
                    color: Colors.redAccent,
                    scale: scale,
                    isDark: isDark,
                    glassEnabled: glassEnabled,
                  ),
                ],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'account',
              ),
              _buildExpandableSection(
                title: loc.aboutSection,
                icon: Icons.info_outline_rounded,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20 * scale),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: WavePainter(
                                  _waveController.value,
                                  color: effectiveAccent,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: WavePainter(
                                  _waveController.value * 2.0,
                                  thin: true,
                                  color: effectiveAccent,
                                ),
                              );
                            },
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32 * scale),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'lizaplayer',
                                  style: s(TextStyle(
                                    fontSize: 24 * scale,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0 * scale,
                                    color: isDark ? Colors.white : Colors.black87,
                                    shadows: [
                                      Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10 * scale, offset: const Offset(0, 2)),
                                    ],
                                  )),                                ),
                                SizedBox(height: 6 * scale),
                                _buildBadge('v2.4.0', Colors.grey, scale),
                                SizedBox(height: 32 * scale),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSocialButton(
                                      icon: FontAwesomeIcons.github,
                                      label: 'GitHub',
                                      onTap: () => _launchURL('https://github.com/lizapropanol/lizaplayer'),
                                      scale: scale,
                                      isDark: isDark,
                                      glassEnabled: glassEnabled,
                                    ),
                                    SizedBox(width: 16 * scale),
                                    _buildSocialButton(
                                      icon: FontAwesomeIcons.telegram,
                                      label: 'Telegram',
                                      onTap: () => _launchURL('https://t.me/lizapropanol'),
                                      scale: scale,
                                      isDark: isDark,
                                      glassEnabled: glassEnabled,
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
                ],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'about',
              ),
            ],          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation(AppLocalizations loc, double scale) {
    return Center(
      child: RotatingLogo(size: 140 * scale),
    );
  }

  Widget _buildMainContent(AppLocalizations loc, bool isDark) {
    final current = _playerService.currentTrack;

    return Consumer(
      builder: (context, ref, child) {
        final glassEnabled = ref.watch(glassEnabledProvider);
        final blurEnabled = ref.watch(blurEnabledProvider);
        final scale = ref.watch(scaleProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
        
        final titleBarEnabled = ref.watch(customTitleBarEnabledProvider);
        final topPadding = titleBarEnabled && !_isFullScreen ? 30.0 : 0.0;

        Widget mainContentBody = Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Column(
            children: [
              AnimatedSlide(
              offset: _showLaunchAnimations ? Offset.zero : const Offset(0, -1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showLaunchAnimations ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1200),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 10 * scale),
                  child: _buildGlassContainer(
                    glassEnabled: glassEnabled,
                    isDark: isDark,
                    borderRadius: BorderRadius.circular(50 * scale),
                    scale: scale,
                    child: Padding(
                      padding: EdgeInsets.all(6 * scale),
                      child: TabBar(
                        controller: _tabController,
                        dividerHeight: 0,
                        indicatorPadding: EdgeInsets.zero,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: glassEnabled
                          ? BoxDecoration(
                              color: effectiveAccent.withOpacity(isDark ? 0.2 : 0.25),
                              borderRadius: BorderRadius.circular(46 * scale),
                              border: Border.all(color: Colors.white.withOpacity(isDark ? 0.2 : 0.4), width: 1.5 * scale),
                            )
                          : BoxDecoration(
                              color: effectiveAccent, 
                              borderRadius: BorderRadius.circular(46 * scale),
                            ),
                        overlayColor: MaterialStateProperty.all(Colors.transparent),
                        labelColor: glassEnabled ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.black : Colors.white),
                        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                        labelStyle: s(TextStyle(fontWeight: FontWeight.w600, fontSize: 15 * scale)),
                        tabs: [Tab(text: loc.home), Tab(text: loc.myWave), Tab(text: loc.playlists), Tab(text: loc.settings)],                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: ListenableBuilder(
                  listenable: _tabController,
                  builder: (context, _) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: _buildCurrentTab(current, glassEnabled, scale, loc, isDark),
                    );
                  },
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: _isFrozen ? Duration.zero : const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: 1.0,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              child: (_showMiniPlayer && current != null)
                ? Padding(
                    key: const ValueKey('miniplayer'),
                    padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 20 * scale),
                    child: _buildMiniPlayer(current, glassEnabled, scale)
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
        ),
        );

        return RepaintBoundary(
          child: Stack(
            children: [
              Positioned.fill(
                child: Consumer(
                  builder: (context, ref, _) {
                    final applyAll = ref.watch(applyFilterToAllProvider);
                    final hue = ref.watch(hueShiftProvider);
                    final sat = ref.watch(saturationProvider);
                    final con = ref.watch(contrastProvider);
                    final bri = ref.watch(brightnessProvider);
                    final grey = ref.watch(grayscaleProvider);
                    final pix = ref.watch(pixelationProvider);

                    Widget img = _FreezableImage(
                      url: _customBackgroundUrl,
                      path: _customBackgroundPath,
                      isFrozen: _isFrozen,
                      scale: scale,
                      pixelation: pix,
                    );

                    if (applyAll) return img;

                    var matrix = _matrixIdentity();
                    if (grey > 0) matrix = _matrixConcat(matrix, _matrixGrayscale(grey));
                    if (hue != 0) matrix = _matrixConcat(matrix, _matrixHue(hue));
                    if (sat != 1.0) matrix = _matrixConcat(matrix, _matrixSaturation(sat));
                    if (con != 1.0) matrix = _matrixConcat(matrix, _matrixContrast(con));
                    if (bri != 1.0) matrix = _matrixConcat(matrix, _matrixBrightness(bri));

                    return ColorFiltered(
                      colorFilter: ColorFilter.matrix(matrix),
                      child: img,
                    );
                  },
                ),
              ),

              if (blurEnabled) Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _isFrozen ? 0.0 : 10.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    if (value == 0 && _isFrozen) return const SizedBox.shrink();
                    return BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
                      child: const SizedBox(),
                    );
                  },
                ),
              ),
              mainContentBody,
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentTab(dynamic current, bool glassEnabled, double scale, AppLocalizations loc, bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    
    switch (_tabController.index) {
      case 0:
        if (ref.watch(uiModeProvider) == 'v2') {
          return Padding(
            key: const ValueKey('v2_player_tab'),
            padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 20 * scale),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: AnimatedSlide(
                        offset: _showLaunchAnimations ? Offset.zero : const Offset(-1.0, 0),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _showLaunchAnimations ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 1400),
                          child: _buildV2PlayerView(current, glassEnabled, scale),
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    Expanded(
                      flex: 1,
                      child: AnimatedSlide(
                        offset: _showLaunchAnimations ? Offset.zero : const Offset(1.0, 0),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _showLaunchAnimations ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 1400),
                          child: _buildQueuePanel(glassEnabled, scale, isBottom: true),
                        ),
                      ),
                    ),
                    SizedBox(height: 84 * scale),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: _showLaunchAnimations ? Offset.zero : const Offset(0, 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _showLaunchAnimations ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 1200),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        height: _isSearchOpen ? 500 * scale : 68 * scale,
                        child: _buildGlassContainer(
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          borderRadius: BorderRadius.circular(32 * scale),
                          scale: scale,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: _isSearchOpen ? 1.0 : 0.0,
                                  child: IgnorePointer(
                                    ignoring: !_isSearchOpen,
                                    child: _buildV2SearchResultsContent(glassEnabled, isDark, scale, loc, effectiveAccent),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  SizedBox(width: 18 * scale),
                                  Icon(Icons.search_rounded, color: isDark ? Colors.grey : Colors.grey, size: 24 * scale),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16.5 * scale),
                                      cursorColor: effectiveAccent,
                                      decoration: InputDecoration(hintText: loc.searchTracks, hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey, fontSize: 16.5 * scale), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 17 * scale)),
                                      onChanged: (_) => _searchTracks(),
                                      onSubmitted: (_) => _searchTracks(),
                                    ),
                                  ),
                                  if (_isSearchOpen) IconButton(
                                    onPressed: () => setState(() { _isSearchOpen = false; _searchController.clear(); }),
                                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          key: const ValueKey(0),
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ExcludeFocus(
                      child: AnimatedSlide(
                        offset: _showLaunchAnimations ? Offset.zero : const Offset(-1.0, 0),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _showLaunchAnimations ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 1400),
                          child: _buildMainPlayerArea(current, glassEnabled, scale),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 20 * scale),
                    child: SizedBox(
                      width: 480 * scale,
                      child: FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: AnimatedSlide(
                          offset: _showLaunchAnimations ? Offset.zero : const Offset(1.0, 0),
                          duration: const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _showLaunchAnimations ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 1400),
                            child: _buildQueuePanel(glassEnabled, scale),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSlide(
              offset: _showLaunchAnimations ? Offset.zero : const Offset(0, 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showLaunchAnimations ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1200),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 20 * scale),
                  child: _buildGlassContainer(
                    glassEnabled: glassEnabled,
                    isDark: isDark,
                    borderRadius: BorderRadius.circular(30 * scale),
                    scale: scale,
                    child: Row(
                      children: [
                        SizedBox(width: 18 * scale),
                        Icon(Icons.search_rounded, color: isDark ? Colors.grey : Colors.grey, size: 24 * scale),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16.5 * scale),
                            cursorColor: effectiveAccent,
                            decoration: InputDecoration(hintText: loc.searchTracks, hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey, fontSize: 16.5 * scale), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 17 * scale)),
                            onChanged: (val) {
                              if (val.trim().isEmpty) {
                                if (_isSearchOpen) {
                                  setState(() {
                                    _isSearchOpen = false;
                                    _searchResultsTracks = [];
                                    _searchResultsArtists = [];
                                    _searchResultsAlbums = [];
                                  });
                                }
                              }
                            },
                            onSubmitted: (_) => _searchTracks(),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: 8 * scale),
                          child: HoverScale(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20 * scale),
                              onTap: () => _searchTracks(),
                              child: _buildGlassContainer(
                                glassEnabled: glassEnabled,
                                isDark: isDark,
                                borderRadius: BorderRadius.circular(20 * scale),
                                scale: scale,
                                customOpacity: isDark ? 0.15 : 0.3,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                                  child: Text(
                                    loc.find,
                                    style: TextStyle(
                                      color: effectiveAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15 * scale,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 4 * scale),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 1:
        return KeyedSubtree(key: const ValueKey(1), child: _buildMyWaveTab(glassEnabled, scale));
      case 2:
        return KeyedSubtree(key: const ValueKey(2), child: _buildPlaylistsTab(glassEnabled, scale));
      case 3:
        return KeyedSubtree(key: const ValueKey(3), child: _buildSettingsTab(loc, glassEnabled, isDark, scale));
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _startWaveFromTrack(AppTrack track) async {
    await _startMyWave(seedTrack: track);
  }

  Future<void> _startWaveFromPlaylist(List<AppTrack> tracks) async {
    if (tracks.isEmpty) return;
    final loc = AppLocalizations.of(context)!;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final seedTrack = tracks[Random().nextInt(tracks.length)];
      List<AppTrack> newTracks = List.from(tracks); newTracks.shuffle();
      if (seedTrack.source == AudioSourceType.yandex && _yandexClient != null) {
        final similar = await _yandexClient!.tracks.getSimilar(seedTrack.id);
        newTracks.addAll(similar.map((t) => AppTrack.fromYandex(t)));
      } else if (seedTrack.source == AudioSourceType.soundcloud && _soundcloudClientId != null) {
        final url = Uri.parse('https://api-v2.soundcloud.com/tracks/${seedTrack.id}/related?client_id=${_soundcloudClientId}&limit=50');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['collection'] != null) {
            newTracks.addAll((data['collection'] as List)
                .where((item) => item['kind'] == 'track' || item['stream_url'] != null)
                .map((item) => AppTrack.fromSoundcloud(item as Map<String, dynamic>))
                .where((t) => t.streamUrl != null));
          }
        }
      }
      if (mounted) Navigator.pop(context);
      setState(() { waveTracks = newTracks; _isWaveActive = true; _waveSource = seedTrack.source == AudioSourceType.yandex ? 'yandex' : 'soundcloud'; });
      _playFromList(waveTracks, 0);
    } catch (e) { if (mounted) Navigator.pop(context); debugPrint("Error starting wave from playlist: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Focus(
      focusNode: _globalFocusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          final focused = FocusManager.instance.primaryFocus;
          final isTextFieldFocused = focused?.context?.widget is EditableText || 
                                     focused?.context?.findAncestorWidgetOfExactType<TextField>() != null;
          final key = event.logicalKey;

          if (isTextFieldFocused) {
            if (key == LogicalKeyboardKey.escape) {
              _handleEscape();
              focused?.unfocus();
              _globalFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }

          if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
            _togglePlayback();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyJ) {
            _seekRelative(const Duration(seconds: -10));
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyL) {
            _seekRelative(const Duration(seconds: 10));
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            _tabController.animateTo((_tabController.index - 1).clamp(0, 3));
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            _tabController.animateTo((_tabController.index + 1).clamp(0, 3));
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (focused == node) {
              node.nextFocus();
            } else {
              FocusManager.instance.primaryFocus?.focusInDirection(TraversalDirection.down);
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            FocusManager.instance.primaryFocus?.focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.escape) {
            _handleEscape();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.digit1) {
            _tabController.animateTo(0);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.digit2) {
            _tabController.animateTo(1);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.digit3) {
            _tabController.animateTo(2);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.digit4) {
            _tabController.animateTo(3);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyM) {
            _toggleMute();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.f11) {
            _toggleFullScreen();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyS) {
            _focusSearch();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyN) {
            _nextTrack();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyP) {
            _prevTrack();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyT) {
            _toggleLyrics();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyR) {
            _toggleRepeat();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyA) {
            _openArtistDetails();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyH) {
            _addToPlaylist();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyG) {
            _toggleLike();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.comma) {
            final newVol = (_playerService.volume - 0.05).clamp(0.0, 1.0);
            _playerService.setVolume(newVol);
            TokenStorage.saveVolume(newVol);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.period) {
            final newVol = (_playerService.volume + 0.05).clamp(0.0, 1.0);
            _playerService.setVolume(newVol);
            TokenStorage.saveVolume(newVol);
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.enter && _tabController.index == 1) {
            _startMyWave();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          _globalFocusNode.requestFocus();
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
        body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child));
                },
                child: _isInitialized ? Container(key: const ValueKey('home_main_content'), child: _buildMainContent(loc, isDark)) : Consumer(builder: (context, ref, child) => _buildLoadingAnimation(loc, ref.watch(scaleProvider))),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomTitleBar(isFullScreen: _isFullScreen),
          ),
        ],
        ),    ),
    ),
    );
  }

  List<double> _matrixIdentity() => [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  List<double> _matrixConcat(List<double> m1, List<double> m2) {
    final result = List<double>.filled(20, 0.0);
    for (int y = 0; y < 4; y++) {
      for (int x = 0; x < 5; x++) {
        double v = 0;
        for (int i = 0; i < 4; i++) {
          v += m1[y * 5 + i] * m2[i * 5 + x];
        }
        if (x == 4) v += m1[y * 5 + 4];
        result[y * 5 + x] = v;
      }
    }
    return result;
  }

  List<double> _matrixGrayscale(double v) {
    final r = 0.2126 + 0.7874 * (1 - v);
    final g = 0.7152 - 0.7152 * (1 - v);
    final b = 0.0722 - 0.0722 * (1 - v);
    final r2 = 0.2126 - 0.2126 * (1 - v);
    final g2 = 0.7152 + 0.2848 * (1 - v);
    final b2 = 0.0722 - 0.0722 * (1 - v);
    final r3 = 0.2126 - 0.2126 * (1 - v);
    final g3 = 0.7152 - 0.7152 * (1 - v);
    final b3 = 0.0722 + 0.9278 * (1 - v);
    return [
      r, g, b, 0, 0,
      r2, g2, b2, 0, 0,
      r3, g3, b3, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _matrixHue(double rotation) {
    final cosVal = cos(rotation);
    final sinVal = sin(rotation);
    final lumR = 0.213;
    final lumG = 0.715;
    final lumB = 0.072;
    return [
      lumR + cosVal * (1 - lumR) + sinVal * (-lumR), lumG + cosVal * (-lumG) + sinVal * (-lumG), lumB + cosVal * (-lumB) + sinVal * (1 - lumB), 0, 0,
      lumR + cosVal * (-lumR) + sinVal * (0.143), lumG + cosVal * (1 - lumG) + sinVal * (0.140), lumB + cosVal * (-lumB) + sinVal * (-0.283), 0, 0,
      lumR + cosVal * (-lumR) + sinVal * (-(1 - lumR)), lumG + cosVal * (-lumG) + sinVal * (lumG), lumB + cosVal * (1 - lumB) + sinVal * (lumB), 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _matrixSaturation(double s) => [
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0,
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0,
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0,
    0, 0, 0, 1, 0,
  ];

  List<double> _matrixContrast(double c) {
    final t = (1.0 - c) / 2.0;
    return [
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _matrixBrightness(double b) => [
    b, 0, 0, 0, 0,
    0, b, 0, 0, 0,
    0, 0, b, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  void onWindowBlur() {
    final optimizationEnabled = ref.read(freezeOptimizationProvider);
    if (optimizationEnabled) {
      if (mounted) {
        setState(() => _isFrozen = true);
        ref.read(isFrozenProvider.notifier).state = true;
        _waveController.stop();
        _pauseAnimationController.stop();
        _prevAnimationController.stop();
        _nextAnimationController.stop();
        _likeAnimationController.stop();
        _listLikeAnimationController.stop();
      }
    }
  }

  @override
  void onWindowFocus() {
    if (_isFrozen) {
      if (mounted) {
        setState(() => _isFrozen = false);
        ref.read(isFrozenProvider.notifier).state = false;
        _waveController.repeat();
      }
    }
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() => _isFullScreen = false);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    windowManager.removeListener(this);
    _globalFocusNode.dispose();
    _searchFocusNode.dispose();
    _pauseAnimationController.dispose();
    _prevAnimationController.dispose();
    _nextAnimationController.dispose();
    _likeAnimationController.dispose();
    _listLikeAnimationController.dispose();
    _waveController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _yandexTokenController.dispose();
    _soundcloudIdController.dispose();
    _playerStateSubscription?.cancel();
    _playerIndexSubscription?.cancel();
    super.dispose();
  }
}

class SyncedLyricsView extends ConsumerStatefulWidget {
  final List<LyricLine> lyrics;
  final Stream<Duration> playerStream;
  final bool isDark;
  final double scale;
  final Color accentColor;
  final bool hasSyncedTime;
  final bool isFrozen;

  const SyncedLyricsView({
    super.key,
    required this.lyrics,
    required this.playerStream,
    required this.isDark,
    required this.scale,
    required this.accentColor,
    required this.hasSyncedTime,
    required this.isFrozen,
  });

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView> with SingleTickerProviderStateMixin, FontStyler {
  final ScrollController _scrollController = ScrollController();
  final PlayerService _playerService = PlayerService();
  int _activeIndex = 0;
  final Map<int, GlobalKey> _lineKeys = {};
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _getKey(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!widget.hasSyncedTime) {
      content = SmoothScrollWrapper(
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40 * widget.scale),
            child: Text(
              widget.lyrics.map((e) => e.text).join('\n'),
              style: s(TextStyle(
                fontSize: 19 * widget.scale,
                height: 1.8,
                color: widget.isDark ? Colors.white.withOpacity(0.9) : Colors.black87.withOpacity(0.9),
              )),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      content = StreamBuilder<Duration>(initialData: _playerService.position,
        stream: widget.isFrozen 
          ? widget.playerStream.distinct((a, b) => a.inSeconds == b.inSeconds)
          : widget.playerStream,
        builder: (context, snapshot) {
          final currentPos = snapshot.data ?? Duration.zero;
          int newIndex = 0;
          for (int i = 0; i < widget.lyrics.length; i++) {
            if (currentPos >= widget.lyrics[i].time) {
              newIndex = i;
            } else {
              break;
            }
          }

          if (newIndex != _activeIndex) {
            _activeIndex = newIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final ctx = _getKey(_activeIndex).currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    duration: widget.isFrozen ? Duration.zero : const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    alignment: 0.5,
                  );
                }
              }
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                    stops: const [0.0, 0.1, 0.9, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: constraints.maxHeight / 2),
                  child: Column(
                    children: List.generate(widget.lyrics.length, (i) {
                      final isCurrent = i == _activeIndex;
                      return GestureDetector(
                        onTap: () => _playerService.seek(widget.lyrics[i].time),
                        child: Padding(
                          key: _getKey(i),
                          padding: EdgeInsets.symmetric(
                            vertical: 16.0 * widget.scale,
                            horizontal: 24 * widget.scale,
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: isCurrent ? 1.0 : 0.25,
                            child: AnimatedScale(
                              scale: isCurrent ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                textAlign: TextAlign.center,
                                style: s(TextStyle(
                                  fontSize: 23 * widget.scale,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                  color: widget.accentColor,
                                  letterSpacing: -0.3,
                                )),
                                child: Text(widget.lyrics[i].text),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            }
          );
        },
      );
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: content,
      ),
    );
  }
}

class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const HoverScale({Key? key, required this.child, this.scale = 1.03}) : super(key: key);
  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: (_isHovered || _isFocused) ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class FadeSlideEntrance extends ConsumerStatefulWidget {
  final Widget child;
  final int index;
  const FadeSlideEntrance({Key? key, required this.child, required this.index}) : super(key: key);
  @override
  ConsumerState<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends ConsumerState<FadeSlideEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    
    _scheduleAnimation();
  }

  void _scheduleAnimation() {
    if (_started) return;
    
    final isFrozen = ref.read(isFrozenProvider);
    if (isFrozen) {
      _controller.value = 1.0;
      _started = true;
      return;
    }

    Future.delayed(Duration(milliseconds: (widget.index * 40).clamp(0, 400)), () {
      if (!mounted || _started) return;
      
      if (ref.read(isFrozenProvider)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
      _started = true;
    });
  }

  @override
  void didUpdateWidget(FadeSlideEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_started) _scheduleAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = ref.watch(isFrozenProvider);
    
    if (isFrozen && !_started) {
      _controller.value = 1.0;
      _started = true;
    }

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: widget.child,
      ),
    );
  }
}

class ClickableArtistsText extends StatefulWidget {
  final String artistName;
  final List? originalArtistData;
  final double fontSize;
  final Color color;
  final void Function(dynamic) onArtistTap;
  final TextAlign textAlign;

  const ClickableArtistsText({
    super.key,
    required this.artistName,
    this.originalArtistData,
    required this.fontSize,
    required this.color,
    required this.onArtistTap,
    this.textAlign = TextAlign.start,
  });

  @override
  State<ClickableArtistsText> createState() => _ClickableArtistsTextState();
}

class _ClickableArtistsTextState extends State<ClickableArtistsText> {
  List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _initRecognizers();
  }

  @override
  void didUpdateWidget(ClickableArtistsText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artistName != oldWidget.artistName || widget.originalArtistData != oldWidget.originalArtistData) {
      _disposeRecognizers();
      _initRecognizers();
    }
  }

  void _initRecognizers() {
    _recognizers = [];
    if (widget.originalArtistData != null && widget.originalArtistData!.isNotEmpty) {
      for (var artist in widget.originalArtistData!) {
        final recognizer = TapGestureRecognizer()..onTap = () {
          widget.onArtistTap(artist);
        };
        _recognizers.add(recognizer);
      }
    } else if (widget.artistName.isNotEmpty) {
      final recognizer = TapGestureRecognizer()..onTap = () {
        widget.onArtistTap({'username': widget.artistName});
      };
      _recognizers.add(recognizer);
    }
  }

  void _disposeRecognizers() {
    for (var r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.originalArtistData == null || widget.originalArtistData!.isEmpty) {
      return Text.rich(
        TextSpan(
          text: widget.artistName,
          style: TextStyle(fontSize: widget.fontSize, color: widget.color),
          recognizer: _recognizers.isNotEmpty ? _recognizers[0] : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: widget.textAlign,
      );
    }

    final List<InlineSpan> spans = [];
    for (int i = 0; i < widget.originalArtistData!.length; i++) {
      final artist = widget.originalArtistData![i];
      String name = '';
      if (artist is Map) {
        name = artist['username']?.toString() ?? artist['title']?.toString() ?? '';
      } else {
        try {
          name = (artist as dynamic).title ?? (artist as dynamic).name ?? '';
        } catch (_) {}
      }
      spans.add(
        TextSpan(
          text: name,
          style: TextStyle(fontSize: widget.fontSize, color: widget.color),
          recognizer: _recognizers.length > i ? _recognizers[i] : null,
        ),
      );
      if (i < widget.originalArtistData!.length - 1) {
        spans.add(TextSpan(text: ', ', style: TextStyle(fontSize: widget.fontSize, color: widget.color)));
      }
    }
    return Text.rich(TextSpan(children: spans), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: widget.textAlign);
  }
}

class SmoothScrollWrapper extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final ScrollController? controller;
  const SmoothScrollWrapper({super.key, required this.builder, this.controller});
  @override
  ConsumerState<SmoothScrollWrapper> createState() => _SmoothScrollWrapperState();
}

class _SmoothScrollWrapperState extends ConsumerState<SmoothScrollWrapper> with SingleTickerProviderStateMixin {
  late ScrollController _controller;
  double _targetPixels = 0;
  double _currentPixels = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animController.addListener(_updateScroll);
    _controller.addListener(_handleManualScroll);
  }

  void _handleManualScroll() {
    if (!_animController.isAnimating && _controller.hasClients) {
      _currentPixels = _controller.position.pixels;
      _targetPixels = _currentPixels;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.removeListener(_handleManualScroll);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (!_controller.hasClients) return;
      
      if (!_animController.isAnimating) {
        _currentPixels = _controller.position.pixels;
        _targetPixels = _currentPixels;
        _animController.repeat();
      }
      
      final delta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
      _targetPixels = (_targetPixels + delta).clamp(
        _controller.position.minScrollExtent, 
        _controller.position.maxScrollExtent
      );
    }
  }

  void _updateScroll() {
    if (!_controller.hasClients) return;

    final diff = _targetPixels - _currentPixels;
    if (diff.abs() < 0.5) {
      _currentPixels = _targetPixels;
      _controller.jumpTo(_targetPixels);
      _animController.stop();
      return;
    }

    _currentPixels += diff * 0.12;
    _controller.jumpTo(_currentPixels);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handleScroll,
      child: widget.builder(context, _controller),
    );
  }
}

class _TrackTileLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final double scale;
  final Color accentColor;

  const _TrackTileLikeButton({
    required this.isLiked,
    required this.onTap,
    required this.scale,
    required this.accentColor,
  });

  @override
  State<_TrackTileLikeButton> createState() => _TrackTileLikeButtonState();
}

class _TrackTileLikeButtonState extends State<_TrackTileLikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _animation,
        child: HoverScale(
          child: Icon(
            widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: widget.isLiked ? widget.accentColor : Colors.grey,
            size: 20 * widget.scale,
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animation;
  final bool thin;
  final Color color;

  WavePainter(this.animation, {this.thin = false, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(thin ? 0.08 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thin ? 1.5 : 2.5;

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final baseY = size.height * (0.15 + i * 0.18);

      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width + 20; x += 10) {
        final wave = sin((x / 60) + animation * (2 * pi) + i * 1.5) * (thin ? 12 : 24);
        path.lineTo(x, baseY + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FreezableImage extends StatefulWidget {
  final String? url;
  final String? path;
  final bool isFrozen;
  final double scale;
  final BoxFit fit;
  final double pixelation;

  const _FreezableImage({
    this.url,
    this.path,
    required this.isFrozen,
    required this.scale,
    this.fit = BoxFit.cover,
    this.pixelation = 0.0,
  });

  @override
  _FreezableImageState createState() => _FreezableImageState();
}

class _FreezableImageState extends State<_FreezableImage> {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  bool _showImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateImage();
  }

  @override
  void didUpdateWidget(_FreezableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.path != oldWidget.path || (oldWidget.isFrozen && !widget.isFrozen)) {
      if (widget.url == null && widget.path == null) {
        if (mounted) setState(() => _showImage = false);
      } else {
        _updateImage();
      }
    }
  }

  void _updateImage() {
    _imageStream?.removeListener(ImageStreamListener(_onImage));
    
    final provider = widget.path != null && widget.path!.isNotEmpty
        ? FileImage(File(widget.path!)) 
        : (widget.url != null && widget.url!.isNotEmpty ? CachedNetworkImageProvider(widget.url!) as ImageProvider : null);
    
    if (provider == null) {
      if (mounted) setState(() { _showImage = false; });
      return;
    }

    _imageStream = provider.resolve(createLocalImageConfiguration(context));
    _imageStream!.addListener(ImageStreamListener(_onImage));
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (mounted) {
      setState(() {
        _imageInfo = info;
        if (synchronousCall) {
          _showImage = true;
        } else {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) setState(() => _showImage = true);
          });
        }
      });
      if (widget.isFrozen) {
        _imageStream?.removeListener(ImageStreamListener(_onImage));
      }
    }
  }

  @override
  void dispose() {
    _imageStream?.removeListener(ImageStreamListener(_onImage));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _showImage ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeIn,
      onEnd: () {
        if (!_showImage && mounted) {
          setState(() {
            _imageInfo = null;
          });
        }
      },
      child: _imageInfo == null 
        ? Container(color: Colors.transparent)
        : LayoutBuilder(
            builder: (context, constraints) {
              final pix = widget.pixelation;
              if (pix <= 0.0) {
                return RawImage(
                  image: _imageInfo!.image,
                  scale: _imageInfo!.scale,
                  fit: widget.fit,
                );
              }

              final pixelFactor = (1.0 - (pix * 0.95)).clamp(0.05, 1.0);
              return Transform.scale(
                scale: 1.0 / pixelFactor,
                filterQuality: FilterQuality.none,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: pixelFactor,
                    heightFactor: pixelFactor,
                    child: RawImage(
                      image: _imageInfo!.image,
                      scale: _imageInfo!.scale,
                      fit: widget.fit,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _GlassToastWidget extends ConsumerStatefulWidget {
  final String message;
  final bool isError;
  final bool isLoading;
  final double scale;
  final bool isDark;
  final bool glassEnabled;
  final VoidCallback onDismiss;

  const _GlassToastWidget({
    required this.message,
    required this.isError,
    this.isLoading = false,
    required this.scale,
    required this.isDark,
    required this.glassEnabled,
    required this.onDismiss,
  });

  @override
  ConsumerState<_GlassToastWidget> createState() => _GlassToastWidgetState();
}

class _GlassToastWidgetState extends ConsumerState<_GlassToastWidget> with SingleTickerProviderStateMixin, FontStyler {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _controller.forward();
    
    if (!widget.isLoading) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  @override
  void didUpdateWidget(_GlassToastWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40 * widget.scale,
      right: 24 * widget.scale,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16 * widget.scale),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: (widget.isDark ? Colors.black : Colors.white).withOpacity(widget.glassEnabled ? 0.2 : 0.9),
                  borderRadius: BorderRadius.circular(16 * widget.scale),
                  border: Border.all(
                    color: widget.isError ? Colors.redAccent.withOpacity(0.5) : (widget.isDark ? Colors.white12 : Colors.black12),
                    width: 1.5 * widget.scale,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20 * widget.scale, vertical: 12 * widget.scale),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isLoading)
                      SizedBox(
                        width: 18 * widget.scale,
                        height: 18 * widget.scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 2 * widget.scale,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary.opacity == 0 
                              ? (widget.isDark ? Colors.white70 : Colors.black87) 
                              : Theme.of(context).colorScheme.primary
                          ),
                        ),
                      )
                    else
                      Icon(
                        widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: widget.isError 
                          ? Colors.redAccent 
                          : (Theme.of(context).colorScheme.primary.opacity == 0 
                              ? (widget.isDark ? Colors.white70 : Colors.black87) 
                              : Theme.of(context).colorScheme.primary),
                        size: 20 * widget.scale,
                      ),
                    SizedBox(width: 12 * widget.scale),
                    Text(
                      widget.message,
                      style: s(TextStyle(
                        fontSize: 14 * widget.scale,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final List<Color> colors;
  final double animationValue;

  _GradientBorderPainter({
    required this.strokeWidth,
    required this.radius,
    required this.colors,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radiusValue = radius;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radiusValue));
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    paint.shader = SweepGradient(
      colors: [...colors, colors.first],
      transform: GradientRotation(animationValue * 2 * 3.14159265),
    ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) => 
    oldDelegate.animationValue != animationValue || 
    oldDelegate.colors != colors;
}

class _GradientBorderContainer extends ConsumerStatefulWidget {
  final Widget child;
  final double strokeWidth;
  final double radius;
  final List<Color> colors;

  const _GradientBorderContainer({
    required this.child,
    required this.strokeWidth,
    required this.radius,
    required this.colors,
  });

  @override
  _GradientBorderContainerState createState() => _GradientBorderContainerState();
}

class _GradientBorderContainerState extends ConsumerState<_GradientBorderContainer> with SingleTickerProviderStateMixin {
  static double _globalAngle = 0.0;
  static Duration _lastFrameTime = Duration.zero;
  late Ticker _ticker;
  double _currentSpeedMultiplier = 1.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    final isFrozen = ref.read(isFrozenProvider);
    _currentSpeedMultiplier = isFrozen ? 0.0 : 1.0;
    _ticker = createTicker(_onTick);
    if (!isFrozen) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final delta = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    
    if (_currentSpeedMultiplier > 0) {
      if (_lastFrameTime != elapsed) {
        final baseSpeed = ref.read(borderAnimationSpeedProvider);
        _globalAngle = (_globalAngle + delta * _currentSpeedMultiplier * baseSpeed * 0.2) % 1.0;
        _lastFrameTime = elapsed;
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = ref.watch(isFrozenProvider);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.colors[0]),
      duration: const Duration(milliseconds: 300),
      builder: (context, color1, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: widget.colors[1]),
          duration: const Duration(milliseconds: 300),
          builder: (context, color2, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isFrozen ? 0.0 : 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOutCubic,
              builder: (context, speed, child) {
                _currentSpeedMultiplier = speed;
                if (_currentSpeedMultiplier > 0 && !_ticker.isActive) {
                  _ticker.start();
                } else if (_currentSpeedMultiplier <= 0 && _ticker.isActive) {
                  _ticker.stop();
                  _lastElapsed = Duration.zero;
                }
                return CustomPaint(
                  painter: _GradientBorderPainter(
                    strokeWidth: widget.strokeWidth,
                    radius: widget.radius,
                    colors: [color1 ?? widget.colors[0], color2 ?? widget.colors[1]],
                    animationValue: _globalAngle,
                  ),
                  child: widget.child,
                );
              },
            );
          },
        );
      },
    );
  }
}

class WavySlider extends StatelessWidget {
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const WavySlider({
    Key? key,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.globalToLocal(details.globalPosition);
        const horizontalPadding = 24.0;
        final width = box.size.width - (horizontalPadding * 2);
        final percent = ((position.dx - horizontalPadding) / width).clamp(0.0, 1.0);
        onChanged(percent * max);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.globalToLocal(details.globalPosition);
        const horizontalPadding = 24.0;
        final width = box.size.width - (horizontalPadding * 2);
        final percent = ((position.dx - horizontalPadding) / width).clamp(0.0, 1.0);
        onChanged(percent * max);
      },
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: _WavySliderPainter(
          value: value / (max > 0 ? max : 1.0),
          color: color,
        ),
      ),
    );
  }
}

class _WavySliderPainter extends CustomPainter {
  final double value;
  final Color color;

  _WavySliderPainter({
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final thumbPaint = Paint()..color = color;

    final y = size.height / 2;
    const horizontalPadding = 24.0;
    final width = size.width - (horizontalPadding * 2);
    final progressWidth = width * value;
    final startX = horizontalPadding;
    final endX = size.width - horizontalPadding;
    final thumbX = startX + progressWidth;

    canvas.drawLine(Offset(thumbX, y), Offset(endX, y), backgroundPaint);

    final path = Path();
    path.moveTo(startX, y);

    const waveLength = 45.0;
    const amplitude = 2.5;
    for (double x = 0; x <= progressWidth; x += 1) {
      final waveY = y + sin(x / waveLength * 2 * pi) * amplitude;
      path.lineTo(startX + x, waveY);
    }

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(thumbX, y), 8, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _WavySliderPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class DashedSlider extends StatelessWidget {
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const DashedSlider({
    Key? key,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.globalToLocal(details.globalPosition);
        const horizontalPadding = 24.0;
        final width = box.size.width - (horizontalPadding * 2);
        final percent = ((position.dx - horizontalPadding) / width).clamp(0.0, 1.0);
        onChanged(percent * max);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.globalToLocal(details.globalPosition);
        const horizontalPadding = 24.0;
        final width = box.size.width - (horizontalPadding * 2);
        final percent = ((position.dx - horizontalPadding) / width).clamp(0.0, 1.0);
        onChanged(percent * max);
      },
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: _DashedSliderPainter(
          value: value / (max > 0 ? max : 1.0),
          color: color,
        ),
      ),
    );
  }
}

class _DashedSliderPainter extends CustomPainter {
  final double value;
  final Color color;

  _DashedSliderPainter({
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final thumbPaint = Paint()..color = color;

    final y = size.height / 2;
    const horizontalPadding = 24.0;
    final width = size.width - (horizontalPadding * 2);
    final progressWidth = width * value;
    final startX = horizontalPadding;
    final endX = size.width - horizontalPadding;
    final thumbX = startX + progressWidth;

    canvas.drawLine(Offset(thumbX, y), Offset(endX, y), backgroundPaint);

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double currentX = startX;
    while (currentX < thumbX) {
      final nextX = (currentX + dashWidth) > thumbX ? thumbX : (currentX + dashWidth);
      canvas.drawLine(Offset(currentX, y), Offset(nextX, y), paint);
      currentX += dashWidth + dashSpace;
    }

    canvas.drawCircle(Offset(thumbX, y), 8, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _DashedSliderPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class DotsSlider extends StatelessWidget {
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const DotsSlider({
    Key? key,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.globalToLocal(details.globalPosition);
        const horizontalPadding = 24.0;
        final width = box.size.width - (horizontalPadding * 2);
        final percent = ((position.dx - horizontalPadding) / width).clamp(0.0, 1.0);
        onChanged(percent * max);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.globalToLocal(details.globalPosition);
        const horizontalPadding = 24.0;
        final width = box.size.width - (horizontalPadding * 2);
        final percent = ((position.dx - horizontalPadding) / width).clamp(0.0, 1.0);
        onChanged(percent * max);
      },
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: _DotsSliderPainter(
          value: value / (max > 0 ? max : 1.0),
          color: color,
        ),
      ),
    );
  }
}

class _DotsSliderPainter extends CustomPainter {
  final double value;
  final Color color;

  _DotsSliderPainter({
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final thumbPaint = Paint()..color = color;

    final y = size.height / 2;
    const horizontalPadding = 24.0;
    final width = size.width - (horizontalPadding * 2);
    final progressWidth = width * value;
    final startX = horizontalPadding;
    final endX = size.width - horizontalPadding;
    final thumbX = startX + progressWidth;

    canvas.drawLine(Offset(startX, y), Offset(endX, y), backgroundPaint);

    const dotSpacing = 12.0;
    const dotRadius = 3.0;
    double currentX = startX;
    while (currentX <= thumbX) {
      canvas.drawCircle(Offset(currentX, y), dotRadius, paint);
      currentX += dotSpacing;
    }

    canvas.drawCircle(Offset(thumbX, y), 8, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _DotsSliderPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class _V2CoverArt extends ConsumerStatefulWidget {
  final dynamic current;
  final double scale;
  final bool isDark;
  final Color effectiveAccent;
  final Widget Function(dynamic, double) customTrackCoverBuilder;

  const _V2CoverArt({
    required this.current,
    required this.scale,
    required this.isDark,
    required this.effectiveAccent,
    required this.customTrackCoverBuilder,
  });

  @override
  ConsumerState<_V2CoverArt> createState() => _V2CoverArtState();
}

class _V2CoverArtState extends ConsumerState<_V2CoverArt> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: const Offset(0, 0.02),
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOutSine,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(v2FloatingEnabledProvider) && !ref.read(isFrozenProvider)) {
        _floatController.repeat(reverse: true);
      } else {
        _floatController.value = 0.5;
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFloating = ref.watch(v2FloatingEnabledProvider);
    final isFrozen = ref.watch(isFrozenProvider);

    ref.listen<bool>(v2FloatingEnabledProvider, (prev, next) {
      if (next && !ref.read(isFrozenProvider)) {
        _floatController.repeat(reverse: true);
      } else {
        _floatController.animateTo(0.5, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      }
    });

    ref.listen<bool>(isFrozenProvider, (prev, next) {
      if (next) {
        _floatController.stop();
      } else if (ref.read(v2FloatingEnabledProvider)) {
        _floatController.repeat(reverse: true);
      }
    });

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: (isFloating && !isFrozen) ? _floatAnimation : AlwaysStoppedAnimation(Offset.zero),
          child: child,
        );
      },
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(0.02)
          ..rotateY(0.02),
        alignment: Alignment.center,
        child: Container(
          width: 450 * widget.scale,
          height: 450 * widget.scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32 * widget.scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40 * widget.scale,
                offset: Offset(0, 20 * widget.scale),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32 * widget.scale),
            child: widget.customTrackCoverBuilder(widget.current, widget.scale),
          ),
        ),
      ),
    );
  }
}
class _V2ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double scale;
  final Color color;
  final double size;

  const _V2ControlBtn({
    required this.icon,
    required this.onTap,
    required this.scale,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      scale: 1.1,
      child: IconButton(
        icon: Icon(icon, size: size, color: color),
        onPressed: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }
}

class _V2PlayBtn extends StatelessWidget {
  final VoidCallback onTap;
  final double scale;
  final Color effectiveAccent;
  final PlayerService playerService;

  const _V2PlayBtn({
    required this.onTap,
    required this.scale,
    required this.effectiveAccent,
    required this.playerService,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return HoverScale(
      scale: 1.05,
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10 * scale, sigmaY: 10 * scale),
            child: Container(
              width: 92 * scale,
              height: 92 * scale,
              decoration: BoxDecoration(
                color: effectiveAccent.withOpacity(isDark ? 0.25 : 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5 * scale),
                boxShadow: [
                  BoxShadow(
                    color: effectiveAccent.withOpacity(0.3),
                    blurRadius: 24 * scale,
                    offset: Offset(0, 8 * scale),
                  ),
                ],
              ),
              child: StreamBuilder<PlayerState>(
                initialData: playerService.playerState,
                stream: playerService.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  return Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 54 * scale,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverEffectLayer extends ConsumerStatefulWidget {
  final String effect;
  final double scale;

  const _CoverEffectLayer({required this.effect, required this.scale});

  @override
  ConsumerState<_CoverEffectLayer> createState() => _CoverEffectLayerState();
}

class _CoverEffectLayerState extends ConsumerState<_CoverEffectLayer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _controller.addListener(_updateParticles);
  }

  void _updateParticles() {
    if (!mounted || ref.read(isFrozenProvider)) return;
    
    setState(() {
      int spawnCount = widget.effect == 'blood' ? 3 : 1;
      if (_particles.length < 150) {
        for (int i = 0; i < spawnCount; i++) {
          final angle = _random.nextDouble() * 2 * pi;
          final speed = widget.effect == 'blood' 
            ? (_random.nextDouble() * 6 + 2) * widget.scale 
            : (_random.nextDouble() * 1.5 + 0.5) * widget.scale;
          
          final radius = 150 * widget.scale;
          
          _particles.add(_Particle(
            x: cos(angle) * radius,
            y: sin(angle) * radius,
            vx: cos(angle) * speed,
            vy: sin(angle) * speed,
            life: 1.0,
            size: _random.nextDouble() * 6 * widget.scale + 2 * widget.scale,
            color: widget.effect == 'blood' 
              ? Color.lerp(Colors.red[900], Colors.red[700], _random.nextDouble())!
              : Color.lerp(Colors.greenAccent[700], Colors.limeAccent[400], _random.nextDouble())!,
          ));
        }
      }

      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.x += p.vx;
        p.y += p.vy;
        
        if (widget.effect == 'blood') {
          p.vx *= 0.96;
          p.vy *= 0.96;
          p.vy += 0.15 * widget.scale;
          p.life -= 0.02;
        } else {
          p.vx *= 0.98;
          p.vy += 0.05 * widget.scale;
          p.life -= 0.01;
        }
        
        if (p.life <= 0) _particles.removeAt(i);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = ref.watch(isFrozenProvider);
    if (isFrozen) return const SizedBox.shrink();
    
    return CustomPaint(
      painter: _CoverEffectPainter(particles: _particles, effect: widget.effect),
      size: Size(600 * widget.scale, 600 * widget.scale),
    );
  }
}

class _Particle {
  double x, y, vx, vy, life, size;
  Color color;
  _Particle({required this.x, required this.y, required this.vx, required this.vy, required this.life, required this.size, required this.color});
}

class _CoverEffectPainter extends CustomPainter {
  final List<_Particle> particles;
  final String effect;

  _CoverEffectPainter({required this.particles, required this.effect});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.life.clamp(0, 1))
        ..style = PaintingStyle.fill;

      if (effect == 'blood') {
        final velocity = Offset(p.vx, p.vy);
        if (velocity.distance > 0.5) {
          final path = Path();
          final angle = atan2(p.vy, p.vx);
          final tailLen = 15.0 * p.life;
          
          path.moveTo(center.dx + p.x, center.dy + p.y);
          path.lineTo(
            center.dx + p.x - cos(angle) * tailLen, 
            center.dy + p.y - sin(angle) * tailLen
          );
          
          canvas.drawPath(path, Paint()
            ..color = p.color.withOpacity(p.life * 0.5)
            ..strokeWidth = p.size
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
        }
        canvas.drawCircle(center + Offset(p.x, p.y), p.size, paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: center + Offset(p.x, p.y),
            width: p.size * 1.2,
            height: p.size * 2.0 * (1 + (1 - p.life)),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoverEffectPainter oldDelegate) => true;
}
