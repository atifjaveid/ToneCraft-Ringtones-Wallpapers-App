# ToneCraft 🎵

A beautifully crafted Flutter app for discovering, previewing, and setting **ringtones** and **wallpapers**. ToneCraft features a dark-themed UI with violet/cyan accents, animated onboarding, waveform-driven audio playback, favourites persistence, and one-tap wallpaper setting — all powered by the **Jamendo** and **Unsplash** APIs.

---

## Features

### Ringtones
- Browse thousands of tracks from the Jamendo API with infinite scroll pagination
- Filter by genre: Pop, Rock, Electronic, Hip-Hop, Jazz, Classical, Ambient, Acoustic, Metal, R&B
- Search tracks and artists by keyword
- Preview any track with an in-app full-screen audio player
- Animated amplitude-driven waveform seekbar with drag-to-seek
- Download tracks to device storage (MP3)
- Set any downloaded track as the system ringtone (Android)
- Save favourites locally — persisted across sessions via SharedPreferences

### Wallpapers
- Browse HD photos from the Unsplash API across 11 categories: Nature, Architecture, Abstract, Space, City, Mountains, Ocean, Dark, Minimal, Cars, Animals
- "All" tab merges 20 photos from every category in parallel
- Search wallpapers by keyword
- Full-screen preview with photographer credit and resolution badge
- Download wallpaper to gallery
- Set wallpaper as Home screen, Lock screen, or both (Android via MethodChannel)

### Onboarding
- 3-page animated onboarding flow shown only on first launch
- Animated background orbs, floating emoji icons, and dot-grid overlay
- Onboarding completion saved to SharedPreferences — never shown again

---

## Screens

| Screen | Description |
|--------|-------------|
| `OnboardingScreen` | 3-page intro shown on first launch only |
| `HomeScreen` | Main screen with Browse and Favourites tabs, genre chips, search, and ringtone list |
| `WallpaperScreen` | Wallpaper grid with category chips, search, and preview |
| `AudioPlayerSheet` | Full-screen overlay player with waveform, seek, skip ±10s |
| `_WallpaperPreviewScreen` | Full-screen wallpaper preview with download & set options |

---

## Project Structure

```
lib/
├── main.dart                          # App entry, theme setup, onboarding check
├── screens/
│   ├── onboarding_screen.dart         # Animated 3-page onboarding
│   ├── home_screen.dart               # Ringtone browse + favourites tabs
│   └── wallpaper_screen.dart          # Wallpaper grid + preview
├── model/
│   ├── ringtone_model.dart            # Ringtone data class + JSON parsing
│   └── wallpaper_model.dart           # Wallpaper data class + JSON parsing
├── services/
│   ├── audio_services.dart            # Singleton AudioPlayer wrapper
│   ├── download_services.dart         # Download + set-as-ringtone (Android)
│   ├── favourites_service.dart        # SharedPreferences-backed favourites
│   ├── ringtone_api_services.dart     # Jamendo API — search & pagination
│   └── wallpapers_api_services.dart   # Unsplash API — search & category fetch
└── widgets/
    ├── audioplayer_sheet.dart         # Full-screen player card + waveform painter
    └── ringtone_card.dart             # List card with play/download/favourite actions

assets/
└── fonts/
    ├── Outfit-Regular.ttf
    ├── Outfit-Medium.ttf
    ├── Outfit-SemiBold.ttf
    ├── Outfit-Bold.ttf
    └── Outfit-ExtraBold.ttf
```

---

## Architecture & Data Flow

### Ringtone Flow
```
HomeScreen
  └── ApiService.searchRingtones(keyword, page, genre)
        └── GET api.jamendo.com/v3.0/tracks/ → List<Ringtone>
  └── RingtoneCard (tap)
        └── AudioPlayerSheet
              └── AudioService.togglePlay(id, url)
                    └── audioplayers AudioPlayer
  └── RingtoneCard (download icon)
        └── DownloadService.downloadRingtone(url, fileName)
  └── RingtoneCard (bell icon after download)
        └── DownloadService.setAsRingtone(file, title)
              └── MethodChannel('com.ringle.app/set_ringtone')
  └── RingtoneCard (heart icon)
        └── FavouritesService.toggleFavourite(ringtone)
              └── SharedPreferences → JSON list
```

### Wallpaper Flow
```
WallpaperScreen
  ├── "All" chip    → WallpaperApiService.fetchAllCategories()
  │                     └── 11 parallel GET /search/photos?query=<tag>
  ├── Category chip → WallpaperApiService.searchPhotos(query: tag)
  └── Search query  → WallpaperApiService.searchPhotos(query: keyword)

  └── _WallpaperCard (tap)
        └── _WallpaperPreviewScreen
              ├── Download → api.downloadImageBytes(url) → saveToGallery (MethodChannel)
              └── Set Wallpaper → api.downloadImageBytes(url) → setWallpaper (MethodChannel)
```

