import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../model/ringtone_model.dart';
import '../services/audio_services.dart';

/// Full-screen audio player card with amplitude-driven waveform.
/// Call [AudioPlayerSheet.show] to push the route.
class AudioPlayerSheet extends StatefulWidget {
  final Ringtone ringtone;
  final AudioService audioService;

  const AudioPlayerSheet({
    super.key,
    required this.ringtone,
    required this.audioService,
  });

  static Future<void> show(
      BuildContext context,
      Ringtone ringtone,
      AudioService audioService,
      ) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => AudioPlayerSheet(
          ringtone: ringtone,
          audioService: audioService,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet>
    with TickerProviderStateMixin {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isDragging = false;
  double _dragProgress = 0;

  late AnimationController _waveController;
  late AnimationController _albumPulseController;
  late Animation<double> _albumScale;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _albumPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _albumScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _albumPulseController, curve: Curves.easeInOut),
    );

    _isPlaying =
        widget.audioService.currentlyPlayingId == widget.ringtone.id &&
            widget.audioService.isPlaying;

    if (_isPlaying) _albumPulseController.repeat(reverse: true);

    widget.audioService.positionStream.listen((pos) {
      if (mounted && !_isDragging) setState(() => _position = pos);
    });

    widget.audioService.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    widget.audioService.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing =
          widget.audioService.currentlyPlayingId == widget.ringtone.id &&
              state == PlayerState.playing;
      setState(() => _isPlaying = playing);
      if (playing) {
        _albumPulseController.repeat(reverse: true);
      } else {
        _albumPulseController.stop();
        _albumPulseController.animateTo(0);
      }
    });

    if (!_isPlaying && widget.ringtone.hasPreview) {
      Future.microtask(_togglePlay);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _albumPulseController.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!widget.ringtone.hasPreview) return;
    await widget.audioService.togglePlay(
      ringtoneId: widget.ringtone.id,
      previewUrl: widget.ringtone.previewUrl!,
    );
    if (mounted) setState(() {});
  }

  Future<void> _seekToRatio(double ratio) async {
    if (_duration == Duration.zero) return;
    final ms = (_duration.inMilliseconds * ratio.clamp(0.0, 1.0)).round();
    await widget.audioService.seekTo(Duration(milliseconds: ms));
  }

  double get _progress {
    if (_isDragging) return _dragProgress;
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _closePlayer() async {
    await widget.audioService.stop();
     if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await widget.audioService.stop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PlayerCard(
              ringtone: widget.ringtone,
              isPlaying: _isPlaying,
              progress: _progress,
              position: _position,
              duration: _duration,
              waveController: _waveController,
              albumScale: _albumScale,
              onTogglePlay: _togglePlay,
              onClose: _closePlayer,
              onSeekStart: (ratio) {
                setState(() {
                  _isDragging = true;
                  _dragProgress = ratio;
                });
              },
              onSeekUpdate: (ratio) {
                setState(() => _dragProgress = ratio);
              },
              onSeekEnd: (ratio) async {
                await _seekToRatio(ratio);
                setState(() => _isDragging = false);
              },
              onSkipBack: () => _seekToRatio(
                (_position.inMilliseconds - 10000) /
                    math.max(1, _duration.inMilliseconds),
              ),
              onSkipForward: () => _seekToRatio(
                (_position.inMilliseconds + 10000) /
                    math.max(1, _duration.inMilliseconds),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Card
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Ringtone ringtone;
  final bool isPlaying;
  final double progress;
  final Duration position;
  final Duration duration;
  final AnimationController waveController;
  final Animation<double> albumScale;
  final VoidCallback onTogglePlay;
  final VoidCallback onClose;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;

  const _PlayerCard({
    required this.ringtone,
    required this.isPlaying,
    required this.progress,
    required this.position,
    required this.duration,
    required this.waveController,
    required this.albumScale,
    required this.onTogglePlay,
    required this.onClose,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.15),
            blurRadius: 60,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Subtle radial glow behind album art
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withOpacity(0.18),
                      Colors.transparent,
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top bar
                  Row(
                    children: [
                      _iconBtn(
                        Icons.keyboard_arrow_down_rounded,
                        onClose,
                        size: 28,
                      ),
                      const Spacer(),
                      Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40), // balance
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Album art
                  ScaleTransition(
                    scale: albumScale,
                    child: _AlbumArt(imageUrl: ringtone.imageUrl),
                  ),

                  const SizedBox(height: 24),

                  // Title & artist
                  Text(
                    ringtone.title ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ringtone.artist ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // ── Waveform ──────────────────────────────────────────────
                  _WaveformSeekbar(
                    peaks: ringtone.waveformPeaks,
                    progress: progress,
                    isPlaying: isPlaying,
                    waveController: waveController,
                    onSeekStart: onSeekStart,
                    onSeekUpdate: onSeekUpdate,
                    onSeekEnd: onSeekEnd,
                  ),

                  const SizedBox(height: 8),

                  // Time labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _timeLabel(_fmt(position)),
                        _timeLabel(_fmt(duration)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _iconBtn(Icons.replay_10_rounded, onSkipBack, size: 30),
                      const SizedBox(width: 20),
                      _PlayButton(isPlaying: isPlaying, onTap: onTogglePlay),
                      const SizedBox(width: 20),
                      _iconBtn(Icons.forward_10_rounded, onSkipForward, size: 30),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeLabel(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withOpacity(0.35),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap, {double size = 24}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white70, size: size),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Waveform seekbar — amplitude-driven bar heights
// ─────────────────────────────────────────────────────────────────────────────

class _WaveformSeekbar extends StatelessWidget {
  final List<int> peaks;
  final double progress;
  final bool isPlaying;
  final AnimationController waveController;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;

  const _WaveformSeekbar({
    required this.peaks,
    required this.progress,
    required this.isPlaying,
    required this.waveController,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  double _xToRatio(double localX, double width) =>
      (localX / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragStart: (d) =>
              onSeekStart(_xToRatio(d.localPosition.dx, width)),
          onHorizontalDragUpdate: (d) =>
              onSeekUpdate(_xToRatio(d.localPosition.dx, width)),
          onHorizontalDragEnd: (d) => onSeekEnd(progress),
          onTapDown: (d) {
            final ratio = _xToRatio(d.localPosition.dx, width);
            onSeekStart(ratio);
            onSeekEnd(ratio);
          },
          child: AnimatedBuilder(
            animation: waveController,
            builder: (_, __) => CustomPaint(
              painter: _AmplitudeWavePainter(
                peaks: peaks,
                progress: progress,
                isPlaying: isPlaying,
                animValue: waveController.value,
              ),
              size: Size(width, 80),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amplitude wave painter — bar height ∝ peak amplitude
// ─────────────────────────────────────────────────────────────────────────────

class _AmplitudeWavePainter extends CustomPainter {
  final List<int> peaks;
  final double progress;
  final bool isPlaying;
  final double animValue;

  // Precomputed fake peaks for tracks without waveform data
  static final List<double> _fakePeaks = _buildFakePeaks();

  static List<double> _buildFakePeaks() {
    const count = 60;
    final rng = math.Random(42);
    // Smooth random walk that feels musical
    final raw = List.generate(count, (i) {
      final base = math.sin(i * 0.18) * 0.3 +
          math.sin(i * 0.07) * 0.4 +
          rng.nextDouble() * 0.3;
      return base.clamp(0.0, 1.0) as double;
    });
    // Normalise to [0.08 … 1.0]
    final max = raw.reduce(math.max);
    return raw.map((v) => 0.08 + (v / max) * 0.92).toList();
  }

  _AmplitudeWavePainter({
    required this.peaks,
    required this.progress,
    required this.isPlaying,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hasPeaks = peaks.isNotEmpty;
    final barCount = hasPeaks ? math.min(peaks.length, 60) : _fakePeaks.length;

    // Normalize real peaks
    double maxPeak = 1;
    if (hasPeaks) {
      maxPeak = peaks.reduce(math.max).toDouble();
      if (maxPeak == 0) maxPeak = 1;
    }

    final totalGap = size.width * 0.30; // 30% of width is gaps
    final barWidth = (size.width - totalGap) / barCount;
    final gap = totalGap / barCount;
    final minBarH = 3.0;

    final playedPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF818CF8),
          const Color(0xFF4F46E5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final unplayedPaint = Paint()
      ..color = Colors.white.withOpacity(0.18);

    final playedGlowPaint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = 0; i < barCount; i++) {
      // Raw amplitude 0..1
      double amplitude;
      if (hasPeaks) {
        final peakIndex = (i / barCount * peaks.length).floor();
        amplitude = peaks[peakIndex] / maxPeak;
      } else {
        amplitude = _fakePeaks[i];
      }

      // Clamp minimum so even silent bars are visible
      amplitude = amplitude.clamp(0.06, 1.0);

      // Breathing animation on playing bars
      if (isPlaying) {
        // Each bar gets a small phase offset so the wave ripples
        final phase = (animValue * 2 * math.pi) - (i * 0.12);
        final breathe = math.sin(phase) * 0.08 * amplitude;
        amplitude = (amplitude + breathe).clamp(0.04, 1.0);
      }

      // Bar height is strictly proportional to amplitude
      final barH = math.max(minBarH, amplitude * size.height);
      final x = i * (barWidth + gap);
      final y = (size.height - barH) / 2; // centred vertically

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        Radius.circular(barWidth / 2),
      );

      final ratio = i / barCount;
      final isPlayed = ratio <= progress;

      if (isPlayed) {
        // Glow behind played bars
        canvas.drawRRect(rect, playedGlowPaint);
        canvas.drawRRect(rect, playedPaint);
      } else {
        canvas.drawRRect(rect, unplayedPaint);
      }
    }

    // Playhead needle
    if (progress > 0) {
      final needleX = progress * size.width;
      final needlePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(needleX, 0),
        Offset(needleX, size.height),
        needlePaint,
      );
      // Needle dot
      canvas.drawCircle(
        Offset(needleX, size.height / 2),
        4,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_AmplitudeWavePainter old) =>
      old.progress != progress ||
          old.isPlaying != isPlaying ||
          old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Play / Pause button
// ─────────────────────────────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(isPlaying ? 0.6 : 0.3),
              blurRadius: isPlaying ? 24 : 12,
              spreadRadius: isPlaying ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Album art
// ─────────────────────────────────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final String? imageUrl;

  const _AlbumArt({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: hasImage
            ? CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF1E1B4B),
    child: const Icon(
      Icons.music_note_rounded,
      color: Color(0xFF4F46E5),
      size: 56,
    ),
  );
}