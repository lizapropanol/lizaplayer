import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_music/yandex_music.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/services/player_service.dart';
import 'package:lizaplayer/screens/auth_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:lizaplayer/main.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';

final blurEnabledProvider = StateProvider<bool>((ref) => false);
final scaleProvider = StateProvider<double>((ref) => 1.0);

class HomeScreen extends ConsumerStatefulWidget {
  final String token;
  const HomeScreen({required this.token, super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late final YandexMusic _client;
  final PlayerService _playerService = PlayerService();
  late final TabController _tabController;

  List<Track> waveTracks = [];
  bool _loading = false;
  bool _isWaveActive = false;

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _playerStateSubscription;

  List<Track> _likedTracks = [];
  bool _isLikesOpen = false;

  bool _isInitialized = false;

  String? _customBackgroundUrl;

  late AnimationController _pauseAnimationController;
  late Animation<double> _pauseAnimation;

  late AnimationController _prevAnimationController;
  late Animation<double> _prevAnimation;

  late AnimationController _nextAnimationController;
  late Animation<double> _nextAnimation;

  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  late AnimationController _waveController;

  List<Track> _currentPlaylist = [];
  int _currentIndex = -1;
  List<Track> _queueTracks = [];

  bool _showMiniPlayer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_tabListener);
    _pauseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pauseAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _pauseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _prevAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _prevAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _prevAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _nextAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _nextAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _nextAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _initializeApp();
  }

