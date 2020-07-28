import 'package:dartboard/dartboard.dart';
import 'package:dartboard/src/utils.dart';

void main() {
  _printWelcome();

  final dartboard = Dartboard();
  dartboard.run();
}

void _printWelcome() {
  print('Welcome to Dartboard $dartboardVersion!');
}
