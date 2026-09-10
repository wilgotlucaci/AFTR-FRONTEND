# AFTR — iOS app

> Live tonight. Remember tomorrow.

SwiftUI client for AFTR. You start a **Night**, put your phone away, and
the next day you get a recap: a map of where you went, the venues, the
movement, and a few funny AI-written highlights. The Python API lives in
the sibling `aftr-backend` repo.

---

## Requirements

- Xcode (iOS 26.5 deployment target)
- The `aftr-backend` server running (see its README)

## Run

1. Start the backend: `cd ../aftr-backend && .venv/bin/uvicorn api:app --reload`
2. Open `AFTR.xcodeproj`, select an iOS Simulator, ⌘R.

The API base URL defaults to `http://127.0.0.1:8000` (Simulator only).
For a physical device or a deployed backend, add an `API_BASE_URL` string
key to `Info.plist` — see `AppConfig` in
[`APIService.swift`](APIService.swift). No code change needed.

Auth is Supabase email/password. The session is persisted to the
Keychain, so you only log in once. Sign out from the profile menu on
Home.

## Structure

```
AFTRApp.swift          @main entry
ContentView.swift      routes: Splash → Login → Home → ActiveNight
APIService.swift       backend calls + AppConfig (base URL)
AuthService.swift      Supabase sign in / out / session check
SupabaseManager.swift  Supabase client
LocationManager.swift  CoreLocation: adaptive upload cadence, outlier
                       rejection, background tracking
Models/                Codable models for the API payloads
Screens/
  Auth/LoginView            neon-pink branded sign in
  Home/HomeView             start a Night, join by code, recent Nights
  Night/ActiveNightView     live timer, invite code, "put your phone away"
  Recap/RecapView           hero, duration, stats, AFTR SAYS, route map,
                            venue timeline, movement
```

`Home`, `Night`, `Recap` and `Models` are Xcode 16 *synchronized*
folder groups — add a `.swift` file to the folder and it's in the target
automatically. Keep `ContentView.swift` a thin router; screens go under
`Screens/`.

## Design language

Black background, neon pink (`#FF1A94`) accent, soft pink + purple glow,
white type, dark translucent rounded cards. Premium, subtle nightlife —
**not** generic neon cyberpunk. The login screen is the reference.

## Multi-person Nights

The host shares the 6-character **invite code** shown on the Active Night
screen (also via the share sheet). Others enter it on Home → *Join code*.
Everyone's route and the group events (splits, reunions, dynamic duo,
houdini, …) then show up in the recap.

## Notes

- No sign-up screen yet — users are created out of band in Supabase.
- The backend has no public deployment; it runs on localhost for now.
