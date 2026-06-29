/// In-memory [ClubRepository] with seed data, so the whole demo is explorable
/// without a backend. Replace with a real implementation later — nothing in the
/// UI depends on this class, only on [ClubRepository].
library;

import '../models/app_notification.dart';
import '../models/day_conditions.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import 'club_repository.dart';

/// Demo password — every seeded account uses it.
const demoPassword = 'rowing';

class MockClubRepository implements ClubRepository {
  MockClubRepository() {
    _seed();
  }

  // --- People --------------------------------------------------------------
  static const _coach = UserProfile(
    id: 'u_coach',
    displayName: 'Niamh Ryan',
    email: 'coach@athlunkard.club',
    role: UserRole.coach,
  );
  static const _saoirse = UserProfile(
    id: 'u_saoirse',
    displayName: 'Saoirse Walsh',
    email: 'saoirse@athlunkard.club',
    role: UserRole.athlete,
  );
  static const _aoife = UserProfile(
    id: 'u_aoife',
    displayName: 'Aoife Byrne',
    email: 'aoife@athlunkard.club',
    role: UserRole.athlete,
  );
  static const _cian = UserProfile(
    id: 'u_cian',
    displayName: "Cian O'Brien",
    email: 'cian@athlunkard.club',
    role: UserRole.athlete,
  );
  static const _darragh = UserProfile(
    id: 'u_darragh',
    displayName: 'Darragh Kelly',
    email: 'darragh@athlunkard.club',
    role: UserRole.athlete,
  );
  static const _meabh = UserProfile(
    id: 'u_meabh',
    displayName: 'Méabh Nolan',
    email: 'meabh@athlunkard.club',
    role: UserRole.athlete,
  );
  static const _conor = UserProfile(
    id: 'u_conor',
    displayName: 'Conor Doyle',
    email: 'conor@athlunkard.club',
    role: UserRole.athlete,
  );
  static const _parent = UserProfile(
    id: 'u_parent',
    displayName: "Liam O'Brien",
    email: 'parent@athlunkard.club',
    role: UserRole.parent,
    childId: 'u_cian',
  );

  static const _athletes = [
    _saoirse,
    _aoife,
    _cian,
    _darragh,
    _meabh,
    _conor,
  ];
  static const _allAccounts = [_coach, ..._athletes, _parent];

  // --- Storage -------------------------------------------------------------
  late DateTime _today;
  final List<DayConditions> _days = [];
  final Set<DateTime> _unavailable = {};
  final List<Session> _sessions = [];
  final List<AppNotification> _notifications = [];
  int _idCounter = 1000;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _at(int dayOffset, int hour, int minute) =>
      _today.add(Duration(days: dayOffset, hours: hour, minutes: minute));

