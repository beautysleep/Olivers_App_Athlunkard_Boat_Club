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
import 'session_windows.dart';
import 'tide_windows.dart';
import 'water_release_conditions.dart';
import 'weather_conditions.dart';

class AppState extends ChangeNotifier {
  AppState(
    this._repository, {
    FirestoreTideRepository? tideRepository,
    FirestoreWeatherRepository? weatherRepository,
    FirestoreWaterReleaseRepository? waterReleaseRepository,
  }) : _liveTideSource = tideRepository,
       _liveWeatherSource = weatherRepository,
       _liveWaterReleaseSource = waterReleaseRepository;

  final ClubRepository _repository;

  final FirestoreTideRepository? _liveTideSource;
  Map<String, List<LiveHighTide>> _liveHighTides = {};

  final FirestoreWeatherRepository? _liveWeatherSource;
  Map<String, LiveWeather> _liveWeather = {};
  Map<String, LiveDaylight> _liveDaylight = {};

  final FirestoreWaterReleaseRepository? _liveWaterReleaseSource;
  LiveWaterRelease? _liveWaterRelease;

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  List<UserProfile> get accounts => _repository.accounts();

  bool login(String email, String password) {
    final user = _repository.authenticate(email, password);
    if (user == null) return false;
    _currentUser = user;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  List<DayConditions> upcomingDays() => _repository.upcomingDays();
  Set<DateTime> coachUnavailableDays() => _repository.coachUnavailableDays();
  List<Session> sessionsForDate(DateTime date) =>
      _repository.sessionsForDate(date);

  /// Every live source is optional: without it the day card says "No data",
  /// which must not become the whole app failing to start.
  Future<void> _loadOptionalSource(Future<void> Function() load) async {
    try {
      await load();
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  Future<void> loadLiveTides() async {
    final repository = _liveTideSource;
    if (repository == null) return;
    await _loadOptionalSource(() async {
      _liveHighTides = await repository.loadHighTides();
    });
  }

  List<LiveHighTide> liveHighTidesFor(DateTime date) =>
      _liveHighTides[_dateKey(date)] ?? const [];

  /// Null beyond the weather forecast horizon, where the UI says so rather
  /// than inventing a window.
  LiveDaylight? liveDaylightFor(DateTime date) => _liveDaylight[_dateKey(date)];

  /// Offering no window is deliberate when either input is missing: judging
  /// real tides against mock daylight would produce a confident wrong answer.
  DaySessions daySessionsFor(DayConditions day) {
    final sessionsThatDay = sessionsForDate(day.date);
    final highs = liveHighTidesFor(day.date);
    final daylight = liveDaylightFor(day.date);
    if (highs.isEmpty || daylight == null) {
      return (offerableWindows: null, sessionsWithoutAWindow: sessionsThatDay);
    }
    final offerable = offerableHighTides(
      highs,
      localSunrise: daylight.localSunrise,
      localSunset: daylight.localSunset,
    );
    return (
      offerableWindows: sessionsByHighTide(offerable, sessionsThatDay),
      sessionsWithoutAWindow: sessionsWithoutAHighTide(
        offerable,
        sessionsThatDay,
      ),
    );
  }

  Future<void> loadLiveWeather() async {
    final repository = _liveWeatherSource;
    if (repository == null) return;
    await _loadOptionalSource(() async {
      final forecasts = await repository.loadDailyForecasts();
      _liveWeather = forecasts.weather;
      _liveDaylight = forecasts.daylight;
    });
  }

  LiveWeather? liveWeatherFor(DateTime date) => _liveWeather[_dateKey(date)];

  Future<void> loadLiveWaterRelease() async {
    final repository = _liveWaterReleaseSource;
    if (repository == null) return;
    await _loadOptionalSource(() async {
      _liveWaterRelease = await repository.loadStatus();
    });
  }

  LiveWaterRelease? get liveWaterRelease => _liveWaterRelease;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Session? sessionById(String id) {
    for (final s in _repository.sessions()) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<UserProfile> get _allAthletes =>
      _repository.accounts().where((a) => a.role == UserRole.athlete).toList();

  List<Session> sessionsForCurrentUser() {
    final user = _currentUser;
    if (user == null) return const [];
    final all = _repository.sessions().toList()
      ..sort((a, b) => a.meetingTime.compareTo(b.meetingTime));
    switch (user.role) {
      case UserRole.coach:
        return all;
      case UserRole.athlete:
        return all.where((s) => s.isCommitted(user)).toList();
      case UserRole.parent:
        final childId = user.childId;
        return all
            .where((s) => s.committedAthletes.any((a) => a.id == childId))
            .toList();
    }
  }

  List<AppNotification> notifications() {
    final user = _currentUser;
    if (user == null) return const [];
    return _repository.notificationsForUser(user.id);
  }

  int get notificationCount => notifications().length;

  void sendProposal(
    DayConditions day,
    LiveHighTide highTide, {
    required DateTime meetingTime,
  }) {
    final coach = _currentUser;
    if (coach == null || coach.role != UserRole.coach) return;

    final session = Session(
      id: _repository.nextId('s'),
      meetingTime: meetingTime,
      highTideTime: highTide.localTime,
      conditionRating: day.conditionRating,
      coach: coach,
      committedAthletes: [],
    );
    _repository.upsertSession(session);

    for (final athlete in _allAthletes) {
      _notify(
        athlete.id,
        NotificationType.proposalReceived,
        'New session proposed',
        'A session is proposed for ${formatDayTime(session.meetingTime)} — '
            'can you attend?',
        sessionId: session.id,
      );
    }
    notifyListeners();
  }

  /// Coach marks themselves unavailable for [day], so it won't be proposed.
  void markCoachUnavailable(DayConditions day) {
    if (_currentUser?.role != UserRole.coach) return;
    _repository.markCoachUnavailable(day.date);
    notifyListeners();
  }

  /// Coach cancels a session — either pivoting to land training or outright.
  /// Everyone who committed is notified.
  void cancelSession(Session session, {required bool pivotToLand}) {
    if (_currentUser?.role != UserRole.coach) return;
    session.lifecycle = pivotToLand
        ? SessionLifecycle.cancelledWeatherPivot
        : SessionLifecycle.cancelledOutright;
    _repository.upsertSession(session);

    final when = formatDayTime(session.meetingTime);
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
    _repository.upsertSession(session);

    // Notify the athlete's parent, if one is subscribed to them.
    if (accept && !alreadyIn) {
      for (final account in _repository.accounts()) {
        if (account.role == UserRole.parent && account.childId == athlete.id) {
          _notify(
            account.id,
            NotificationType.childCommitted,
            '${athlete.displayName.split(' ').first} is attending a session',
            '${athlete.displayName.split(' ').first} is planning to attend '
                'the ${formatDayTime(session.meetingTime)} session.',
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
          'The ${formatDayTime(session.meetingTime)} session is on — '
              '${session.committedCount} going.',
          sessionId: session.id,
        );
      }
      _notify(
        session.coach.id,
        NotificationType.sessionConfirmed,
        'Session confirmed',
        '${session.committedCount} athletes are going to the '
            '${formatDayTime(session.meetingTime)} session.',
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
    _repository.addNotification(
      AppNotification(
        id: _repository.nextId('n'),
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
