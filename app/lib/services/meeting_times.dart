/// Why an 06:41 high tide defaults to 06:00 and not 06:30: the crew must
/// already be at the club this long beforehand to get on the water in time.
/// Provisional — settle the real figure with the coaches.
const kMinimumMinutesBeforeHighTide = 30;

/// Each step back is another half hour on the water, so this is really how many
/// session lengths the coach chooses between.
const kMeetingTimeOptions = 3;

DateTime halfHourMarkAtOrBefore(DateTime time) => DateTime(
  time.year,
  time.month,
  time.day,
  time.hour,
  time.minute >= 30 ? 30 : 0,
);

/// Rowing does not start at high water: the crew meets beforehand, and how far
/// beforehand is the coach's call, not the tide's.
List<DateTime> meetingTimesBefore(
  DateTime highTide, {
  int minimumMinutesBefore = kMinimumMinutesBeforeHighTide,
  int options = kMeetingTimeOptions,
}) {
  final latestLaunchableTime = highTide.subtract(
    Duration(minutes: minimumMinutesBefore),
  );
  final soonest = halfHourMarkAtOrBefore(latestLaunchableTime);
  return [
    for (var step = 0; step < options; step++)
      soonest.subtract(Duration(minutes: 30 * step)),
  ];
}
