int _sequence = 0;

String newSessionItemId() {
  _sequence = (_sequence + 1) % 1000000;
  return '${DateTime.now().microsecondsSinceEpoch}-$_sequence';
}
