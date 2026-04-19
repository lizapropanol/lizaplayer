import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/logo.png' : 'assets/logo.png',
    );
    
    final menu = Menu(
      items: [
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
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      exit(0);
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
