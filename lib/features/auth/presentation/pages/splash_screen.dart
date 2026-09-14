import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../home/presentation/pages/home_screen.dart';
import '../../data/providers/auth_provider.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _databaseBoxName = 'cineverse';
  final _tokenProvider = SecureTokenProvider();

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Le logo apparaît en fondu puis "zoom" légèrement, comme Netflix.
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(_databaseBoxName);
    final token = await _tokenProvider.read();
    final destination = _isValidToken(token)
        ? const HomeScreen()
        : const LoginScreen();

    // On laisse le temps à l'animation de se jouer, comme un vrai splash Netflix.
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  bool _isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiration = payload['exp'];
      return payload is Map<String, dynamic> &&
          expiration is num &&
          expiration > DateTime.now().millisecondsSinceEpoch / 1000;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le dégradé est posé directement sur tout le Scaffold (hors SafeArea)
      // pour qu'il remplisse l'écran en entier, encoche et barres système
      // comprises. Le SafeArea ne s'applique qu'au contenu à l'intérieur.
      backgroundColor: const Color(0xFF000000),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            // Dégradé violet profond, façon Netflix (noir -> violet -> noir).
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF2D0B4E),
                Color(0xFF120024),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Tailles calculées à partir de l'espace réellement disponible,
                // pour rester cohérent sur mobile, tablette, petit écran ou paysage.
                final shortestSide =
                    constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;

                final haloSize = (shortestSide * 0.55).clamp(160.0, 320.0);
                final logoFontSize = (shortestSide * 0.11).clamp(28.0, 48.0);
                final logoLetterSpacing = (shortestSide * 0.015).clamp(
                  3.0,
                  6.0,
                );
                final loaderSize = (shortestSide * 0.07).clamp(22.0, 32.0);
                final horizontalPadding = (constraints.maxWidth * 0.08)
                    .clamp(16.0, 48.0);

                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        children: [
                          // Zone haute flexible : absorbe l'espace en plus sur
                          // les grands écrans sans jamais provoquer d'overflow.
                          const Spacer(flex: 3),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Halo lumineux violet derrière le logo, qui pulse.
                              Opacity(
                                opacity: _glowAnimation.value * 0.6,
                                child: Container(
                                  width: haloSize,
                                  height: haloSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(
                                          0xFF9B5CFF,
                                        ).withValues(alpha: 0.55),
                                        const Color(
                                          0xFF9B5CFF,
                                        ).withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Logo / nom de l'app avec fondu + zoom.
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFFB985FF),
                                              Color(0xFF7B2FF7),
                                            ],
                                          ).createShader(bounds),
                                      child: Text(
                                        'CINEVERSE',
                                        style: TextStyle(
                                          fontSize: logoFontSize,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: logoLetterSpacing,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(flex: 4),
                          // Petit indicateur de chargement discret en bas.
                          FadeTransition(
                            opacity: _glowAnimation,
                            child: SizedBox(
                              width: loaderSize,
                              height: loaderSize,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFB985FF),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.06),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}