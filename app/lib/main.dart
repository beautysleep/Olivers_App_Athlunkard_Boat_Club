import 'package:flutter/material.dart';

import 'features/authentication/login_screen.dart';
import 'features/home/role_home.dart';
import 'services/app_scope.dart';
import 'services/app_state.dart';
import 'services/mock_club_repository.dart';

void main() {
  runApp(const AthlunkardBoatClubApp());
}

class AthlunkardBoatClubApp extends StatefulWidget {
  const AthlunkardBoatClubApp({super.key});

  @override
  State<AthlunkardBoatClubApp> createState() => _AthlunkardBoatClubAppState();
}

class _AthlunkardBoatClubAppState extends State<AthlunkardBoatClubApp> {
  // One app-wide state, backed by the mock repository. Swap MockClubRepository
  // for a real implementation later — nothing else here changes.
  final AppState _appState = AppState(MockClubRepository());

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
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
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
