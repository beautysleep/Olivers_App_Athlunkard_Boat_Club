/// Small date/time formatters. Pure Dart so both the UI and the services layer
/// can use them. (A real app would likely use the `intl` package; kept
/// dependency-free for the demo.)
library;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "Sat 5 Jul"
String formatDayDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// e.g. "06:40"
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// e.g. "Sat 5 Jul, 06:40"
String formatDayTime(DateTime d) => '${formatDayDate(d)}, ${formatTime(d)}';

/// Short weekday for compact calendar cells, e.g. "Sat".
String formatWeekday(DateTime d) => _weekdays[d.weekday - 1];
