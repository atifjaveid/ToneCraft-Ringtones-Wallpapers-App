import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

// ─── Data ──────────────────────────────────────────────────────────────────

class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color glowColor;
  final IconData icon;

  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.glowColor,
    required this.icon,
  });
}

const _pages = [
  _OnboardPage(
    emoji: '🎵',
    title: 'Craft Your\nPerfect Tone',
    subtitle: 'Explore thousands of ringtones across every genre. From ambient chill to hard-hitting drops — your phone, your vibe.',
    accentColor: Color(0xFFBF5AF2),
    glowColor: Color(0x55BF5AF2),
    icon: Icons.music_note_rounded,
  ),
  _OnboardPage(
    emoji: '🖼️',
    title: 'Walls That\nSpeak Loud',
    subtitle: 'Hand-picked wallpapers from nature, architecture, abstract art, and beyond. Your screen deserves to be extraordinary.',
    accentColor: Color(0xFF0AE8F0),
    glowColor: Color(0x550AE8F0),
    icon: Icons.wallpaper_rounded,
  ),
  _OnboardPage(
    emoji: '❤️',
    title: 'Save Your\nFavorites',
    subtitle: 'Heart what you love. Your collection, always at your fingertips — offline and perfectly organized.',
    accentColor: Color(0xFFFF6B6B),
    glowColor: Color(0x55FF6B6B),
    icon: Icons.favorite_rounded,
  ),
];

// ─── Screen ────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _entryController;

  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatAnim = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _entryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _entryController.reset();
    _entryController.forward();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tonecraft_onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: Stack(
        children: [
          // ── Animated background orbs ──────────────────────────────────
          _buildBackgroundOrbs(page, size),

          // ── Page content ──────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (_, i) => _buildPageContent(_pages[i], size),
          ),

          // ── Bottom controls ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(page),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs(_OnboardPage page, Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _floatController]),
      builder: (_, __) {
        return Stack(
          children: [
            // Large primary orb top-right
            Positioned(
              top: -60 + _floatAnim.value,
              right: -80,
              child: Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        page.accentColor.withOpacity(0.35),
                        page.accentColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Smaller accent orb bottom-left
            Positioned(
              bottom: 200 - _floatAnim.value,
              left: -60,
              child: Transform.scale(
                scale: 1.1 - (_pulseAnim.value - 1.0),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        page.accentColor.withOpacity(0.2),
                        page.accentColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Grid dot pattern overlay
            CustomPaint(
              size: Size(size.width, size.height),
              painter: _DotGridPainter(
                color: page.accentColor.withOpacity(0.06),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageContent(_OnboardPage page, Size size) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // ── Hero icon with glow ──────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseController, _floatController]),
                  builder: (_, __) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnim.value * 0.5),
                      child: Transform.scale(
                        scale: _pulseAnim.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    page.glowColor,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Inner glass circle
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: page.accentColor.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: page.accentColor.withOpacity(0.3),
                                    blurRadius: 40,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  page.emoji,
                                  style: const TextStyle(fontSize: 52),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 56),

                // ── Page indicator ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isActive
                            ? page.accentColor
                            : Colors.white.withOpacity(0.2),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: page.accentColor.withOpacity(0.5),
                                  blurRadius: 8,
                                )
                              ]
                            : [],
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                // ── Title ────────────────────────────────────────────────
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -1.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: page.accentColor.withOpacity(0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Subtitle ─────────────────────────────────────────────
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.65,
                    color: Colors.white.withOpacity(0.55),
                    letterSpacing: 0.1,
                  ),
                ),

                const Spacer(),
                const SizedBox(height: 130), // space for bottom controls
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(_OnboardPage page) {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0A14).withOpacity(0),
            const Color(0xFF0A0A14),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main CTA button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 58,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    page.accentColor,
                    page.accentColor.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: page.accentColor.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _nextPage,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'Start Crafting' : 'Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Skip link ──────────────────────────────────────────────────
          if (!isLast)
            TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dot grid background painter ──────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 28.0;
    const radius = 1.2;
    final paint = Paint()..color = color;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
