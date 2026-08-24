library;

/// How long before high tide the crew must already be at the club to get on the
/// water in time. It sets which half-hour mark the default meeting time lands
/// on: 06:41 high tide becomes 06:00, not 06:30. Provisional — settle the real
/// figure with the coaches alongside the other thresholds.
const kMinimumMinutesBeforeHighTide = 30;

/// How many meeting times the coach chooses between. Each step back is another
/// half hour on the water, so the choice is effectively session length.
const kMeetingTimeOptions = 3;

/// Meeting times the coach can propose for a high tide, soonest first.
///
/// Rowing does not start at high water — the crew meets beforehand, and how far
/// beforehand is the coach's call, so this offers the on-the-hour and
/// on-the-half-hour marks rather than deciding for them.
List<DateTime> meetingTimesBefore(
  DateTime highTide, {
  int minimumMinutesBefore = kMinimumMinutesBeforeHighTide,
  int options = kMeetingTimeOptions,
}) {
  final latest = highTide.subtract(Duration(minutes: minimumMinutesBefore));
  final onTheHalfHour = DateTime(
    latest.year,
    latest.month,
    latest.day,
    latest.hour,
    latest.minute >= 30 ? 30 : 0,
  );
  return [
    for (var step = 0; step < options; step++)
      onTheHalfHour.subtract(Duration(minutes: 30 * step)),
  ];
}
