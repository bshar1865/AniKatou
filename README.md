# AniKatou (iOS)

AniKatou is an iOS client built with SwiftUI.

It does not ship with content sources. You connect it to your own self-hosted AniWatch-compatible API.

## What it does

- Home feed (trending, popular, latest, etc.)
- Search anime
- Anime details + episode list
- Streaming playback (custom or native player)
- Continue Watching
- Library (saved anime)
- Episode downloads (HLS)
- Offline playback for downloaded episodes

## Setup

1. Sideload the app (AltStore, SideStore, Sideloadly, Feather, etc.).
2. Deploy your AniWatch-compatible API backend.
3. Open AniKatou and enter your API base URL in Settings.

## Important

- AniKatou is only a client.
- It does not host or distribute media.
- There are no bundled API endpoints or content sources.
- You are responsible for your backend and usage.

## Dependency

- [Kingfisher](https://github.com/onevcat/Kingfisher) (MIT)

## API backend reference

- https://github.com/ghoshRitesh12/aniwatch-api

## License

See [LICENSE](LICENSE).
