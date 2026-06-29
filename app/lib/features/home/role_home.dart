import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/app_scope.dart';
import '../calendar/calendar_screen.dart';
import '../notifications/notifications_screen.dart';
import '../sessions/upcoming_sessions_screen.dart';

/// The signed-in shell. The set of tabs depends on the user's role, mirroring
/// the per-persona flows: coach and athlete are calendar-first; the parent is
/// notification-first.
class RoleHome extends StatefulWidget {
  const RoleHome({super.key});

  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _Tab {
  const _Tab(this.icon, this.selectedIcon, this.label, this.screen);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;
}

class _RoleHomeState extends State<RoleHome> {
  int _index = 0;

  List<_Tab> _tabsFor(UserRole role) {
    const calendar = _Tab(Icons.calendar_today_outlined,
        Icons.calendar_today, 'Calendar', CalendarScreen());
    const sessions = _Tab(Icons.directions_boat_outlined,
        Icons.directions_boat, 'Sessions', UpcomingSessionsScreen());
    const alerts = _Tab(Icons.notifications_outlined, Icons.notifications,
        'Alerts', NotificationsScreen());

    switch (role) {
      case UserRole.coach:
      case UserRole.athlete:
        return const [calendar, sessions, alerts];
      case UserRole.parent:
        // Parent's main use is notifications; sessions tab is read-only
        // visibility into the child's sessions.
        return const [alerts, sessions];
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox.shrink();

    final tabs = _tabsFor(user.role);
    final index = _index.clamp(0, tabs.length - 1);
    final alertCount = appState.notificationCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(tabs[index].label),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(user.displayName.split(' ').first),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: appState.logout,
          ),
        ],
      ),
      body: tabs[index].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: _maybeBadge(tab, alertCount, selected: false),
              selectedIcon: _maybeBadge(tab, alertCount, selected: true),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  Widget _maybeBadge(_Tab tab, int count, {required bool selected}) {
    final icon = Icon(selected ? tab.selectedIcon : tab.icon);
    if (tab.label == 'Alerts' && count > 0) {
      return Badge(label: Text('$count'), child: icon);
    }
    return icon;
  }
}
