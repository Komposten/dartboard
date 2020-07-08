import 'dart:isolate';

//imports//

int offset;

void main(List<String> args, SendPort port) {
  var path = args[0];
  offset = int.tryParse(args[1]) ?? 0;

  try {
    // All user-provided code goes here.
    //code//
  } catch (e, stackTrace) {
    handleError(e, stackTrace, path);
  }

  port.send('//messageFinished//');
}

void handleError(e, StackTrace stackTrace, String path) {
  path = RegExp.escape(path).replaceAll(r'\\', r'[\/\\]');
  var pathPattern = RegExp(r'(file:.+' + path + r'):(\d+):(\d+)');
  var traceString = stackTrace.toString();
  var matches = pathPattern.allMatches(traceString);

  for (var match in matches) {
    var text = match.group(0);
    var line = int.tryParse(match.group(2));
    var column = int.tryParse(match.group(3));

    var newText = '[dart_repl code]:${line - offset}:$column';
    traceString = traceString.replaceFirst(text, newText);
  }

  print(e);
  print(traceString);
}
