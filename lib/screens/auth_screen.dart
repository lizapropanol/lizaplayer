import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lizaplayer/screens/home_screen.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/widgets/custom_title_bar.dart';
import 'package:lizaplayer/l10n/app_localizations.dart';
import 'package:lizaplayer/utils/font_styler.dart';
import 'dart:math';
import 'dart:ui';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with TickerProviderStateMixin, FontStyler {
  late final AnimationController _waveController;
  final TextEditingController _yandexController = TextEditingController();
  final TextEditingController _soundcloudController = TextEditingController();
  bool _isLoading = false;
  final double scale = 0.8;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    );
    _waveController.value = Random().nextDouble();
    _waveController.repeat();
    _loadExistingTokens();
  }

  Future<void> _loadExistingTokens() async {
    final yToken = await TokenStorage.getYandexToken();
    final scId = await TokenStorage.getSoundcloudClientId();
    if (yToken != null) _yandexController.text = yToken;
    if (scId != null && scId != 'khI8ciOiYPX6UVGInQY5zA0zvTkfzuuC') {
      _soundcloudController.text = scId;
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    final yToken = _yandexController.text.trim();
    final scId = _soundcloudController.text.trim();

    if (yToken.isNotEmpty) await TokenStorage.saveYandexToken(yToken);
    if (scId.isNotEmpty) await TokenStorage.saveSoundcloudClientId(scId);
    
    await TokenStorage.saveFirstRunCompleted();
    _navigateToHome(yToken.isNotEmpty ? yToken : null, scId.isNotEmpty ? scId : null);
  }

  Future<void> _skip() async {
    await TokenStorage.saveFirstRunCompleted();
    final yToken = await TokenStorage.getYandexToken();
    final scId = await TokenStorage.getSoundcloudClientId();
    _navigateToHome(yToken, scId);
  }

  void _navigateToHome(String? yToken, String? scId) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            yandexToken: yToken,
            soundcloudClientId: scId,
          ), 
        ),
      );
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _yandexController.dispose();
    _soundcloudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = primaryColor.opacity == 0 ? Colors.white : primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background waves layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => CustomPaint(
                painter: WavePainter(
                  _waveController.value,
                  color: accentColor.withOpacity(0.15),
                ),
              ),
            ),
          ),
          // Blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40 * scale, sigmaY: 40 * scale),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Main content
          Column(
            children: [
              const CustomTitleBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24 * scale),
                    child: Container(
                      width: 500 * scale,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(40 * scale),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5 * scale),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 100 * scale,
                            spreadRadius: 10 * scale,
                          ),
                          BoxShadow(
                            color: accentColor.withOpacity(0.1),
                            blurRadius: 40 * scale,
                          ),
                        ],
                      ),
                      // Clip content to avoid blur bleed on hover
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40 * scale),
                        child: Padding(
                          padding: EdgeInsets.all(48 * scale),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/logo.png',
                                width: 100 * scale,
                                height: 100 * scale,
                                filterQuality: FilterQuality.high,
                              ),
                              SizedBox(height: 24 * scale),
                              Text(
                                loc.welcomeTitle,
                                style: s(TextStyle(
                                  fontSize: 34 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1 * scale,
                                )),
                              ),
                              SizedBox(height: 8 * scale),
                              Text(
                                loc.welcomeSubtitle,
                                textAlign: TextAlign.center,
                                style: s(TextStyle(
                                  fontSize: 15 * scale,
                                  color: Colors.white.withOpacity(0.5),
                                )),
                              ),
                              SizedBox(height: 48 * scale),
                              _buildTokenField(
                                controller: _yandexController,
                                hint: loc.yandexTokenLabel,
                                iconPath: 'assets/yandex_music_icon.svg',
                                accentColor: accentColor,
                              ),
                              SizedBox(height: 16 * scale),
                              _buildTokenField(
                                controller: _soundcloudController,
                                hint: loc.soundcloudIdLabel,
                                iconPath: 'assets/soundcloud_icon.svg',
                                accentColor: accentColor,
                              ),
                              SizedBox(height: 48 * scale),
                              Row(
                                children: [
                                  Expanded(
                                    child: _AuthButton(
                                      label: loc.skipButton,
                                      onPressed: _skip,
                                      isOutlined: true,
                                      accentColor: accentColor,
                                      scale: scale,
                                    ),
                                  ),
                                  SizedBox(width: 16 * scale),
                                  Expanded(
                                    child: _AuthButton(
                                      label: loc.connectButton,
                                      onPressed: _saveAndContinue,
                                      isLoading: _isLoading,
                                      accentColor: accentColor,
                                      scale: scale,
                                    ),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenField({
    required TextEditingController controller,
    required String hint,
    required String iconPath,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        style: s(TextStyle(color: Colors.white, fontSize: 16 * scale)),
        cursorColor: accentColor,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: s(TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15 * scale)),
          prefixIcon: Padding(
            padding: EdgeInsets.all(14 * scale),
            child: SvgPicture.asset(
              iconPath,
              width: 20 * scale,
              height: 20 * scale,
              colorFilter: ColorFilter.mode(accentColor.withOpacity(0.4), BlendMode.srcIn),
            ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 18 * scale),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isOutlined;
  final bool isLoading;
  final Color accentColor;
  final double scale;

  const _AuthButton({
    required this.label,
    required this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
    required this.accentColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16 * scale),
        splashColor: accentColor.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          height: 56 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * scale),
            color: isOutlined ? Colors.transparent : accentColor.withOpacity(0.12),
            border: Border.all(
              color: isOutlined ? Colors.white.withOpacity(0.1) : accentColor.withOpacity(0.4),
              width: 1.5 * scale,
            ),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 20 * scale,
                  height: 20 * scale,
                  child: CircularProgressIndicator(
                    strokeWidth: 2 * scale,
                    color: accentColor,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: isOutlined ? Colors.white.withOpacity(0.6) : Colors.white,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  WavePainter(this.animation, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 8; i++) {
      final path = Path();
      final baseY = size.height * (0.1 + i * 0.12);

      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 10) {
        final wave = sin((x / 100) + animation * 10 + i * 0.8) * 40;
        path.lineTo(x, baseY + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
