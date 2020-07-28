import 'dart:async';
import 'dart:isolate';

//imports//

String path;
int offset;

void main(List<String> args, SendPort port) {
  path = args[0];
  offset = int.tryParse(args[1]) ?? 0;

  // Run the user code in a zone to capture its output and pass that to the send port.
  runZoned(
    _main,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => port.send(line),
    ),
    onError: handleError,
  );

  port.send('//messageFinished//');
}

void _main() async {
  //code//
}

void handleError(e, StackTrace stackTrace) {
  path = RegExp.escape(path).replaceAll(r'\\', r'[\/\\]');
  var pathPattern = RegExp(r'(file:.+' + path + r'):(\d+):(\d+)');
  var traceString = stackTrace.toString();
  var matches = pathPattern.allMatches(traceString);

  for (var match in matches) {
    var text = match.group(0);
    var line = int.tryParse(match.group(2));
    var column = int.tryParse(match.group(3));

    var newText = '[dartboard code]:${line - offset}:$column';
    traceString = traceString.replaceFirst(text, newText);
  }

  print(e);
  print(traceString);
}
