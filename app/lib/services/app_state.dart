import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/day_conditions.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../shared/formatting.dart';
import 'club_repository.dart';
import 'firestore_tide_repository.dart';
import 'firestore_day_rating_repository.dart';
import 'firestore_water_release_repository.dart';
import 'firestore_weather_repository.dart';
import 'day_ratings.dart';
import 'member_directory.dart';
import 'daylight_conditions.dart';
import 'push_registration.dart';
import 'session_repository.dart';
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
    FirestoreDayRatingRepository? dayRatingRepository,
    SessionRepository? sessionRepository,
    this.pushRegistration,
    this.memberDirectory,
  }) : _liveDayRatingSource = dayRatingRepository,
       _liveTideSource = tideRepository,
       _liveWeatherSource = weatherRepository,
       _liveWaterReleaseSource = waterReleaseRepository,
       _sessionSource = sessionRepository;

  final ClubRepository _repository;
  final SessionRepository? _sessionSource;
  List<Session> _sessions = const [];

  final PushRegistration? pushRegistration;

  final FirestoreTideRepository? _liveTideSource;
  Map<String, List<LiveHighTide>> _liveHighTides = {};

  final FirestoreWeatherRepository? _liveWeatherSource;
  Map<String, LiveWeather> _liveWeather = {};
  Map<String, LiveDaylight> _liveDaylight = {};

  final FirestoreWaterReleaseRepository? _liveWaterReleaseSource;
  LiveWaterRelease? _liveWaterRelease;

  final FirestoreDayRatingRepository? _liveDayRatingSource;
  Map<String, LiveDayRating> _liveDayRatings = {};

  final MemberDirectory? memberDirectory;
  List<UserProfile> _roster = const [];

  /// Everyone in the club, for notifying athletes and showing who is going.
  List<UserProfile> get roster => _roster;

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<SignInOutcome> login(String email, String password) =>
      _adopt(() => _directory.signIn(email, password));

  Future<SignInOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    String? childId,
  }) => _adopt(
    () => _directory.signUp(
      email: email,
      password: password,
      displayName: displayName,
      inviteCode: inviteCode,
      childId: childId,
    ),
  );

  /// Only a success adopts the member: a refused code or password must not
  /// leave a half-signed-in state behind it.
  Future<SignInOutcome> _adopt(Future<SignInOutcome> Function() attempt) async {
    final outcome = await attempt();
    if (outcome != SignInOutcome.succeeded) return outcome;
    _currentUser = await _directory.currentMember();
    await _afterSignedIn();
    notifyListeners();
    return outcome;
  }

  /// Firebase keeps a member signed in between runs, so the app asks who that
  /// is before showing a login screen they do not need.
  Future<void> restoreSession() async {
    _currentUser = await _directory.currentMember();
    if (_currentUser != null) await _afterSignedIn();
    notifyListeners();
  }

  /// Everything that needs a signed-in identity: the roster (sessions need it
  /// to resolve ids), sessions themselves, and push registration — run on
  /// every sign-in, and again on every relaunch of an already-signed-in
  /// session, since a token can rotate while the app is closed.
  Future<void> _afterSignedIn() async {
    await loadRoster();
    await loadSessions();
    await registerForPush();
  }

  /// A denied permission or missing device support must not break login —
  /// the same failure-tolerant posture as the read-only live sources below.
  Future<void> registerForPush() async {
    final registration = pushRegistration;
    if (registration == null) return;
    try {
      await registration.registerCurrentDevice();
    } catch (_) {
      return;
    }
  }

  Future<void> loadRoster() async {
    _roster = await _directory.roster();
    notifyListeners();
  }

  Future<void> logout() async {
    await _directory.signOut();
    _currentUser = null;
    _roster = const [];
    notifyListeners();
  }

  MemberDirectory get _directory {
    final directory = memberDirectory;
    if (directory == null) {
      throw StateError('AppState was built without a MemberDirectory');
    }
    return directory;
  }

  List<DayConditions> upcomingDays() => _repository.upcomingDays();
  Set<DateTime> coachUnavailableDays() => _repository.coachUnavailableDays();

  /// Sessions need the roster already loaded (to resolve
  /// `committed_athlete_ids`) and, against the real backend, an authenticated
  /// caller — so this runs from [_adopt]/[restoreSession], not unconditionally
  /// at startup the way the read-only live sources below do.
  Future<void> loadSessions() async {
    final repository = _sessionSource;
    if (repository == null) return;
    await _loadOptionalSource(() async {
      _sessions = await repository.loadSessions(_findAccount);
    });
  }

  UserProfile? _findAccount(String id) {
    for (final member in _roster) {
      if (member.id == id) return member;
    }
    return null;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Session> sessionsForDate(DateTime date) {
    final target = _dateOnly(date);
    return [
      for (final session in _sessions)
        if (_dateOnly(session.meetingTime) == target) session,
    ];
  }

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

  Future<void> loadLiveDayRatings() async {
    final repository = _liveDayRatingSource;
    if (repository == null) return;
    await _loadOptionalSource(() async {
      _liveDayRatings = await repository.loadRatings();
    });
  }

  LiveDayRating? liveDayRatingFor(DateTime date) =>
      _liveDayRatings[_dateKey(date)];

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Session? sessionById(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<UserProfile> get _allAthletes =>
      _roster.where((member) => member.role == UserRole.athlete).toList();

  List<Session> sessionsForCurrentUser() {
    final user = _currentUser;
    if (user == null) return const [];
    final all = _sessions.toList()
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

  /// False on a role mismatch or a failed write — the caller decides how to
  /// tell the coach, this just says whether it happened.
  Future<bool> sendProposal(
    DayConditions day,
    LiveHighTide highTide, {
    required DateTime meetingTime,
  }) async {
    final coach = _currentUser;
    final repository = _sessionSource;
    if (coach == null || coach.role != UserRole.coach || repository == null) {
      return false;
    }

    final String sessionId;
    try {
      sessionId = await repository.proposeSession(
        meetingTime: meetingTime,
        highTideTime: highTide.localTime,
        conditionRating: day.conditionRating,
      );
    } catch (_) {
      return false;
    }
    await loadSessions();

    for (final athlete in _allAthletes) {
      _notify(
        athlete.id,
        NotificationType.proposalReceived,
        'New session proposed',
        'A session is proposed for ${formatDayTime(meetingTime)} — '
            'can you attend?',
        sessionId: sessionId,
      );
    }
    notifyListeners();
    return true;
  }

  /// Coach marks themselves unavailable for [day], so it won't be proposed.
  void markCoachUnavailable(DayConditions day) {
    if (_currentUser?.role != UserRole.coach) return;
    _repository.markCoachUnavailable(day.date);
    notifyListeners();
  }

  /// Coach cancels a session — either pivoting to land training or outright.
  /// Everyone who committed is notified.
  Future<bool> cancelSession(
    Session session, {
    required bool pivotToLand,
  }) async {
    final repository = _sessionSource;
    if (_currentUser?.role != UserRole.coach || repository == null) {
      return false;
    }
    try {
      await repository.cancelSession(session.id, pivotToLand: pivotToLand);
    } catch (_) {
      return false;
    }
    await loadSessions();

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
    return true;
  }

  // --- Athlete actions -----------------------------------------------------
  /// Athlete accepts or declines a proposed session.
  Future<bool> respondToProposal(
    Session session, {
    required bool accept,
  }) async {
    final athlete = _currentUser;
    final repository = _sessionSource;
    if (athlete == null ||
        athlete.role != UserRole.athlete ||
        repository == null) {
      return false;
    }

    final wasConfirmed = session.status == SessionStatus.confirmed;
    final alreadyIn = session.isCommitted(athlete);

    try {
      await repository.respondToSession(session.id, accept: accept);
    } catch (_) {
      return false;
    }
    await loadSessions();
    final updated = sessionById(session.id);

    // Notify the athlete's parent, if one is subscribed to them.
    if (accept && !alreadyIn) {
      for (final account in _roster) {
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
    final nowConfirmed = updated?.status == SessionStatus.confirmed;
    if (!wasConfirmed && nowConfirmed == true && updated != null) {
      for (final a in updated.committedAthletes) {
        _notify(
          a.id,
          NotificationType.sessionConfirmed,
          'Session confirmed',
          'The ${formatDayTime(session.meetingTime)} session is on — '
              '${updated.committedCount} going.',
          sessionId: session.id,
        );
      }
      _notify(
        session.coach.id,
        NotificationType.sessionConfirmed,
        'Session confirmed',
        '${updated.committedCount} athletes are going to the '
            '${formatDayTime(session.meetingTime)} session.',
        sessionId: session.id,
      );
    }
    notifyListeners();
    return true;
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
