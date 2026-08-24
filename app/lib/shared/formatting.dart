/// Hand-rolled rather than pulling in `intl`, which the demo does not otherwise
/// need. See formatting_test.dart for what each one produces.
library;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDayDate(DateTime dateTime) =>
    '${_weekdays[dateTime.weekday - 1]} ${dateTime.day} '
    '${_months[dateTime.month - 1]}';

String formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:'
    '${dateTime.minute.toString().padLeft(2, '0')}';

String formatDayTime(DateTime dateTime) =>
    '${formatDayDate(dateTime)}, ${formatTime(dateTime)}';

String formatWeekday(DateTime dateTime) => _weekdays[dateTime.weekday - 1];
