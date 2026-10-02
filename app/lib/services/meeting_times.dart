/// Where the "Meet at" wheel in the day card lands when it opens, and the
/// bounds it refuses to scroll past. Picking a time is otherwise free-form —
/// 15-minute ticks, no preset list of options.
library;

/// The default meeting time opens this long before the earliest rowable
/// water, which is almost always what a coach wants: on the slipway as the
/// water comes up. They can scroll either way from there.
const kDefaultMinutesBeforeRowableWater = 30;

/// How far back the wheel will scroll before the earliest rowable water. A
/// coach can meet a session up to an hour before the water is there —
/// anything longer suggests pointing at the wrong tide.
const kEarliestMinutesBeforeRowableWater = 60;

/// How late the wheel will scroll before the tide drops back below rowable.
/// A session proposed with less than an hour of rowable water left over is
/// almost certainly a mistake — scrolling right up to the end would.
const kLatestMinutesBeforeRowableWaterEnds = 60;

/// Floor a DateTime to the nearest 15-minute mark on or before it. The
/// Cupertino time picker steps in quarters, so every default and bound has
/// to land on one or the wheel's "initial" value snaps away from the number
/// the coach was shown.
DateTime quarterHourAtOrBefore(DateTime time) => DateTime(
  time.year,
  time.month,
  time.day,
  time.hour,
  time.minute - (time.minute % 15),
);

/// The time the "Meet at" wheel is pre-set to when the sheet first opens.
DateTime defaultMeetingTime(DateTime earliestRowableWater) =>
    quarterHourAtOrBefore(
      earliestRowableWater.subtract(
        const Duration(minutes: kDefaultMinutesBeforeRowableWater),
      ),
    );

/// The earliest value the wheel will accept.
DateTime earliestMeetingTime(DateTime earliestRowableWater) =>
    quarterHourAtOrBefore(
      earliestRowableWater.subtract(
        const Duration(minutes: kEarliestMinutesBeforeRowableWater),
      ),
    );

/// The latest value the wheel will accept — anchored to when the water
/// drops back below rowable, not to high tide itself, because what the coach
/// is really protecting is the length of the session that is still rowable
/// at meeting time.
DateTime latestMeetingTime(DateTime rowableWaterEnds) => quarterHourAtOrBefore(
  rowableWaterEnds.subtract(
    const Duration(minutes: kLatestMinutesBeforeRowableWaterEnds),
  ),
);
