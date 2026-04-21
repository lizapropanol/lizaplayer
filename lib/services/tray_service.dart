import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lizaplayer/services/player_service.dart';

class TrayService with TrayListener, WindowListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  final PlayerService _playerService = PlayerService();
  StreamSubscription? _trackSub;
  StreamSubscription? _playSub;

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/logo.png',
    );
    
    await _updateMenu();

    _trackSub?.cancel();
    _trackSub = _playerService.trackStream.listen((_) => _updateMenu());
    _playSub?.cancel();
    _playSub = _playerService.playingStream.listen((_) => _updateMenu());
  }

  Future<void> _updateMenu() async {
    final track = _playerService.currentTrack;
    final isPlaying = _playerService.playing;

    final menu = Menu(
      items: [
        if (track != null) ...[
          MenuItem(
            key: 'current_track',
            label: '${track.title} - ${track.artistName}',
            disabled: true,
          ),
          MenuItem.separator(),
        ],
        MenuItem(
          key: 'prev_track',
          label: 'Previous',
        ),
        MenuItem(
          key: 'toggle_play',
          label: isPlaying ? 'Pause' : 'Play',
        ),
        MenuItem(
          key: 'next_track',
          label: 'Next',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'show_window',
          label: 'Show',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
        windowManager.focus();
        break;
      case 'exit_app':
        exit(0);
        break;
      case 'toggle_play':
        if (_playerService.playing) {
          _playerService.pause();
        } else {
          _playerService.play();
        }
        break;
      case 'next_track':
        _playerService.next();
        break;
      case 'prev_track':
        _playerService.previous();
        break;
    }
  }

  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    } else {
      exit(0);
    }
  }
}
