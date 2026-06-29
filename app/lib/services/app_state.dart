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

class AppState extends ChangeNotifier {
  AppState(this._repo);

  final ClubRepository _repo;

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
  Session? sessionForDate(DateTime date) => _repo.sessionForDate(date);

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
    _repo.addNotification(AppNotification(
      id: _repo.nextId('n'),
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      sessionId: sessionId,
    ));
  }
}
