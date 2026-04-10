import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tonecraft/model/wallpaper_model.dart';
import 'package:tonecraft/services/wallpapers_api_services.dart';

const _wallpaperChannel = MethodChannel('com.tonecraft/wallpaper');

// ─── Categories shown as chips ─────────────────────────────────────────────
// "All" merges 20 from every tag below it.
// Every other chip fetches exactly 20 of its own tag.
// If you add/remove a tag here, also add/remove it in
// WallpaperApiService.allCategoryTags so the "All" merge stays in sync.
const List<Map<String, String>> kWallpaperCategories = [
  {'label': 'All',          'tag': ''},
  {'label': 'Nature',       'tag': 'nature'},
  {'label': 'Architecture', 'tag': 'architecture'},
  {'label': 'Abstract',     'tag': 'abstract'},
  {'label': 'Space',        'tag': 'space'},
  {'label': 'City',         'tag': 'city'},
  {'label': 'Mountains',    'tag': 'mountains'},
  {'label': 'Ocean',        'tag': 'ocean'},
  {'label': 'Dark',         'tag': 'dark aesthetic'},
  {'label': 'Minimal',      'tag': 'minimalist'},
  {'label': 'Cars',         'tag': 'cars'},
  {'label': 'Animals',      'tag': 'animals'},
];

