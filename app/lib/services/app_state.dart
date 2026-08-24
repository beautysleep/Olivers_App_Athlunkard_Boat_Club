/// The application / use-case layer.
///
/// [AppState] holds the signed-in user and turns user intents (propose, commit,
/// cancel) into data changes + the right notifications, then tells the UI to
/// rebuild. It talks only to [ClubRepository], so swapping the data source
/// doesn't touch any of this logic.
library;

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/day_conditions.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../shared/formatting.dart';
import 'club_repository.dart';
import 'firestore_tide_repository.dart';
import 'firestore_water_release_repository.dart';
import 'firestore_weather_repository.dart';
import 'daylight_conditions.dart';
import 'tide_windows.dart';
import 'water_release_conditions.dart';
import 'weather_conditions.dart';

class AppState extends ChangeNotifier {
  AppState(
    this._repo, {
    FirestoreTideRepository? tideRepository,
    FirestoreWeatherRepository? weatherRepository,
    FirestoreWaterReleaseRepository? waterReleaseRepository,
  }) : _tideRepo = tideRepository,
       _weatherRepo = weatherRepository,
       _waterReleaseRepo = waterReleaseRepository;

  final ClubRepository _repo;

  /// Optional live-tide source (Firestore). Null in tests → mock only.
  final FirestoreTideRepository? _tideRepo;
  Map<String, List<LiveHighTide>> _liveHighTides = {};

  /// Optional live-weather source (Firestore). Null in tests → mock only.
  final FirestoreWeatherRepository? _weatherRepo;
  Map<String, LiveWeather> _liveWeather = {};
  Map<String, LiveDaylight> _liveDaylight = {};

  /// Optional live-water-release source (Firestore). Null in tests → mock
  /// only. Global, not per-day — unlike tide/weather there's a single current
  /// status, not one value per calendar day.
  final FirestoreWaterReleaseRepository? _waterReleaseRepo;
  LiveWaterRelease? _liveWaterRelease;

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // --- Authentication ------------------------------------------------------
  List<UserProfile> get accounts => _repo.accounts();

