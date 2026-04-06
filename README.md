# AniKatou (iOS)

AniKatou is a SwiftUI iOS app for browsing anime metadata and playing streams using the Anime API (50n50).

It does not include built-in content sources.

## Features

- Home sections (trending, latest, top airing, popular, upcoming, top 10)
- Search
- Anime details with episode groups
- Library
- Continue Watching
- HLS episode downloads
- Offline playback for downloaded episodes
- Subtitle support (including downloaded subtitle files)
- Custom player and native player support

## Setup

1. Build or sideload the app.
2. Run your API backend.
3. Open `Settings -> Server Settings` and set your API base URL.

## API backend reference

- https://github.com/50n50/animeapi

Thanks to Paul for providing the Anime API. This backend is required for the app to load and stream anime.

## Notes

- AniKatou is a client only.
- No media is hosted or bundled by this app.
- You are responsible for the backend and how it is used.

## License

See [LICENSE](LICENSE).