### Onboarding Flow
```
main()
  └── SharedPreferences.getBool('tonecraft_onboarding_done')
        ├── false → OnboardingScreen → _completeOnboarding()
        │             └── prefs.setBool('tonecraft_onboarding_done', true)
        │             └── Navigate to HomeScreen
        └── true  → HomeScreen (directly)
```

---

## Services

### `AudioService` (singleton)
Wraps `audioplayers` `AudioPlayer`. Exposes `togglePlay`, `pause`, `stop`, `seekTo`, and streams for player state, position, and duration. Only one track plays at a time — calling `togglePlay` on a new track stops the current one automatically.

### `DownloadService` (singleton)
Handles storage permission requests (Android 13+ uses `Permission.audio`, older uses `Permission.storage`), streaming HTTP download with progress callback, and a `MethodChannel` call to native Android to write the file to `MediaStore` and set it as the system ringtone.

### `FavouritesService` (singleton)
Stores favourite `Ringtone` objects as a JSON list in SharedPreferences under key `favourite_ringtones`. Provides `getFavourites`, `addFavourite`, `removeFavourite`, `toggleFavourite`, and `isFavourite`.

### `ApiService` (Jamendo)
- **Endpoint**: `https://api.jamendo.com/v3.0/tracks/`
- **Page size**: 24 tracks per request
- **Sorting**: `relevance` when keyword is present, `popularity_total` when browsing
- **Filters**: `namesearch` for keyword search, `fuzzytags` for genre filtering

### `WallpaperApiService` (Unsplash)
- **Endpoint**: `https://api.unsplash.com/search/photos`
- **Per category**: 20 photos, portrait orientation
- **"All" tab**: fires 11 parallel requests and merges results, de-duplicated by ID
- Complies with Unsplash API guidelines by calling `triggerDownload()` on every save/set action

---

## Native Android Integration

Two `MethodChannel`s bridge Flutter to Android:

| Channel | Method | Purpose |
|---------|--------|---------|
| `com.ringle.app/set_ringtone` | `setRingtone` | Write MP3 to MediaStore and set as system ringtone |
| `com.ringle.app/set_ringtone` | `getSdkInt` | Detect Android API level for permission routing |
| `com.tonecraft/wallpaper` | `saveToGallery` | Save image bytes to device gallery |
| `com.tonecraft/wallpaper` | `setWallpaper` | Set image as home (1), lock (2), or both (3) wallpapers |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart `>=3.0.0`) |
| Audio | `audioplayers ^6.0.0` |
| Networking | `http ^1.2.1` |
| Images | `cached_network_image ^3.3.1` |
| Local storage | `shared_preferences ^2.2.3` |
| File paths | `path_provider ^2.1.3` |
| Permissions | `permission_handler ^11.3.1` |
| Loading skeletons | `shimmer ^3.0.0` |
| Font | Outfit (Regular → ExtraBold) |

---

## Dependencies

```yaml
dependencies:
  http: ^1.2.1
  audioplayers: ^6.0.0
  path_provider: ^2.1.3
  permission_handler: ^11.3.1
  shared_preferences: ^2.2.3
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  cupertino_icons: ^1.0.6
```

---

## API Keys

The app uses two external APIs. Keys are currently hardcoded in the service files:

| API | File | Variable |
|-----|------|---------|
| Jamendo | `lib/services/ringtone_api_services.dart` | `_clientId` |
| Unsplash | `lib/services/wallpapers_api_services.dart` | `_accessKey` |

> **Note:** Move these to environment variables or a secrets file before releasing publicly to avoid key exposure.

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.0.0`
- Android Studio with Android NDK (for native MethodChannel implementation)
- A physical or emulated Android device (wallpaper setting and ringtone features require Android)

### Run the project

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Android Permissions

Add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.WRITE_SETTINGS" />
```

---

## Theme & Colors

| Element | Color |
|---------|-------|
| Background | `#0A0A14` |
| Surface | `#12121F` |
| Surface 2 | `#1A1A2E` |
| Primary (violet) | `#BF5AF2` |
| Secondary (cyan) | `#0AE8F0` |
| Accent red | `#FF6B6B` |
| Muted text | `#7070A0` |
| Onboarding page 1 accent | `#BF5AF2` violet |
| Onboarding page 2 accent | `#0AE8F0` cyan |
| Onboarding page 3 accent | `#FF6B6B` red |

---


- **Developed by**: Muhammad Atif Javeid