  void _tabListener() {
    if (mounted) {
      setState(() {
        _showMiniPlayer = _tabController.index != 0;
      });
    }
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    try {
      _client = YandexMusic(token: widget.token);
      await _client.init();
      _playerService.setClient(_client);

      _playerStateSubscription = _playerService.player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _nextTrack();
        }
        if (mounted) {
          setState(() {});
        }
      });

      await _loadLikedTracks();

      _customBackgroundUrl = await TokenStorage.getCustomGifUrl();

      final blurEnabled = await TokenStorage.getBlurEnabled();
      ref.read(blurEnabledProvider.notifier).state = blurEnabled;

      final scale = await TokenStorage.getScale() ?? 0.8;
      ref.read(scaleProvider.notifier).state = scale;

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('Initialization error: $e');
    }

    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 3)) {
      await Future.delayed(const Duration(seconds: 3) - elapsed);
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _loadLikedTracks() async {
    final ids = await TokenStorage.getLikedTrackIds();
    if (ids.isEmpty) return;

    try {
      final loaded = await _client.tracks.getTracks(ids);
      setState(() {
        _likedTracks = loaded.whereType<Track>().toList();
      });
    } catch (e) {
      print('Error loading liked tracks: $e');
    }
  }

  Future<void> _toggleLike([Track? track]) async {
    final trackToToggle = track ?? _playerService.currentTrack;
    if (trackToToggle == null || trackToToggle.id == null) return;

    final id = trackToToggle.id!;
    final willBeLiked = !_likedTracks.any((t) => t.id == id);

    setState(() {
      if (willBeLiked) {
        _likedTracks.insert(0, trackToToggle);
      } else {
        _likedTracks.removeWhere((t) => t.id == id);
      }
    });

    final currentIds = _likedTracks.map((t) => t.id.toString()).toList();
    await TokenStorage.saveLikedTrackIds(currentIds);
  }

  Widget _buildTrackTile(Track track, int index, List<Track> list, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isPlaying = _playerService.currentTrack?.id == track.id;
    final durationText = _formatDuration(
      track.durationMs != null ? Duration(milliseconds: track.durationMs!) : null,
    );
    final loc = AppLocalizations.of(context)!;
    final isLiked = _likedTracks.any((t) => t.id == track.id);

    return Container(
      decoration: BoxDecoration(
        color: isPlaying ? effectiveAccent.withOpacity(isDark ? 0.13 : 0.08) : null,
        borderRadius: BorderRadius.circular(22 * scale),
      ),
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
                  imageUrl: _getCoverUrl(track.coverUri, size: '100x100'),
                  width: 56 * scale,
                  height: 56 * scale,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[900],
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5 * scale)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 56 * scale,
                    height: 56 * scale,
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
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
                      track.title ?? loc.untitledTrack,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17 * scale,
                        fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                        color: isPlaying ? effectiveAccent : null,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      track.artists?.map((a) => a.title).join(', ') ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5 * scale, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * scale),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _toggleLike(track),
                    icon: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? effectiveAccent : Colors.grey,
                      size: 26 * scale,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 44 * scale, minHeight: 44 * scale),
                  ),
                  SizedBox(width: 20 * scale),
                  Text(
                    durationText,
                    style: TextStyle(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final effectiveTint = accent.opacity == 0 ? Colors.transparent : accent;

    final fillOpacity = customOpacity ?? (isDark ? 0.16 : 0.82);
    final color = glassEnabled
        ? effectiveTint.withOpacity(fillOpacity)
        : (isDark ? const Color(0xFF1C1C1E) : Colors.white);

    final border = customBorder ?? (glassEnabled
        ? Border.all(
            color: Colors.white.withOpacity(isDark ? 0.18 : 0.25),
            width: 1.5 * scale,
          )
        : null);

    final container = Container(
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

    if (glassEnabled && enableBlur) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0 * scale, sigmaY: 10.0 * scale),
          child: container,
        ),
      );
    }
    return container;
  }

  Widget _buildAnimatedIcon({
    required IconData icon,
    required Color color,
    required double size,
    required double containerSize,
    required double scale,
    required Color accent,
  }) {
    return Stack(
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
                      border: Border.all(
                        color: accent,
                        width: 1.5 * scale,
                      ),
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
          child: Icon(
            icon,
            size: size,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMyWaveStart(bool isDark, AppLocalizations loc, bool glassEnabled, double scale) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

    final isUnlocked = _likedTracks.length >= 5;

    Widget startWidget;
    if (isUnlocked) {
      if (glassEnabled) {
        startWidget = _buildGlassContainer(
          glassEnabled: true,
          isDark: isDark,
          borderRadius: BorderRadius.circular(40 * scale),
          customOpacity: isDark ? 0.3 : 0.9,
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
                    SizedBox(
                      width: 30 * scale,
                      height: 30 * scale,
                      child: CircularProgressIndicator(
                        strokeWidth: 3 * scale,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  else
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 42 * scale,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  SizedBox(width: 12 * scale),
                  Text(
                    _loading ? loc.loading : loc.startMyWave,
                    style: TextStyle(
                      fontSize: 23 * scale,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          scale: scale,
        );
      } else {
        startWidget = ElevatedButton.icon(
          onPressed: _loading ? null : _startMyWave,
          icon: _loading
              ? SizedBox(
                  width: 30 * scale,
                  height: 30 * scale,
                  child: CircularProgressIndicator(strokeWidth: 3 * scale, color: Colors.black),
                )
              : Icon(Icons.play_arrow_rounded, size: 42 * scale),
          label: Text(
            _loading ? loc.loading : loc.startMyWave,
            style: TextStyle(fontSize: 23 * scale, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 72 * scale, vertical: 26 * scale),
            backgroundColor: effectiveAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40 * scale)),
            elevation: 16 * scale,
            shadowColor: effectiveAccent.withOpacity(0.7),
          ),
        );
      }
    } else {
      startWidget = SizedBox(
        width: 600 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 1.5 * scale,
              color: Colors.grey.withOpacity(isDark ? 0.2 : 0.3),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.grey, size: 36 * scale),
                CircleAvatar(
                  radius: 24 * scale,
                  backgroundColor: Colors.transparent,
                  child: Icon(Icons.person_outline_rounded, color: Colors.grey, size: 36 * scale),
                ),
                Container(
                  width: 48 * scale,
                  height: 48 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey, width: 2 * scale),
                  ),
                ),
                Icon(Icons.star_border_rounded, color: Colors.blue.withOpacity(0.5), size: 36 * scale),
                Container(
                  width: 48 * scale,
                  height: 48 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.brown.withOpacity(0.5),
                  ),
                ),
                Icon(Icons.face_rounded, color: Colors.green.withOpacity(0.5), size: 36 * scale),
                Icon(Icons.visibility_rounded, color: Colors.grey, size: 36 * scale),
              ],
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 40 * scale, vertical: 60 * scale),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(40 * scale),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40 * scale, vertical: 60 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedIcon(
                  icon: isUnlocked ? Icons.waves_rounded : Icons.lock_rounded,
                  color: effectiveAccent,
                  size: 165 * scale,
                  containerSize: 280 * scale,
                  scale: scale,
                  accent: effectiveAccent,
                ),
                SizedBox(height: 56 * scale),
                Text(
                  loc.myWave,
                  style: TextStyle(
                    fontSize: 44 * scale,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.2 * scale,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 16 * scale),
                SizedBox(
                  width: 340 * scale,
                  child: Text(
                    isUnlocked ? loc.personalRecommendations : 'Listen to at least 5 tracks to make this feature available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.5 * scale,
                      height: 1.35,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                SizedBox(height: 72 * scale),
                startWidget,
              ],
            ),
          ),
          scale: scale,
        ),
      ),
    );
  }

  Widget _buildMyWavePlaylist(bool isDark, AppLocalizations loc, bool glassEnabled, double scale) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

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
                  Container(
                    padding: EdgeInsets.all(14 * scale),
                    decoration: BoxDecoration(
                      color: effectiveAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(22 * scale),
                    ),
                    child: Icon(Icons.waves_rounded, size: 46 * scale, color: effectiveAccent),
                  ),
                  SizedBox(width: 22 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.myWave,
                          style: TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.8 * scale),
                        ),
                        Text(
                          '${waveTracks.length} ${loc.tracks} • ${loc.personalWave}',
                          style: TextStyle(fontSize: 16.5 * scale, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _startMyWave,
                    icon: Icon(Icons.refresh_rounded, color: effectiveAccent, size: 32 * scale),
                    tooltip: loc.newWave,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                itemCount: waveTracks.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1 * scale,
                  thickness: 0.6 * scale,
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                  indent: 92 * scale,
                  endIndent: 24 * scale,
                ),
                itemBuilder: (context, index) => _buildTrackTile(waveTracks[index], index, waveTracks, scale),
              ),
            ),
          ],
        ),
      ),
      scale: scale,
    );
  }

  Widget _buildMyWaveTab(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    if (_isWaveActive && waveTracks.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildMyWavePlaylist(isDark, loc, glassEnabled, scale),
      );
    }
    return _buildMyWaveStart(isDark, loc, glassEnabled, scale);
  }

  Widget _buildLikesPlaylist(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final loc = AppLocalizations.of(context)!;

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
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isLikesOpen = false;
                      });
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: effectiveAccent, size: 32 * scale),
                  ),
                  SizedBox(width: 16 * scale),
                  Container(
                    padding: EdgeInsets.all(14 * scale),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(22 * scale),
                    ),
                    child: Icon(Icons.favorite_rounded, size: 46 * scale, color: Colors.redAccent),
                  ),
                  SizedBox(width: 22 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.myLikes,
                          style: TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.8 * scale),
                        ),
                        Text(
                          '${_likedTracks.length} ${loc.tracks}',
                          style: TextStyle(fontSize: 16.5 * scale, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _likedTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 120 * scale,
                            color: Colors.redAccent.withOpacity(0.4),
                          ),
                          SizedBox(height: 40 * scale),
                          Text(
                            loc.noLikesYet,
                            style: TextStyle(
                              fontSize: 28 * scale,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          SizedBox(
                            width: 280 * scale,
                            child: Text(
                              loc.likeToFill,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17.5 * scale,
                                height: 1.4,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                      itemCount: _likedTracks.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1 * scale,
                        thickness: 0.6 * scale,
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                        indent: 92 * scale,
                        endIndent: 24 * scale,
                      ),
                      itemBuilder: (context, index) => _buildTrackTile(_likedTracks[index], index, _likedTracks, scale),
                    ),
            ),
          ],
        ),
      ),
      scale: scale,
    );
  }

  Widget _buildPlaylistsTab(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    if (_isLikesOpen) {
      return Padding(
        padding: EdgeInsets.only(left: 24 * scale, right: 24 * scale, bottom: 24 * scale),
        child: _buildLikesPlaylist(glassEnabled, scale),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaylistCard(
            title: loc.myLikes,
            subtitle: '${_likedTracks.length} ${loc.tracks}',
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            onTap: () {
              setState(() {
                _isLikesOpen = true;
              });
            },
            glassEnabled: glassEnabled,
            isDark: isDark,
            scale: scale,
          ),
          _buildPlaylistCard(
            title: loc.myPlaylists,
            subtitle: loc.syncComingSoon,
            icon: Icons.queue_music_rounded,
            iconColor: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary,
            onTap: () {},
            glassEnabled: glassEnabled,
            isDark: isDark,
            scale: scale,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool glassEnabled,
    required bool isDark,
    required double scale,
  }) {
    final effectiveIconColor = iconColor.opacity == 0 ? Colors.grey : iconColor;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: 16 * scale),
        child: _buildGlassContainer(
          glassEnabled: glassEnabled,
          isDark: isDark,
          borderRadius: BorderRadius.circular(28 * scale),
          child: Padding(
            padding: EdgeInsets.all(20 * scale),
            child: Row(
              children: [
                Container(
                  width: 64 * scale,
                  height: 64 * scale,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18 * scale),
                  ),
                  child: Icon(icon, size: 34 * scale, color: effectiveIconColor),
                ),
                SizedBox(width: 20 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4 * scale),
                      Text(subtitle, style: TextStyle(fontSize: 15.5 * scale, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24 * scale),
              ],
            ),
          ),
          scale: scale,
        ),
      ),
    );
  }

  Future<void> _searchTracks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<Track> tracks = [];
    try {
      tracks = await _client.search.tracks(query);
    } catch (e) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop();

    if (mounted) {
      if (tracks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.noResultsFound)));
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
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.8,
                minChildSize: 0.3,
                maxChildSize: 0.95,
                builder: (context, scrollController) => _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Column(
                    children: [
                      Container(
                        width: 40 * scale,
                        height: 5 * scale,
                        margin: EdgeInsets.symmetric(vertical: 10 * scale),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10 * scale),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
                        child: Text(
                          loc.searchResultsFor(query),
                          style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                          itemCount: tracks.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1 * scale,
                            thickness: 0.6 * scale,
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                            indent: 92 * scale,
                            endIndent: 24 * scale,
                          ),
                          itemBuilder: (context, index) => _buildTrackTile(tracks[index], index, tracks, scale),
                        ),
                      ),
                    ],
                  ),
                  scale: scale,
                ),
              );
            },
          ),
        );
      }
    }
  }

  Future<void> _startMyWave() async {
    setState(() {
      _loading = true;
      waveTracks = [];
      _isWaveActive = true;
    });

    try {
      final waves = await _client.myVibe.getWaves();
      final wave = await _client.myVibe.createWave(waves);

      setState(() => waveTracks = wave.tracks ?? []);

      if (waveTracks.length < 30 && waveTracks.isNotEmpty) {
        try {
          final randomIndex = Random().nextInt(waveTracks.length);
          final similar = await _client.tracks.getSimilar(waveTracks[randomIndex].id);
          setState(() => waveTracks = [...waveTracks, ...similar]);
        } catch (_) {}
      }

      waveTracks.shuffle();

      if (waveTracks.isNotEmpty) _playFromList(waveTracks, 0);
    } catch (e) {
      final fallback = await _client.search.tracks('my day');
      setState(() => waveTracks = fallback);

      if (waveTracks.length < 30 && waveTracks.isNotEmpty) {
        try {
          final randomIndex = Random().nextInt(waveTracks.length);
          final similar = await _client.tracks.getSimilar(waveTracks[randomIndex].id);
          setState(() => waveTracks = [...waveTracks, ...similar]);
        } catch (_) {}
      }

      waveTracks.shuffle();

      if (waveTracks.isNotEmpty) _playFromList(waveTracks, 0);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _playFromList(List<Track> list, int index) {
    if (index < 0 || index >= list.length) return;

    setState(() {
      _currentPlaylist = list;
      _currentIndex = index;
      _queueTracks = _currentPlaylist.skip(_currentIndex + 1).toList();
    });

    _playCurrentTrack();
  }

  void _playCurrentTrack() {
    if (_currentIndex >= 0 && _currentIndex < _currentPlaylist.length) {
      final track = _currentPlaylist[_currentIndex];
      _playerService.playFromPlaylist([track], 0);
      setState(() {
        _queueTracks = _currentPlaylist.skip(_currentIndex + 1).toList();
      });
    }
  }

  void _nextTrack() {
    if (_currentIndex < _currentPlaylist.length - 1) {
      _currentIndex++;
      _playCurrentTrack();
    }
  }

  void _prevTrack() {
    if (_playerService.player.position > const Duration(seconds: 3)) {
      _playerService.player.seek(Duration.zero);
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
        _playCurrentTrack();
      }
    }
  }

  void _playAtPlaylistIndex(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _currentPlaylist.length) return;
    _currentIndex = globalIndex;
    _playCurrentTrack();
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
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _logout() async {
    await TokenStorage.deleteToken();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
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
                  Text(loc.theme, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: modes.map((m) {
                    final selected = currentMode == m['mode'];
                    final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                    final buttonContent = Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                      child: Text(m['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
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
                              color: selected ? effectivePrimary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: buttonContent,
                          );
                    return Padding(
                      padding: EdgeInsets.only(right: 8 * scale),
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(themeModeProvider.notifier).state = m['mode'] as ThemeMode;
                          await TokenStorage.saveThemeMode(m['mode'] as ThemeMode);
                        },
                        child: button,
                      ),
                    );
                  }).toList(),
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
                  Text(loc.mainColor, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: colorMap.map((cm) {
                    final color = cm['color'] as Color;
                    final label = cm['label'] as String;
                    final selected = currentColor == color;
                    final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                    final buttonContent = Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                      child: Text(label, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
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
                              color: selected ? effectivePrimary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: buttonContent,
                          );
                    return Padding(
                      padding: EdgeInsets.only(right: 8 * scale),
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(accentColorProvider.notifier).state = color;
                          await TokenStorage.saveAccentColor(color.value);
                        },
                        child: button,
                      ),
                    );
                  }).toList(),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.language_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.language, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: languages.map((l) {
                    final selected = currentLocale == l['locale'];
                    final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                    final buttonContent = Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                      child: Text(l['title'] as String, style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
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
                              color: selected ? effectivePrimary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: buttonContent,
                          );
                    return Padding(
                      padding: EdgeInsets.only(right: 8 * scale),
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(localeProvider.notifier).state = l['locale'] as Locale;
                          await TokenStorage.saveLanguage((l['locale'] as Locale).languageCode);
                        },
                        child: button,
                      ),
                    );
                  }).toList(),
                ),
              ),
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
              Text(loc.customBackground, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: _buildGlassContainer(
            glassEnabled: glassEnabled,
            isDark: isDark,
            borderRadius: BorderRadius.circular(50 * scale),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: loc.urlExample,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
              ),
            ),
            scale: scale,
          ),
        ),
        SizedBox(height: 8 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: Row(
            children: [
              Expanded(
                child: _buildGlassContainer(
                  glassEnabled: glassEnabled,
                  isDark: isDark,
                  borderRadius: BorderRadius.circular(50 * scale),
                  child: GestureDetector(
                    onTap: () async {
                      final url = controller.text.trim();
                      final newUrl = url.isEmpty ? null : url;
                      await TokenStorage.saveCustomGifUrl(newUrl);
                      setState(() => _customBackgroundUrl = newUrl);
                    },
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12 * scale),
                        child: Text(loc.save, style: TextStyle(fontSize: 16 * scale)),
                      ),
                    ),
                  ),
                  scale: scale,
                ),
              ),
              if (_customBackgroundUrl != null && _customBackgroundUrl!.isNotEmpty) ...[
                SizedBox(width: 16 * scale),
                Expanded(
                  child: _buildGlassContainer(
                    glassEnabled: glassEnabled,
                    isDark: isDark,
                    borderRadius: BorderRadius.circular(50 * scale),
                    child: GestureDetector(
                      onTap: () async {
                        await TokenStorage.saveCustomGifUrl(null);
                        controller.clear();
                        setState(() => _customBackgroundUrl = null);
                      },
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12 * scale),
                          child: Text(loc.clear, style: TextStyle(fontSize: 16 * scale, color: Colors.white)),
                        ),
                      ),
                    ),
                    scale: scale,
                  ),
                ),
              ],
            ],
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
        final options = [
          {'value': false, 'title': loc.off},
          {'value': true, 'title': loc.on},
        ];
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
                  Text(loc.glassInterface, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: options.map((o) {
                    final selected = enabled == o['value'];
                    final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
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
                              color: selected ? effectivePrimary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: buttonContent,
                          );
                    return Padding(
                      padding: EdgeInsets.only(right: 8 * scale),
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(glassEnabledProvider.notifier).state = o['value'] as bool;
                          await TokenStorage.saveGlassEnabled(o['value'] as bool);
                        },
                        child: button,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildBlurSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = AppLocalizations.of(context)!;
        final enabled = ref.watch(blurEnabledProvider);
        final options = [
          {'value': false, 'title': loc.off},
          {'value': true, 'title': loc.on},
        ];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glassEnabled = ref.watch(glassEnabledProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
              child: Row(
                children: [
                  Icon(Icons.blur_linear_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.backgroundBlur, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: options.map((o) {
                    final selected = enabled == o['value'];
                    final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
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
                              color: selected ? effectivePrimary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: buttonContent,
                          );
                    return Padding(
                      padding: EdgeInsets.only(right: 8 * scale),
                      child: GestureDetector(
                        onTap: () async {
                          ref.read(blurEnabledProvider.notifier).state = o['value'] as bool;
                          await TokenStorage.saveBlurEnabled(o['value'] as bool);
                        },
                        child: button,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildScaleSelector(double scale) {
    return Consumer(
      builder: (context, ref, child) {
        final currentScale = ref.watch(scaleProvider);
        final percentages = [50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150];
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
                  Icon(Icons.zoom_in_rounded, color: Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24 * scale),
                  SizedBox(width: 16 * scale),
                  Text(loc.interfaceScale, style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: percentages.map((p) {
                    final selected = (currentScale * 100).round() == p;
                    final effectivePrimary = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
                    final buttonContent = Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                      child: Text('$p%', style: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : Colors.black))),
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
                              color: selected ? effectivePrimary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: buttonContent,
                          );
                    return Padding(
                      padding: EdgeInsets.only(right: 8 * scale),
                      child: GestureDetector(
                        onTap: () async {
                          final newScale = p / 100.0;
                          ref.read(scaleProvider.notifier).state = newScale;
                          await TokenStorage.saveScale(newScale);
                        },
                        child: button,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16 * scale),
          ],
        );
      },
    );
  }

  Widget _buildMainPlayerArea(Track? current, bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isLiked = current != null && _likedTracks.any((t) => t.id == current.id);

    return Center(
      child: SizedBox(
        width: 500 * scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null)
              _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24 * scale, 36 * scale, 24 * scale, 24 * scale),
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Center(
                          child: Container(
                            key: ValueKey(current.id ?? 'empty'),
                            width: 420 * scale,
                            height: 420 * scale,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50 * scale),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50 * scale),
                              child: CachedNetworkImage(
                                imageUrl: _getCoverUrl(current.coverUri, size: '400x400'),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(Icons.music_note, size: 140 * scale, color: Colors.white24),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20 * scale),

                      Text(current.title ?? '', style: TextStyle(fontSize: 26 * scale, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      SizedBox(height: 8 * scale),
                      Text(current.artists?.map((a) => a.title).join(', ') ?? '', style: TextStyle(fontSize: 17 * scale, color: Colors.grey), textAlign: TextAlign.center),

                      SizedBox(height: 30 * scale),

                      StreamBuilder<Duration>(
                        stream: _playerService.player.positionStream,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? Duration.zero;
                          final dur = _playerService.duration ?? Duration.zero;

                          return Column(
                            children: [
                              Slider(
                                value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                                max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1,
                                activeColor: effectiveAccent,
                                onChanged: (v) => _playerService.player.seek(Duration(milliseconds: v.toInt())),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(pos),
                                      style: TextStyle(
                                        fontSize: 13.5 * scale,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[400],
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(dur),
                                      style: TextStyle(
                                        fontSize: 13.5 * scale,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[400],
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: 12 * scale),

                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 50 * scale),
                                SizedBox(
                                  width: 48 * scale,
                                  height: 48 * scale,
                                  child: GestureDetector(
                                    onTapDown: (_) => _prevAnimationController.forward(),
                                    onTapUp: (_) => _prevAnimationController.reverse(),
                                    onTapCancel: () => _prevAnimationController.reverse(),
                                    onTap: _prevTrack,
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _prevAnimation,
                                        child: Icon(Icons.skip_previous, size: 36 * scale),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 24 * scale),
                                SizedBox(
                                  width: 64 * scale,
                                  height: 64 * scale,
                                  child: GestureDetector(
                                    onTapDown: (_) => _pauseAnimationController.forward(),
                                    onTapUp: (_) => _pauseAnimationController.reverse(),
                                    onTapCancel: () => _pauseAnimationController.reverse(),
                                    onTap: () => _playerService.player.playing
                                        ? _playerService.player.pause()
                                        : _playerService.player.play(),
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _pauseAnimation,
                                        child: StreamBuilder<PlayerState>(
                                          stream: _playerService.player.playerStateStream,
                                          builder: (_, snap) => Icon(
                                            (snap.data?.playing ?? false) ? Icons.pause : Icons.play_arrow,
                                            size: 54 * scale,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 24 * scale),
                                SizedBox(
                                  width: 48 * scale,
                                  height: 48 * scale,
                                  child: GestureDetector(
                                    onTapDown: (_) => _nextAnimationController.forward(),
                                    onTapUp: (_) => _nextAnimationController.reverse(),
                                    onTapCancel: () => _nextAnimationController.reverse(),
                                    onTap: _nextTrack,
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _nextAnimation,
                                        child: Icon(Icons.skip_next, size: 36 * scale),
                                      ),
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
                              child: Center(
                                child: ScaleTransition(
                                  scale: _likeAnimation,
                                  child: Icon(
                                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isLiked ? effectiveAccent : null,
                                    size: 30 * scale,
                                  ),
                                ),
                              ),
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
                              stream: _playerService.player.volumeStream,
                              builder: (_, snap) => Slider(
                                value: snap.data ?? _playerService.volume,
                                activeColor: effectiveAccent,
                                onChanged: (v) => _playerService.setVolume(v),
                              ),
                            ),
                          ),
                          Icon(Icons.volume_up, size: 24 * scale),
                        ],
                      ),
                    ],
                  ),
                ),
                scale: scale,
              )
            else
              Center(
                child: Icon(Icons.music_note, size: 140 * scale, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuePanel(bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final loc = AppLocalizations.of(context)!;

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(40 * scale),
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
                    Text(
                      loc.queue,
                      style: TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.8 * scale),
                    ),
                    Text(
                      '${_queueTracks.length} ${loc.tracks}',
                      style: TextStyle(fontSize: 16.5 * scale, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _queueTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 40 * scale),
                          Text(
                            loc.queueEmpty,
                            style: TextStyle(
                              fontSize: 28 * scale,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 8 * scale),
                      itemCount: _queueTracks.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1 * scale,
                        thickness: 0.6 * scale,
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                        indent: 92 * scale,
                        endIndent: 24 * scale,
                      ),
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () => _playAtPlaylistIndex(_currentIndex + 1 + index),
                          child: _buildTrackTile(_queueTracks[index], index, _queueTracks, scale),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      scale: scale,
    );
  }

  Widget _buildMiniPlayer(Track current, bool glassEnabled, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isLiked = _likedTracks.any((t) => t.id == current.id);

    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(30 * scale),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16 * scale),
              child: CachedNetworkImage(
                imageUrl: _getCoverUrl(current.coverUri, size: '80x80'),
                width: 60 * scale,
                height: 60 * scale,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(Icons.music_note, size: 30 * scale, color: Colors.grey),
              ),
            ),
            SizedBox(width: 16 * scale),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    current.artists?.map((a) => a.title).join(', ') ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13 * scale, color: Colors.grey),
                  ),
                  SizedBox(height: 4 * scale),
                  StreamBuilder<Duration>(
                    stream: _playerService.player.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data?.inMilliseconds ?? 0;
                      final dur = _playerService.duration?.inMilliseconds ?? 1;
                      return LinearProgressIndicator(
                        value: pos / dur,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(effectiveAccent),
                        minHeight: 3 * scale,
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 32 * scale,
              height: 32 * scale,
              child: GestureDetector(
                onTapDown: (_) => _prevAnimationController.forward(),
                onTapUp: (_) => _prevAnimationController.reverse(),
                onTapCancel: () => _prevAnimationController.reverse(),
                onTap: _prevTrack,
                child: Center(
                  child: ScaleTransition(
                    scale: _prevAnimation,
                    child: Icon(Icons.skip_previous, size: 28 * scale),
                  ),
                ),
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
                onTap: () => _playerService.player.playing ? _playerService.player.pause() : _playerService.player.play(),
                child: Center(
                  child: ScaleTransition(
                    scale: _pauseAnimation,
                    child: StreamBuilder<PlayerState>(
                      stream: _playerService.player.playerStateStream,
                      builder: (_, snap) => Icon(
                        (snap.data?.playing ?? false) ? Icons.pause : Icons.play_arrow,
                        size: 28 * scale,
                      ),
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
                child: Center(
                  child: ScaleTransition(
                    scale: _nextAnimation,
                    child: Icon(Icons.skip_next, size: 28 * scale),
                  ),
                ),
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
                child: Center(
                  child: ScaleTransition(
                    scale: _likeAnimation,
                    child: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? effectiveAccent : Colors.grey,
                      size: 24 * scale,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      scale: scale,
    );
  }

  Widget _settingsCard({
    required String title,
    required List<Widget> children,
    required bool glassEnabled,
    required bool isDark,
    required double scale,
  }) {
    return _buildGlassContainer(
      glassEnabled: glassEnabled,
      isDark: isDark,
      borderRadius: BorderRadius.circular(28 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(24 * scale, 20 * scale, 24 * scale, 12 * scale),
              child: Text(title, style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w600, color: Colors.grey)),
            ),
          ...children,
        ],
      ),
      scale: scale,
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
    required double scale,
  }) {
    final effectiveAccent = Theme.of(context).colorScheme.primary.opacity == 0 ? Colors.grey : Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
      leading: Icon(icon, color: effectiveAccent, size: 24 * scale),
      title: Text(title, style: TextStyle(fontSize: 17 * scale, color: titleColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13.5 * scale)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, size: 24 * scale),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: onTap,
    );
  }

  Widget _buildLoadingAnimation(AppLocalizations loc, double scale) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: effectiveAccent),
          SizedBox(height: 20 * scale),
          Text(
            '${loc.loading}...',
            style: TextStyle(
              fontSize: 28 * scale,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppLocalizations loc, bool isDark) {
    final current = _playerService.currentTrack;
    final hasCustomBg = _customBackgroundUrl != null && _customBackgroundUrl!.isNotEmpty;

    return Consumer(
      builder: (context, ref, child) {
        final glassEnabled = ref.watch(glassEnabledProvider);
        final blurEnabled = ref.watch(blurEnabledProvider);
        final scale = ref.watch(scaleProvider);
        final primary = Theme.of(context).colorScheme.primary;
        final effectiveTint = primary.opacity == 0 ? Colors.transparent : primary;
        final effectiveAccent = primary.opacity == 0 ? Colors.grey : primary;

        final backgroundColor = hasCustomBg
            ? Colors.transparent
            : (glassEnabled
                ? Color.alphaBlend(
                    effectiveTint.withOpacity(isDark ? 0.06 : 0.04),
                    isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
                  )
                : (isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA)));

        Widget mainContent = Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 35 * scale, 20 * scale, 10 * scale),
              child: _buildGlassContainer(
                glassEnabled: glassEnabled,
                isDark: isDark,
                borderRadius: BorderRadius.circular(50 * scale),
                child: Padding(
                  padding: EdgeInsets.all(6 * scale),
                  child: TabBar(
                    controller: _tabController,
                    dividerHeight: 0,
                    indicatorPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: primary.opacity == 0 ? Colors.grey : primary,
                      borderRadius: BorderRadius.circular(46 * scale),
                    ),
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                    labelColor: isDark ? Colors.black : Colors.white,
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15 * scale),
                    tabs: [
                      Tab(text: loc.home),
                      Tab(text: loc.myWave),
                      Tab(text: loc.playlists),
                      Tab(text: loc.settings),
                    ],
                  ),
                ),
                scale: scale,
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMainPlayerArea(current, glassEnabled, scale),
                            ),
                            Padding(
                              padding: EdgeInsets.only(right: 20 * scale),
                              child: SizedBox(
                                width: 400 * scale,
                                child: _buildQueuePanel(glassEnabled, scale),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 20 * scale),
                        child: _buildGlassContainer(
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          borderRadius: BorderRadius.circular(30 * scale),
                          child: Row(
                            children: [
                              SizedBox(width: 18 * scale),
                              Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 24 * scale),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 16.5 * scale,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: loc.searchTracks,
                                    hintStyle: TextStyle(
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                      fontSize: 16.5 * scale,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 17 * scale),
                                  ),
                                  onSubmitted: (_) => _searchTracks(),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: 8 * scale),
                                child: ElevatedButton(
                                  onPressed: _searchTracks,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: effectiveAccent,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26 * scale)),
                                    padding: EdgeInsets.symmetric(horizontal: 32 * scale, vertical: 13 * scale),
                                  ),
                                  child: Text(
                                    loc.find,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5 * scale),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          scale: scale,
                        ),
                      ),
                    ],
                  ),

                  _buildMyWaveTab(glassEnabled, scale),

                  _buildPlaylistsTab(glassEnabled, scale),

                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 20 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _settingsCard(
                          title: loc.appearance,
                          children: [
                            _buildThemeSelector(scale),
                            _buildColorSelector(scale),
                            _buildGlassSelector(scale),
                            _buildCustomBackgroundSelector(scale),
                            _buildBlurSelector(scale),
                            _buildScaleSelector(scale),
                          ],
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          scale: scale,
                        ),

                        SizedBox(height: 8 * scale),

                        _settingsCard(
                          title: loc.languageSection,
                          children: [
                            _buildLanguageSelector(scale),
                          ],
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          scale: scale,
                        ),

                        SizedBox(height: 8 * scale),

                        _settingsCard(
                          title: loc.dataAndAccount,
                          children: [
                            _settingsTile(
                              icon: Icons.delete_outline_rounded,
                              title: loc.clearCache,
                              subtitle: loc.clearCacheSubtitle,
                              onTap: _clearCache,
                              scale: scale,
                            ),
                            _settingsTile(
                              icon: Icons.logout_rounded,
                              title: loc.logout,
                              subtitle: loc.logoutSubtitle,
                              titleColor: Colors.red,
                              onTap: _logout,
                              scale: scale,
                            ),
                          ],
                          glassEnabled: glassEnabled,
                          isDark: isDark,
                          scale: scale,
                        ),

                        SizedBox(height: 60 * scale),

                        Center(
                          child: Column(
                            children: [
                              Text(
                                'lizaplayer',
                                style: TextStyle(
                                  fontSize: 15.5 * scale,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.8 * scale,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                'v2.0.5',
                                style: TextStyle(
                                  fontSize: 13 * scale,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 50 * scale),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showMiniPlayer && current != null)
              Padding(
                padding: EdgeInsets.fromLTRB(20 * scale, 10 * scale, 20 * scale, 20 * scale),
                child: _buildMiniPlayer(current, glassEnabled, scale),
              ),
          ],
        );

        final content = hasCustomBg
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      _customBackgroundUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
                      ),
                    ),
                  ),
                  if (blurEnabled)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: const SizedBox(),
                      ),
                    ),
                  mainContent,
                ],
              )
            : mainContent;

        return content;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _isInitialized
            ? _buildMainContent(loc, isDark)
            : Consumer(
                builder: (context, ref, child) {
                  final scale = ref.watch(scaleProvider);
                  return _buildLoadingAnimation(loc, scale);
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    _pauseAnimationController.dispose();
    _prevAnimationController.dispose();
    _nextAnimationController.dispose();
    _likeAnimationController.dispose();
    _waveController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _playerStateSubscription?.cancel();
    super.dispose();
  }
}
