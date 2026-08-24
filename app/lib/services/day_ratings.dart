/// The decision engine's verdict, read back from `day_ratings`. The app renders
/// it; it never recomputes it, so the thresholds stay tunable in one place.
library;

import '../models/session.dart';

/// Null for a word this build does not know. A future rating the app cannot
/// interpret must not be shown as a colour it might not mean.
Conditions? _conditionsFrom(String? rating) => switch (rating) {
  'green' => Conditions.green,
  'amber' => Conditions.amber,
  'red' => Conditions.red,
  _ => null,
};

class LiveWindowRating {
  const LiveWindowRating({
    required this.highTideTime,
    required this.conditions,
    required this.reasons,
    this.start,
    this.end,
  });

  final DateTime highTideTime;
  final Conditions? conditions;
  final DateTime? start;
  final DateTime? end;
  final List<String> reasons;

  bool get isRowable => start != null && end != null;
}

class LiveDayRating {
  const LiveDayRating({
    required this.conditions,
    required this.reasons,
    required this.windows,
  });

  final Conditions? conditions;

  /// Only the overrides that settle every window at once. A reason about one
  /// tide lives on that tide.
  final List<String> reasons;
  final List<LiveWindowRating> windows;

  LiveWindowRating? forHighTide(DateTime highTideTime) {
    for (final window in windows) {
      if (window.highTideTime.isAtSameMomentAs(highTideTime)) return window;
    }
    return null;
  }
}

LiveDayRating? liveDayRatingFromDocument(Map<String, dynamic>? document) {
  if (document == null) return null;
  return LiveDayRating(
    conditions: _conditionsFrom(document['rating'] as String?),
    reasons: _reasons(document['reasons']),
    windows: [
      for (final raw in (document['windows'] as List?) ?? const [])
        _window((raw as Map).cast<String, dynamic>()),
    ],
  );
}

LiveWindowRating _window(Map<String, dynamic> raw) => LiveWindowRating(
  highTideTime: raw['high_tide_at'] as DateTime,
  conditions: _conditionsFrom(raw['rating'] as String?),
  start: raw['window_start'] as DateTime?,
  end: raw['window_end'] as DateTime?,
  reasons: _reasons(raw['reasons']),
);

List<String> _reasons(Object? raw) => [
  for (final reason in (raw as List?) ?? const []) reason as String,
];
