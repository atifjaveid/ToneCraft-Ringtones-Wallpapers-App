import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tonecraft/model/ringtone_model.dart';
import 'package:tonecraft/screens/wallpaper_screen.dart';
import 'package:tonecraft/services/audio_services.dart';
import 'package:tonecraft/services/favourites_service.dart';
import 'package:tonecraft/services/ringtone_api_services.dart';
import 'package:tonecraft/widgets/ringtone_card.dart';

// ─── Genre categories ──────────────────────────────────────────────────────

const List<Map<String, dynamic>> kCategories = [
  {'label': 'All',        'tag': '',          'icon': '🎵'},
  {'label': 'Pop',        'tag': 'pop',        'icon': '⭐'},
  {'label': 'Rock',       'tag': 'rock',       'icon': '🎸'},
  {'label': 'Electronic', 'tag': 'electronic', 'icon': '⚡'},
  {'label': 'Hip-Hop',    'tag': 'hiphop',     'icon': '🎤'},
  {'label': 'Jazz',       'tag': 'jazz',       'icon': '🎷'},
  {'label': 'Classical',  'tag': 'classical',  'icon': '🎻'},
  {'label': 'Ambient',    'tag': 'ambient',    'icon': '🌙'},
  {'label': 'Acoustic',   'tag': 'acoustic',   'icon': '🎼'},
  {'label': 'Metal',      'tag': 'metal',      'icon': '🤘'},
  {'label': 'R&B',        'tag': 'rnb',        'icon': '💜'},
];

// ─── App color constants ───────────────────────────────────────────────────

const kBg           = Color(0xFF0A0A14);
const kSurface      = Color(0xFF12121F);
const kSurface2     = Color(0xFF1A1A2E);
const kPrimary      = Color(0xFFBF5AF2);   // violet
const kSecondary    = Color(0xFF0AE8F0);   // cyan
const kAccentRed    = Color(0xFFFF6B6B);
const kText         = Colors.white;
const kTextMuted    = Color(0xFF7070A0);

