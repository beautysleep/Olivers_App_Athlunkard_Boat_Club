import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/authentication/login_screen.dart';
import 'features/home/role_home.dart';
import 'services/app_scope.dart';
import 'services/app_state.dart';
import 'services/firestore_tide_repository.dart';
import 'services/firestore_day_rating_repository.dart';
import 'services/firestore_water_release_repository.dart';
import 'services/firestore_weather_repository.dart';
import 'services/firebase_member_directory.dart';
import 'services/member_directory.dart';
import 'services/mock_club_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AthlunkardBoatClubApp());
}

class AthlunkardBoatClubApp extends StatefulWidget {
  const AthlunkardBoatClubApp({super.key, this.appState});

  /// Injected by tests so the app can boot without Firebase behind it.
  final AppState? appState;

  @override
  State<AthlunkardBoatClubApp> createState() => _AthlunkardBoatClubAppState();
}

class _AthlunkardBoatClubAppState extends State<AthlunkardBoatClubApp> {
  late final AppState _appState =
      widget.appState ??
      AppState(
        MockClubRepository(),
        tideRepository: FirestoreTideRepository(),
        weatherRepository: FirestoreWeatherRepository(),
        waterReleaseRepository: FirestoreWaterReleaseRepository(),
        dayRatingRepository: FirestoreDayRatingRepository(),
        memberDirectory: FirebaseMemberDirectory(
          membershipEndpoint: Uri.parse(membershipEndpoint),
        ),
      );

  @override
  void initState() {
    super.initState();
    _appState.restoreSession();
    _appState.loadLiveTides();
    _appState.loadLiveWeather();
    _appState.loadLiveWaterRelease();
    _appState.loadLiveDayRatings();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      appState: _appState,
      child: MaterialApp(
        title: 'Athlunkard Boat Club',
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Shows the login screen until someone signs in, then the role home. Rebuilds
/// automatically when [AppState] changes (login / logout).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return appState.isLoggedIn ? const RoleHome() : const LoginScreen();
  }
}
