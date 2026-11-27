import 'package:intl/intl.dart';

final _dateFmt = DateFormat('dd.MM.yyyy');
final _dateTimeFmt = DateFormat('dd.MM.yyyy HH:mm');

String fmtDate(DateTime d) => _dateFmt.format(d);
String fmtDateTime(DateTime d) => _dateTimeFmt.format(d);