// ─── Home screen ──────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _apiService       = ApiService();
  final _audioService     = AudioService();
  final _favouritesService = FavouritesService();

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  late TabController _tabController;

  List<Ringtone> _ringtones   = [];
  List<Ringtone> _favourites  = [];

  bool    _isLoading     = false;
  bool    _isLoadingMore = false;
  bool    _hasMore       = true;
  String? _errorMessage;

  int    _currentPage    = 1;
  String _currentKeyword = '';
  String _selectedGenre  = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _fetchRingtones(reset: true);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    if (_tabController.index == 1) _loadFavourites();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _tabController.index == 0) {
      _fetchMore();
    }
  }

  Future<void> _fetchRingtones({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _isLoading    = true;
        _errorMessage = null;
        _ringtones    = [];
        _currentPage  = 1;
        _hasMore      = true;
      });
    }
    try {
      final result = await _apiService.searchRingtones(
        keyword: _currentKeyword,
        page:    _currentPage,
        genre:   _selectedGenre,
      );
      if (mounted) {
        setState(() {
          _ringtones = result.ringtones;
          _hasMore   = _ringtones.length < result.total;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading    = false;
        });
      }
    }
  }

  Future<void> _fetchMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _apiService.searchRingtones(
        keyword: _currentKeyword,
        page:    _currentPage + 1,
        genre:   _selectedGenre,
      );
      if (mounted) {
        setState(() {
          _currentPage++;
          _ringtones.addAll(result.ringtones);
          _hasMore       = _ringtones.length < result.total;
          _isLoadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _loadFavourites() async {
    final favs = await _favouritesService.getFavourites();
    if (mounted) setState(() => _favourites = favs);
  }

  void _onSearch(String keyword) {
    _audioService.stop();
    _currentKeyword = keyword.trim();
    _fetchRingtones(reset: true);
  }

  void _onCategorySelected(String tag) {
    if (_selectedGenre == tag) return;
    _audioService.stop();
    setState(() => _selectedGenre = tag);
    _fetchRingtones(reset: true);
  }

  void _goToWallpapers(BuildContext drawerCtx) {
    Navigator.of(drawerCtx).pop();
    _audioService.stop();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const WallpaperScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _audioService.stop();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBrowseTab(),
          _buildFavouritesTab(),
        ],
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kBg,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: _HamburgerIcon(),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          _LogoMark(),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Tone',
                  style: TextStyle(
                    color: kText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    fontFamily: 'Outfit',
                  ),
                ),
                TextSpan(
                  text: 'Craft',
                  style: TextStyle(
                    color: kPrimary,
                    fontSize: 24,
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
      actions: const [SizedBox(width: 4)],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: UnderlineTabIndicator(
              borderSide: const BorderSide(color: kPrimary, width: 3),
              borderRadius: BorderRadius.circular(2),
            ),
            labelColor: kPrimary,
            unselectedLabelColor: kTextMuted,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
            tabs: const [
              Tab(text: 'Browse'),
              Tab(text: 'Favourites'),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Drawer ────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kSurface,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LogoMark(size: 48, iconSize: 24),
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
                                    color: kText,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                TextSpan(
                                  text: 'Craft',
                                  style: TextStyle(
                                    color: kPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    fontFamily: 'Outfit',
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
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
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
                  color: kTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            _DrawerItem(
              icon: Icons.music_note_rounded,
              label: 'Ringtones',
              isActive: true,
              accentColor: kPrimary,
              onTap: () => Navigator.of(context).pop(),
            ),

            Builder(
              builder: (drawerCtx) => _DrawerItem(
                icon: Icons.wallpaper_rounded,
                label: 'Wallpapers',
                isActive: false,
                accentColor: kSecondary,
                onTap: () => _goToWallpapers(drawerCtx),
              ),
            ),

            const Spacer(),

            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: kPrimary, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Developed by Muhammad Atif Javeid',
                    style: TextStyle(
                      color: kTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tabs ──────────────────────────────────────────────────────────────

  Widget _buildBrowseTab() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryChips(),
        Expanded(
          child: _isLoading
              ? _buildShimmerList()
              : _errorMessage != null
                  ? _buildError()
                  : _ringtones.isEmpty
                      ? _buildEmpty('No tracks found.\nTry a different genre or search.')
                      : _buildRingtoneList(_ringtones),
        ),
      ],
    );
  }

  Widget _buildFavouritesTab() {
    if (_favourites.isEmpty) {
      return _buildEmpty(
          'No favourites yet.\nTap ♥ on any track to save it here.');
    }
    return _buildRingtoneList(_favourites, showLoadMore: false);
  }

  // ─── Search bar ────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: kText, fontFamily: 'Outfit'),
          cursorColor: kPrimary,
          decoration: InputDecoration(
            hintText: 'Search tracks, artists...',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontFamily: 'Outfit',
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withOpacity(0.3),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: kSurface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kPrimary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          onSubmitted: _onSearch,
          textInputAction: TextInputAction.search,
          onChanged: (val) => setState(() {}),
        ),
      ),
    );
  }

  // ─── Category chips ────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat      = kCategories[i];
          final tag      = cat['tag'] as String;
          final label    = cat['label'] as String;
          final emoji    = cat['icon'] as String;
          final selected = _selectedGenre == tag;

          return GestureDetector(
            onTap: () => _onCategorySelected(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? kPrimary.withOpacity(0.15) : kSurface2,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? kPrimary.withOpacity(0.7)
                      : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: kPrimary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? kPrimary : kTextMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Lists ─────────────────────────────────────────────────────────────

  Widget _buildRingtoneList(List<Ringtone> ringtones,
      {bool showLoadMore = true}) {
    return ListView.builder(
      controller: showLoadMore ? _scrollController : null,
      padding: const EdgeInsets.only(bottom: 32, top: 8),
      itemCount: ringtones.length + (showLoadMore && _isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == ringtones.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: kPrimary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          );
        }
        return RingtoneCard(
          ringtone:     ringtones[index],
          audioService: _audioService,
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: kSurface2,
      highlightColor: const Color(0xFF2A2A40),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 8,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 82,
          decoration: BoxDecoration(
            color: kSurface2,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kAccentRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: kAccentRed.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: kAccentRed,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'Something went wrong.',
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 15,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => _fetchRingtones(reset: true),
              icon: const Icon(Icons.refresh_rounded, color: kPrimary),
              label: const Text(
                'Try again',
                style: TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: kPrimary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: kPrimary.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              color: kTextMuted.withOpacity(0.4),
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 15,
                height: 1.6,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo mark ─────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  final double size;
  final double iconSize;

  const _LogoMark({this.size = 36, this.iconSize = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimary, Color(0xFF7B2FBE)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

// ─── Hamburger icon ────────────────────────────────────────────────────────

class _HamburgerIcon extends StatelessWidget {
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
            color: kText,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 15,
          height: 2,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

// ─── Drawer item ───────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final bool       isActive;
  final Color      accentColor;
  final VoidCallback onTap;

  const _DrawerItem({
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
                    color: isActive ? accentColor : kTextMuted,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? accentColor : kText,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                    fontFamily: 'Outfit',
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 6,
                        )
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
