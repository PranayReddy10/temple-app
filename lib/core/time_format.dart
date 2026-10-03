/// Times as people read them: the 12-hour clock. The server sends "HH:mm";
/// this is only for showing.
library;

/// "17:30" → "5:30 PM". Anything that is not a bare time (a label the
/// server already wrote, like "9:00 – 10:00 AM") is returned as it is.
String? showTime(String? hhmm) {
  if (hhmm == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})(:\d{2})?$').firstMatch(hhmm.trim());
  if (m == null) return hhmm;
  final h24 = int.parse(m.group(1)!) % 24;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:${m.group(2)} ${h24 < 12 ? 'AM' : 'PM'}';
}

/// "5:30 AM – 12:30 PM" from two "HH:mm" ends, either of which may be missing.
String showTimeRange(String? from, String? to) =>
    [showTime(from), showTime(to)].whereType<String>().join(' – ');