  /// Returns true on success. The UI shows an error on false.
  bool login(String email, String password) {
    final user = _repo.authenticate(email, password);
    if (user == null) return false;
    _currentUser = user;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // --- Reads ---------------------------------------------------------------
  List<DayConditions> upcomingDays() => _repo.upcomingDays();
  Set<DateTime> unavailableDays() => _repo.unavailableDays();
  List<Session> sessionsForDate(DateTime date) => _repo.sessionsForDate(date);

  // --- Live tide (Firestore) ----------------------------------------------
  /// Load live tide predictions from Firestore. Failure-tolerant: on any error
  /// (e.g. Firebase unavailable in tests) it keeps whatever data we already
  /// have, so the app still works on mock data.
  Future<void> loadLiveTides() async {
    final repo = _tideRepo;
    if (repo == null) return;
    try {
      _liveHighTides = await repo.loadHighTides();
      notifyListeners();
    } catch (_) {
      // Firestore not available — fall back to mock silently.
    }
  }

  /// Live high tides for [date] (all of them), or empty if none loaded.
  List<LiveHighTide> liveHighTidesFor(DateTime date) =>
      _liveHighTides[_dateKey(date)] ?? const [];

  /// Live daylight for [date], or null when the day is beyond the weather
  /// forecast horizon (the UI then says so rather than inventing a window).
  LiveDaylight? liveDaylightFor(DateTime date) => _liveDaylight[_dateKey(date)];

  /// The offerable high-tide sessions for [day]: highs that fall in daylight and
  /// are at/above the height threshold. A day can yield two.
  ///
  /// Returns null when either input is missing — no live tide for the day, or
  /// no live daylight to judge it against. Filtering real tides against mock
  /// daylight would silently produce a wrong answer, so it is not done.
  List<LiveHighTide>? offerableHighTidesFor(DayConditions day) {
    final highs = liveHighTidesFor(day.date);
    if (highs.isEmpty) return null;
    final daylight = liveDaylightFor(day.date);
    if (daylight == null) return null;
    return offerableHighTides(
      highs,
      sunrise: daylight.sunrise,
      sunset: daylight.sunset,
    );
  }

  // --- Live weather (Firestore) -------------------------------------------
  /// Load live weather from Firestore. Failure-tolerant, like [loadLiveTides].
  Future<void> loadLiveWeather() async {
    final repo = _weatherRepo;
    if (repo == null) return;
    try {
      final forecasts = await repo.loadDailyForecasts();
      _liveWeather = forecasts.weather;
      _liveDaylight = forecasts.daylight;
      notifyListeners();
    } catch (_) {
      // Firestore not available — fall back to mock silently.
    }
  }

  /// Live daily weather for [date], or null if none loaded (UI falls back to
  /// mock).
  LiveWeather? liveWeatherFor(DateTime date) => _liveWeather[_dateKey(date)];

  // --- Live water release (Firestore) --------------------------------------
  /// Load live water-release status from Firestore. Failure-tolerant, like
  /// [loadLiveTides].
  Future<void> loadLiveWaterRelease() async {
    final repo = _waterReleaseRepo;
    if (repo == null) return;
    try {
      _liveWaterRelease = await repo.loadStatus();
      notifyListeners();
    } catch (_) {
      // Firestore not available — fall back to mock silently.
    }
  }

  /// The current live water-release status, or null if none loaded (UI falls
  /// back to mock). Global, not per-day — there's no lookup-by-date method
  /// here, unlike [liveHighTidesFor]/[liveWeatherFor].
  LiveWaterRelease? get liveWaterRelease => _liveWaterRelease;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Look up a single session by id (used by the detail screen so it always
  /// reflects the latest state after a commit/cancel).
  Session? sessionById(String id) {
    for (final s in _repo.sessions()) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<UserProfile> get _allAthletes =>
      _repo.accounts().where((a) => a.role == UserRole.athlete).toList();

  /// Sessions relevant to the signed-in user, soonest first.
  List<Session> sessionsForCurrentUser() {
    final user = _currentUser;
    if (user == null) return const [];
    final all = _repo.sessions().toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    switch (user.role) {
      case UserRole.coach:
        return all; // the coach sees everything they run
      case UserRole.athlete:
        return all.where((s) => s.isCommitted(user)).toList();
      case UserRole.parent:
        final childId = user.childId;
        return all
            .where((s) => s.committedAthletes.any((a) => a.id == childId))
            .toList();
    }
  }

  /// Notifications for the signed-in user, newest first.
  List<AppNotification> notifications() {
    final user = _currentUser;
    if (user == null) return const [];
    return _repo.notificationsForUser(user.id);
  }

  int get notificationCount => notifications().length;

  // --- Coach actions -------------------------------------------------------
  /// Coach proposes a session for [day]; every athlete is notified.
  void sendProposal(DayConditions day) {
    final coach = _currentUser;
    if (coach == null || coach.role != UserRole.coach) return;

    final session = Session(
      id: _repo.nextId('s'),
      date: day.highTide,
      conditions: day.conditions,
      coach: coach,
      committedAthletes: [],
    );
    _repo.upsertSession(session);

    for (final athlete in _allAthletes) {
      _notify(
        athlete.id,
        NotificationType.proposalReceived,
        'New session proposed',
        'A session is proposed for ${formatDayTime(session.date)} — '
            'can you attend?',
        sessionId: session.id,
      );
    }
    notifyListeners();
  }

  /// Coach marks themselves unavailable for [day], so it won't be proposed.
  void markUnavailable(DayConditions day) {
    if (_currentUser?.role != UserRole.coach) return;
    _repo.markUnavailable(day.date);
    notifyListeners();
  }

  /// Coach cancels a session — either pivoting to land training or outright.
  /// Everyone who committed is notified.
  void cancelSession(Session session, {required bool pivotToLand}) {
    if (_currentUser?.role != UserRole.coach) return;
    session.lifecycle = pivotToLand
        ? SessionLifecycle.cancelledWeatherPivot
        : SessionLifecycle.cancelledOutright;
    _repo.upsertSession(session);

    final when = formatDayTime(session.date);
    for (final athlete in session.committedAthletes) {
      if (pivotToLand) {
        _notify(
          athlete.id,
          NotificationType.sessionPivoted,
          'Session moved to land training',
          'The $when session has moved off the water to land training due to '
              'conditions.',
          sessionId: session.id,
        );
      } else {
        _notify(
          athlete.id,
          NotificationType.sessionCancelled,
          'Session cancelled',
          'Sorry for the inconvenience — the $when session has been cancelled.',
          sessionId: session.id,
        );
      }
    }
    notifyListeners();
  }

  // --- Athlete actions -----------------------------------------------------
  /// Athlete accepts or declines a proposed session.
  void respondToProposal(Session session, {required bool accept}) {
    final athlete = _currentUser;
    if (athlete == null || athlete.role != UserRole.athlete) return;

    final wasConfirmed = session.status == SessionStatus.confirmed;
    final alreadyIn = session.isCommitted(athlete);

    if (accept && !alreadyIn) {
      session.committedAthletes.add(athlete);
    } else if (!accept && alreadyIn) {
      session.committedAthletes.removeWhere((a) => a.id == athlete.id);
    }
    _repo.upsertSession(session);

    // Notify the athlete's parent, if one is subscribed to them.
    if (accept && !alreadyIn) {
      for (final account in _repo.accounts()) {
        if (account.role == UserRole.parent && account.childId == athlete.id) {
          _notify(
            account.id,
            NotificationType.childCommitted,
            '${athlete.displayName.split(' ').first} is attending a session',
            '${athlete.displayName.split(' ').first} is planning to attend '
                'the ${formatDayTime(session.date)} session.',
            sessionId: session.id,
          );
        }
      }
    }

    // If this response tipped it over the threshold, tell everyone going.
    final nowConfirmed = session.status == SessionStatus.confirmed;
    if (!wasConfirmed && nowConfirmed) {
      for (final a in session.committedAthletes) {
        _notify(
          a.id,
          NotificationType.sessionConfirmed,
          'Session confirmed',
          'The ${formatDayTime(session.date)} session is on — '
              '${session.committedCount} going.',
          sessionId: session.id,
        );
      }
      _notify(
        session.coach.id,
        NotificationType.sessionConfirmed,
        'Session confirmed',
        '${session.committedCount} athletes are going to the '
            '${formatDayTime(session.date)} session.',
        sessionId: session.id,
      );
    }
    notifyListeners();
  }

  // --- Helpers -------------------------------------------------------------
  void _notify(
    String recipientId,
    NotificationType type,
    String title,
    String body, {
    String? sessionId,
  }) {
    _repo.addNotification(
      AppNotification(
        id: _repo.nextId('n'),
        recipientId: recipientId,
        type: type,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        sessionId: sessionId,
      ),
    );
  }
}