// ─── Screen ────────────────────────────────────────────────────────────────

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  final _api = WallpaperApiService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Wallpaper> _wallpapers = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _currentKeyword = '';
  String _selectedCategory = ''; // '' = All

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _wallpapers = [];
    });

    try {
      final result = await _buildRequest();
      if (mounted) {
        setState(() {
          _wallpapers = result.wallpapers;
          _isLoading = false;
        });
      }
    } on WallpaperApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    }
  }

  /// "All"  → fetchAllCategories() — 20 per category, merged
  /// search → searchPhotos(keyword) — exactly 20
  /// chip   → searchPhotos(tag)    — exactly 20
  Future<WallpaperSearchResult> _buildRequest() {
    final keyword = _currentKeyword.trim();
    if (keyword.isNotEmpty) {
      return _api.searchPhotos(query: keyword);
    }
    if (_selectedCategory.isEmpty) {
      return _api.fetchAllCategories();
    }
    return _api.searchPhotos(query: _selectedCategory);
  }

  void _onSearch(String keyword) {
    _currentKeyword = keyword.trim();
    _selectedCategory = '';
    _fetch();
  }

  void _onCategorySelected(String tag) {
    if (_selectedCategory == tag && _currentKeyword.isEmpty) return;
    _currentKeyword = '';
    _searchController.clear();
    setState(() => _selectedCategory = tag);
    _fetch();
  }

  void _openPreview(Wallpaper wallpaper) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) =>
            _WallpaperPreviewScreen(wallpaper: wallpaper, api: _api),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF12121F),
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wallpaper_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Tone',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'Craft',
                              style: TextStyle(
                                color: Color(0xFFBF5AF2),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your sound. Your style.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'EXPLORE',
                style: TextStyle(
                  color: const Color(0xFF7070A0),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            _WallpaperDrawerItem(
              icon: Icons.music_note_rounded,
              label: 'Ringtones',
              isActive: false,
              accentColor: const Color(0xFFBF5AF2),
              onTap: () {
                // Close drawer then go back to home (ringtones) screen
                Navigator.of(context).pop(); // close drawer
                Navigator.of(context).pop(); // go back to HomeScreen
              },
            ),
            _WallpaperDrawerItem(
              icon: Icons.wallpaper_rounded,
              label: 'Wallpapers',
              isActive: true,
              accentColor: const Color(0xFF0AE8F0),
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFFBF5AF2), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Developed by Muhammad Atif Javeid',
                    style: TextStyle(
                        color: Color(0xFF7070A0), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: _WallpaperHamburgerIcon(),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            // Logo mark — indigo gradient square matching home screen style
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.wallpaper_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Wall',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  TextSpan(
                    text: 'papers',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search wallpapers...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade400),
            onPressed: () {
              _searchController.clear();
              _onSearch('');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
          ),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        onSubmitted: _onSearch,
        textInputAction: TextInputAction.search,
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: kWallpaperCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = kWallpaperCategories[i];
          final tag = cat['tag']!;
          final label = cat['label']!;
          final selected =
              _selectedCategory == tag && _currentKeyword.isEmpty;
          return GestureDetector(
            onTap: () => _onCategorySelected(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.indigo : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                  selected ? Colors.indigo : const Color(0xFF2A2A45),
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
                    : [],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color:
                  selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildShimmerGrid();
    if (_errorMessage != null) return _buildError();
    if (_wallpapers.isEmpty) {
      return Center(
        child: Text('No wallpapers found.',
            style:
            TextStyle(color: Colors.grey.shade500, fontSize: 15)),
      );
    }
    return _buildGrid();
  }

  Widget _buildGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: _wallpapers.length,
      itemBuilder: (context, index) => _WallpaperCard(
        wallpaper: _wallpapers[index],
        onTap: () => _openPreview(_wallpapers[index]),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: 10,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid card ─────────────────────────────────────────────────────────────

class _WallpaperCard extends StatelessWidget {
  final Wallpaper wallpaper;
  final VoidCallback onTap;

  const _WallpaperCard({required this.wallpaper, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Color(wallpaper.colorValue)),
            CachedNetworkImage(
              imageUrl: wallpaper.thumbUrl ?? wallpaper.regularUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: Color(wallpaper.colorValue)),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF1A1A2E),
                child: Icon(Icons.broken_image,
                    color: Colors.grey.shade400, size: 32),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Text(
                  wallpaper.photographerName ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite,
                        color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text('${wallpaper.likes}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer card ──────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1.5, 0),
              end: Alignment(1.5 * _ctrl.value + 0.5, 0),
              colors: const [
                Color(0xFF1A1A2E),
                Color(0xFF252540),
                Color(0xFF1A1A2E),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Full-screen preview ───────────────────────────────────────────────────

class _WallpaperPreviewScreen extends StatefulWidget {
  final Wallpaper wallpaper;
  final WallpaperApiService api;

  const _WallpaperPreviewScreen(
      {required this.wallpaper, required this.api});

  @override
  State<_WallpaperPreviewScreen> createState() =>
      _WallpaperPreviewScreenState();
}

class _WallpaperPreviewScreenState extends State<_WallpaperPreviewScreen> {
  bool _downloading = false;
  bool _settingWallpaper = false;

  Future<void> _downloadAndSave() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final loc = widget.wallpaper.downloadLocation;
      if (loc != null) await widget.api.triggerDownload(loc);

      final url = widget.wallpaper.fullUrl ??
          widget.wallpaper.regularUrl ??
          widget.wallpaper.rawUrl!;
      final bytes = await widget.api.downloadImageBytes(url);

      final tmp = await getTemporaryDirectory();
      final fileName =
          'ringle_${widget.wallpaper.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tmpFile = File('${tmp.path}/$fileName');
      await tmpFile.writeAsBytes(bytes);

      await _wallpaperChannel.invokeMethod('saveToGallery', {
        'path': tmpFile.path,
        'fileName': fileName,
      });

      _snack('Saved to gallery ✓');
    } on PlatformException catch (e) {
      _snack('Save failed: ${e.message}');
    } catch (e) {
      _snack('Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _setWallpaper(int type) async {
    if (_settingWallpaper) return;
    setState(() => _settingWallpaper = true);
    try {
      final url = widget.wallpaper.fullUrl ??
          widget.wallpaper.regularUrl ??
          widget.wallpaper.rawUrl!;
      final bytes = await widget.api.downloadImageBytes(url);

      final tmp = await getTemporaryDirectory();
      final tmpFile =
      File('${tmp.path}/wp_set_${widget.wallpaper.id}.jpg');
      await tmpFile.writeAsBytes(bytes);

      await _wallpaperChannel.invokeMethod('setWallpaper', {
        'path': tmpFile.path,
        'type': type,
      });

      await tmpFile.delete();
      final loc = widget.wallpaper.downloadLocation;
      if (loc != null) await widget.api.triggerDownload(loc);

      final label = type == 1
          ? 'Home screen'
          : type == 2
          ? 'Lock screen'
          : 'Home & Lock screen';
      _snack('$label wallpaper set ✓');
    } on PlatformException catch (e) {
      _snack('Could not set wallpaper: ${e.message}');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _settingWallpaper = false);
    }
  }

  void _showSetOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set wallpaper as...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _sheetOption(
                  icon: Icons.home_rounded,
                  label: 'Home Screen',
                  onTap: () { Navigator.pop(context); _setWallpaper(1); }),
              _sheetOption(
                  icon: Icons.lock_rounded,
                  label: 'Lock Screen',
                  onTap: () { Navigator.pop(context); _setWallpaper(2); }),
              _sheetOption(
                  icon: Icons.smartphone_rounded,
                  label: 'Home & Lock Screen',
                  onTap: () { Navigator.pop(context); _setWallpaper(3); }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF818CF8), size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right,
                color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallpaper;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Color(w.colorValue),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: w.regularUrl ?? w.fullUrl ?? '',
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Color(w.colorValue)),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade900,
              child: const Icon(Icons.broken_image,
                  color: Colors.white38, size: 64),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 40, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (w.photographerName != null) ...[
                    Row(children: [
                      const Icon(Icons.person_outline,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 5),
                      Text(w.photographerName!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                  ],
                  Row(children: [
                    if (w.width != null && w.height != null) ...[
                      _badge('${w.width}×${w.height}'),
                      const SizedBox(width: 8),
                    ],
                    _badge('❤ ${w.likes}'),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.download_rounded,
                          label: 'Download',
                          loading: _downloading,
                          onTap: _downloadAndSave,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.wallpaper_rounded,
                          label: 'Set Wallpaper',
                          loading: _settingWallpaper,
                          color: const Color(0xFF059669),
                          onTap: _showSetOptions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () {
                    SystemChrome.setSystemUIOverlayStyle(
                      const SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.dark,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 38, height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(text,
        style:
        const TextStyle(color: Colors.white70, fontSize: 11)),
  );
}

// ─── Action button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color != null
        ? [color!, Color.lerp(color!, Colors.black, 0.2)!]
        : [const Color(0xFF6366F1), const Color(0xFF4338CA)];

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bg),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (color ?? Colors.indigo).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
// ─── Hamburger icon (matches HomeScreen style) ─────────────────────────────

class _WallpaperHamburgerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 15,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1), // indigo accent line
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

// ─── Drawer item (matches HomeScreen _DrawerItem style) ────────────────────

class _WallpaperDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _WallpaperDrawerItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: accentColor.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: accentColor.withOpacity(0.25))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? accentColor : const Color(0xFF7070A0),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? accentColor : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
