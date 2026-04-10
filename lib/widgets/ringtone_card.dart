import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'audioplayer_sheet.dart';
import '../model/ringtone_model.dart';
import '../services/audio_services.dart';
import '../services/download_services.dart';
import '../services/favourites_service.dart';

class RingtoneCard extends StatefulWidget {
  final Ringtone ringtone;
  final AudioService audioService;

  const RingtoneCard({
    super.key,
    required this.ringtone,
    required this.audioService,
  });

  @override
  State<RingtoneCard> createState() => _RingtoneCardState();
}

class _RingtoneCardState extends State<RingtoneCard>
    with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService();
  final _favouritesService = FavouritesService();

  bool _isFavourite = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  bool _isSettingRingtone = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadInitialState() async {
    final fav = await _favouritesService.isFavourite(widget.ringtone.id);
    final downloaded = await _downloadService
        .isDownloaded(widget.ringtone.title ?? 'ringtone');
    if (mounted) setState(() {
      _isFavourite = fav;
      _isDownloaded = downloaded;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isCurrentlyPlaying =>
      widget.audioService.currentlyPlayingId == widget.ringtone.id &&
          widget.audioService.isPlaying;

  // Tapping the thumbnail opens the full player sheet
  void _openPlayerSheet() {
    AudioPlayerSheet.show(context, widget.ringtone, widget.audioService);
  }

  Future<void> _downloadRingtone() async {
    if (_isDownloading || !widget.ringtone.hasPreview) {
      if (!widget.ringtone.hasPreview) {
        _showSnack('No audio available to download.');
      }
      return;
    }
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    try {
      await _downloadService.downloadRingtone(
        url: widget.ringtone.bestDownloadUrl!,
        fileName: widget.ringtone.title ?? 'ringtone_${widget.ringtone.id}',
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
        });
        _showSnack('Downloaded: ${widget.ringtone.title}');
      }
    } on DownloadException catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        _showSnack(e.message);
      }
    }
  }

  Future<void> _setAsRingtone() async {
    if (_isSettingRingtone) return;
    final file = await _downloadService
        .getDownloadedFile(widget.ringtone.title ?? 'ringtone');
    if (file == null) {
      _showSnack('Please download the track first.');
      return;
    }
    setState(() => _isSettingRingtone = true);
    try {
      await _downloadService.setAsRingtone(
          file, widget.ringtone.title ?? 'Ringtone');
      _showSnack('Set as ringtone: ${widget.ringtone.title}');
    } on DownloadException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _isSettingRingtone = false);
    }
  }

  Future<void> _toggleFavourite() async {
    final isNowFav =
    await _favouritesService.toggleFavourite(widget.ringtone);
    if (mounted) {
      setState(() => _isFavourite = isNowFav);
      _showSnack(
          isNowFav ? 'Added to favourites' : 'Removed from favourites');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: widget.audioService.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = _isCurrentlyPlaying;
        return GestureDetector(
          onTap: _openPlayerSheet, // tap anywhere on card opens player
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: isPlaying
                  ? Border.all(
                  color: Colors.indigo.withOpacity(0.4), width: 1.5)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildThumbnail(isPlaying),
                  const SizedBox(width: 12),
                  Expanded(child: _buildInfo()),
                  _buildActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(bool isPlaying) {
    final hasImage = widget.ringtone.imageUrl != null &&
        widget.ringtone.imageUrl!.isNotEmpty;
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: hasImage
              ? CachedNetworkImage(
            imageUrl: widget.ringtone.imageUrl!,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
            placeholder: (_, __) => _imagePlaceholder(),
            errorWidget: (_, __, ___) => _imagePlaceholder(),
          )
              : _imagePlaceholder(),
        ),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.ringtone.hasPreview
                ? Colors.black.withOpacity(isPlaying ? 0.45 : 0.25)
                : Colors.black.withOpacity(0.12),
          ),
          child: widget.ringtone.hasPreview
              ? (isPlaying
              ? ScaleTransition(
            scale: _pulseAnimation,
            child:
            const Icon(Icons.pause, color: Colors.white, size: 26),
          )
              : const Icon(Icons.play_arrow,
              color: Colors.white, size: 26))
              : Icon(Icons.music_off,
              color: Colors.white.withOpacity(0.6), size: 20),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 58,
    height: 58,
    color: Colors.indigo.shade50,
    child:
    Icon(Icons.music_note, color: Colors.indigo.shade200, size: 24),
  );

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.ringtone.title ?? 'Unknown',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.ringtone.artist != null) ...[
          const SizedBox(height: 3),
          Text(
            widget.ringtone.artist!,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.grey.shade400, size: 12),
            const SizedBox(width: 3),
            Text(
              widget.ringtone.formattedDuration,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            if (!widget.ringtone.hasPreview) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'No preview',
                  style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
        if (widget.ringtone.genre != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.ringtone.genre!,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (_isDownloading) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor:
              const AlwaysStoppedAnimation<Color>(Colors.indigo),
              minHeight: 3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggleFavourite,
          icon: Icon(
            _isFavourite ? Icons.favorite : Icons.favorite_border,
            color: _isFavourite ? Colors.redAccent : Colors.grey.shade400,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(height: 8),
        if (_isDownloaded)
          IconButton(
            onPressed: _isSettingRingtone ? null : _setAsRingtone,
            icon: _isSettingRingtone
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.green.shade400),
            )
                : Icon(Icons.notifications_active,
                color: Colors.green.shade500, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Set as ringtone',
          )
        else
          IconButton(
            onPressed: _isDownloading ? null : _downloadRingtone,
            icon: _isDownloading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.grey.shade400),
            )
                : Icon(Icons.download_rounded,
                color: Colors.grey.shade500, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Download',
          ),
      ],
    );
  }
}