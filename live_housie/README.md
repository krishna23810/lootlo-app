📁 Folder Structure Explained
lib/
├── core/                    ← Shared app-wide utilities (not feature-specific)
│   ├── constants/           ← Magic numbers, URLs, limits (one source of truth)
│   ├── routing/             ← GoRouter setup (which URL → which screen)
│   ├── theme/               ← Colors, text styles, button styles
│   └── utils/               ← Logger, formatters, helpers
│
├── data/                    ← Everything related to getting/sending data
│   ├── models/              ← Shared DTOs (Data Transfer Objects from API)
│   ├── repositories/        ← Classes that talk to backend APIs (Dio HTTP)
│   └── services/            ← Lower-level infra: WebSocket, WebRTC, Hive storage
│
├── features/                ← Each feature is self-contained (MVVM)
│   ├── splash/views/        ← Splash screen
│   ├── auth/
│   │   ├── models/          ← User, AuthToken data classes
│   │   ├── repositories/    ← API calls for login/register
│   │   ├── viewmodels/      ← Riverpod Notifiers (business logic)
│   │   └── views/           ← LoginScreen, RegisterScreen widgets
│   ├── game/                ← Same pattern for games
│   ├── ticket/              ← Same pattern for tickets
│   ├── wallet/              ← Same pattern for wallet
│   └── live_session/        ← Same pattern for live draw
│
└── main.dart                ← App entry point

Why this structure?

Each feature folder is independent — if you delete wallet/, nothing else breaks
core/ and data/ are shared foundations
MVVM means: Model (data shape) → ViewModel (business logic via Riverpod) → View (UI widgets)
📦 pubspec.yaml — Your Dependencies Explained
Package	What it does	Why we need it
flutter_riverpod	State management runtime	Holds app state, rebuilds widgets when state changes
riverpod_annotation	@riverpod annotation support	Write less boilerplate — code gen creates providers for you
riverpod_generator	Generates .g.dart files	Reads your @riverpod annotations and creates provider code
dio	HTTP client	Makes API calls to your backend (like axios in JS)
socket_io_client	WebSocket client	Real-time events — when a number is drawn, all players see it instantly
flutter_webrtc	WebRTC	Live video streaming from the Draw Host via Janus
hive_flutter	Local key-value storage	Stores auth token locally so user stays logged in
go_router	URL-based navigation	Declarative routing — URLs map to screens
freezed_annotation + freezed	Immutable data classes	Creates models with copyWith, equality, JSON serialization
json_annotation + json_serializable	JSON ↔ Dart conversion	Auto-generates fromJson/toJson for API responses
build_runner	Code generation engine	Runs all generators (riverpod, freezed, json) with one command
The code generation workflow:

You write: @riverpod, @freezed, @JsonSerializable
You run:   dart run build_runner build
It creates: *.g.dart, *.freezed.dart files automatically
🔄 App Flow (What Happens When You Open the App)
1. main() runs
   └── WidgetsFlutterBinding.ensureInitialized()  ← Required before async ops
   └── LocalStorageService.initialize()            ← Opens Hive box for tokens
   └── ProviderScope(child: LiveHousieApp())       ← Wraps everything in Riverpod

2. LiveHousieApp builds
   └── ref.watch(appRouterProvider)  ← Gets/creates the GoRouter
   └── MaterialApp.router(routerConfig: router)  ← Hands routing to GoRouter

3. GoRouter starts at initialLocation: '/'
   └── '/' → SplashScreen

4. SplashScreen (3 seconds)
   └── Shows animated logo + loading spinner
   └── After 3s → context.go('/login')  ← Replaces splash with login

5. From Login:
   └── Success → context.go('/games')     ← Goes to game list
   └── "Register" tap → context.push('/register')  ← Stacks register on top
🧠 Key Concepts to Focus On
1. ProviderScope (in main.dart)

ProviderScope(child: LiveHousieApp())
This is like a "container" that holds all your Riverpod state. Every widget below it can access providers. Without it, ref.watch() wouldn't work.

2. ConsumerWidget vs StatelessWidget

class LiveHousieApp extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) { ... }
}
ConsumerWidget = a StatelessWidget that also gets ref. Use ref.watch() to reactively listen to providers — when the provider value changes, this widget automatically rebuilds.

3. BaseRepository pattern (in data/repositories/)

abstract class BaseRepository {
  late final Dio dio;
  // Auto-adds auth token to every request
  // Auto-handles 401 errors globally
}
Every feature repository (AuthRepository, GameRepository, etc.) extends this. The auth token is automatically attached to every API call — you never manually add headers.

4. WebSocketService (in data/services/) The WebSocket stays connected while you're in a live game. It receives events like:

draw:number_drawn → a new number was drawn
draw:pattern_claimed → someone won a pattern
draw:game_ended → game over, check prizes
Want me to continue to the next task? The next one would be implementing the Auth feature — login/register screens with Riverpod viewmodels. That'll be a great Riverpod learning moment.