  void _seed() {
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    // Daylight is roughly constant across the window for the demo (Irish
    // summer). sunrise ~05:30, sunset ~21:45.
    DateTime sunrise(int o) => _at(o, 5, 30);
    DateTime sunset(int o) => _at(o, 21, 45);

    // High tide drifts ~45 min later each day; first window of the day.
    DateTime tide(int o) => _at(o, 6, 40).add(Duration(minutes: 45 * o));

    DayConditions day(
      int o,
      Conditions c, {
      required double wind,
      required double rain,
      required double tideHeight,
      bool waterRelease = false,
    }) =>
        DayConditions(
          date: _at(o, 0, 0),
          conditions: c,
          highTide: tide(o),
          highTideHeightMetres: tideHeight,
          windKnots: wind,
          rainfallMm: rain,
          waterReleaseActive: waterRelease,
          sunrise: sunrise(o),
          sunset: sunset(o),
        );

    _days.addAll([
      day(0, Conditions.amber, wind: 12, rain: 0.5, tideHeight: 4.1),
      day(1, Conditions.red, wind: 23, rain: 5.5, tideHeight: 4.3), // pivoted
      day(2, Conditions.amber, wind: 14, rain: 1.2, tideHeight: 4.0), // gathering
      day(3, Conditions.red, wind: 26, rain: 7.0, tideHeight: 3.8), // too windy
      day(4, Conditions.green, wind: 5, rain: 0.0, tideHeight: 4.4),
      day(5, Conditions.green, wind: 8, rain: 0.2, tideHeight: 4.5), // confirmed
      day(6, Conditions.red, wind: 11, rain: 2.0, tideHeight: 4.2,
          waterRelease: true), // water-release override
      day(7, Conditions.amber, wind: 13, rain: 0.8, tideHeight: 4.0),
      day(8, Conditions.green, wind: 7, rain: 0.0, tideHeight: 4.3),
      day(9, Conditions.amber, wind: 15, rain: 1.5, tideHeight: 3.9),
    ]);

    // Coach has marked themselves unavailable on day 8 (away), despite green.
    _unavailable.add(_dateOnly(_at(8, 0, 0)));

    // A session mid-flight on day 2: 3 committed, needs 1 more.
    _sessions.add(Session(
      id: 's_day2',
      date: tide(2),
      conditions: Conditions.amber,
      coach: _coach,
      committedAthletes: [_aoife, _cian, _darragh],
    ));

    // A confirmed session on day 5: 5 committed (>= minimum of 4).
    _sessions.add(Session(
      id: 's_day5',
      date: tide(5),
      conditions: Conditions.green,
      coach: _coach,
      committedAthletes: [_aoife, _meabh, _conor, _cian, _darragh],
    ));

    // A session proposed for day 1 that the coach pivoted to land as the
    // forecast turned red.
    _sessions.add(Session(
      id: 's_pivot',
      date: tide(1),
      conditions: Conditions.amber,
      coach: _coach,
      committedAthletes: [_aoife, _cian],
      lifecycle: SessionLifecycle.cancelledWeatherPivot,
    ));

    // Seed notifications so each inbox isn't empty on first login.
    _notifications.addAll([
      AppNotification(
        id: 'n_1',
        recipientId: _saoirse.id,
        type: NotificationType.proposalReceived,
        title: 'New session proposed',
        body: "There's a session proposed — can you attend? Tap to respond.",
        createdAt: _at(0, -2, 0),
        sessionId: 's_day2',
      ),
      AppNotification(
        id: 'n_2',
        recipientId: _coach.id,
        type: NotificationType.sessionConfirmed,
        title: 'Session confirmed',
        body: '5 athletes are going — the session is on.',
        createdAt: _at(0, -3, 0),
        sessionId: 's_day5',
      ),
      AppNotification(
        id: 'n_3',
        recipientId: _parent.id,
        type: NotificationType.childCommitted,
        title: 'Cian is attending a session',
        body: 'Cian is planning to attend an upcoming session. Plan transport.',
        createdAt: _at(0, -4, 0),
        sessionId: 's_day5',
      ),
      AppNotification(
        id: 'n_4',
        recipientId: _coach.id,
        type: NotificationType.sessionPivoted,
        title: 'Conditions worsened — moved to land',
        body: 'You moved an upcoming session to land training.',
        createdAt: _at(0, -5, 0),
        sessionId: 's_pivot',
      ),
    ]);
  }

  // --- ClubRepository ------------------------------------------------------
  @override
  List<UserProfile> accounts() => List.unmodifiable(_allAccounts);

  @override
  UserProfile? authenticate(String email, String password) {
    final target = email.trim().toLowerCase();
    if (password != demoPassword) return null;
    for (final a in _allAccounts) {
      if (a.email.toLowerCase() == target) return a;
    }
    return null;
  }

  @override
  List<DayConditions> upcomingDays() => List.unmodifiable(_days);

  @override
  Set<DateTime> unavailableDays() => Set.unmodifiable(_unavailable);

  @override
  void markUnavailable(DateTime date) => _unavailable.add(_dateOnly(date));

  @override
  List<Session> sessions() => List.unmodifiable(_sessions);

  @override
  Session? sessionForDate(DateTime date) {
    final target = _dateOnly(date);
    for (final s in _sessions) {
      if (_dateOnly(s.date) == target) return s;
    }
    return null;
  }

  @override
  void upsertSession(Session session) {
    final i = _sessions.indexWhere((s) => s.id == session.id);
    if (i >= 0) {
      _sessions[i] = session;
    } else {
      _sessions.add(session);
    }
  }

  @override
  List<AppNotification> notificationsForUser(String userId) {
    final mine =
        _notifications.where((n) => n.recipientId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(mine);
  }

  @override
  void addNotification(AppNotification notification) =>
      _notifications.add(notification);

  @override
  String nextId(String prefix) => '${prefix}_${_idCounter++}';

  /// Exposed for the use-case layer: everyone who should be notified of a new
  /// proposal. Not part of the persistence interface, so it's a plain getter.
  List<UserProfile> get athletes => List.unmodifiable(_athletes);
}
