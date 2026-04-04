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
                children: [_buildApiKeysSelector(scale, isDark, glassEnabled, loc)],
                glassEnabled: glassEnabled,
                isDark: isDark,
                scale: scale,
                sectionKey: 'integrations',
              ),
              _buildExpandableSection(
                title: loc.appearance,
                icon: Icons.palette_rounded,
                children: [
                  _buildThemeSelector(scale),
                  _buildColorSelector(scale),
                  _buildGlassSelector(scale),
                  _buildCustomBackgroundSelector(scale),
                  _buildCustomTrackCoverSelector(scale),
                  _buildBlurSelector(scale),
                  _buildFreezeOptimizationSelector(scale),
                  _buildScaleSelector(scale)
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
                  _settingsTile(icon: Icons.delete_outline_rounded, title: loc.clearCache, subtitle: loc.clearCacheSubtitle, onTap: _clearCache, scale: scale),
                  _settingsTile(icon: Icons.logout_rounded, title: loc.logout, subtitle: loc.logoutSubtitle, titleColor: Colors.red, onTap: _logout, scale: scale)
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
                                  style: TextStyle(
                                    fontSize: 24 * scale,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0 * scale,
                                    color: isDark ? Colors.white : Colors.black87,
                                    shadows: [
                                      Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10 * scale, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 6 * scale),
                                _buildBadge('v2.3.0', Colors.grey, scale),
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
              SizedBox(height: 60 * scale),
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Text(
                    'Made with ❤️ by lizapropanol',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 50 * scale),
            ],
          ),
        ),
      ),
    );
  }
