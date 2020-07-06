import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:path/path.dart' as p;

/* TODO(komposten): Maybe add support for some codes like Ctrl+L for clearing screen.
    Will have to read character-by-character for that.

   TODO(komposten): Add an option to specify input stream.
    Maybe also output stream. Would require zone-age in the Isolate, though, to
    pipe it's output to the correct place.

   TODO(komposten): New command ideas:
     clear; | Clears the current code block
     edit:<line>; <content> | Replace the line at <line> with <content>
     insert:<line>; <content> | Insert a new line with <content> at <line>
     delete:<line>; | Deletes the line at <line>
n */
class DartRepl {
  static const String prompt = '   > ';
  static const String echoPrompt = '   | ';
  static const String statementEval = 'eval;';
  static const String statementEnd = 'end;';
  static const String statementExit = 'exit;';
  static const String statementUndo = 'undo;';
  static const String statementEcho = 'echo;';
  static const String isolateCompleted = 'completed';

  String _cachedSegment = '';
  int _lines = 0;

  void run() async {
    var segment;

    while (true) {
      segment = _readSegment();

      if (segment == statementExit) {
        break;
      }

      await _eval(segment);
      stdout.writeln();
    }

    exit(0);
  }

  String _readSegment() {
    var segment = _cachedSegment;

    while (true) {
      _printPrompt();

      var line = stdin.readLineSync();
      var lineTrimmed = line.trim();

      if (lineTrimmed == statementExit) {
        segment = statementExit;
        break;
      } else if (lineTrimmed == statementEcho) {
        stdout.write('========');
        stdout.writeln(_addLineNumbers(segment));
      } else if (lineTrimmed == statementUndo) {
        // Remove everything after the last newline in segment.
        // This will remove the line added before undo was triggered.
        segment = segment.substring(0, segment.lastIndexOf('\n'));
        _lines--;

        // Move the cursor up one line to the undo command and clear that line.
        // Then move it up again to the line we want to undo, and clear that line as well.
        stdout.write('\u001b[F\u001b[K\u001b[F\u001b[K');
      } else {
        segment += '\n$line';
        _lines++;

        if (lineTrimmed.endsWith(statementEnd)) {
          segment = _removeStatement(segment, statementEnd);
          _cachedSegment = '';
          _lines = 0;
          break;
        } else if (lineTrimmed.endsWith(statementEval)) {
          segment = _removeStatement(segment, statementEval);
          _cachedSegment = segment;
          break;
        }
      }
    }

    return segment;
  }

  void _printPrompt() {
    var lineNumber = _lines + 1;
    stdout.write(_numberedPrompt(lineNumber, prompt));
  }

  String _addLineNumbers(String segment) {
    var lines = segment.split('\n');
    var result = '';

    for (var i = 1; i < lines.length; i++) {
      var line = lines[i];
      var numberedPrompt = _numberedPrompt(i, echoPrompt);
      result = '$result\n$numberedPrompt$line';
    }

    return result;
  }

  String _numberedPrompt(int number, String prompt) {
    var numberString = number.toString();

    // Remove characters from the start of the prompt so the number fits.
    var promptStart = min(numberString.length, prompt.length - 2);

    return '$numberString\u001b[1;32m${prompt.substring(promptStart)}\u001b[0m';
  }

  String _removeStatement(String segment, String statement) {
    statement = RegExp.escape(statement);
    return segment.replaceAll(RegExp('\\s?$statement\$'), '');
  }

  Future<void> _eval(String segment) async {
    var tempFile = _createCodeFile(segment);
    await _evalInIsolate(tempFile);
  }

  File _createCodeFile(String segment) {
    //TODO(komposten): Place import statements before the main method.
    var code = '''
      import 'dart:isolate';
    
      void main(_, SendPort port) {
        $segment
        
        port.send('$isolateCompleted');
      }
      ''';

    final tempDir = _getTempDir();
    final tempFile = File(p.join(tempDir.path, 'script.dart'));

    tempFile.createSync();
    tempFile.writeAsStringSync(code);
    return tempFile;
  }

  Directory _getTempDir() {
    final parentPath = p.join(Directory.systemTemp.path, 'dart_repl');
    final parentDir = Directory(parentPath);

    if (!parentDir.existsSync()) {
      parentDir.createSync();
    }

    return parentDir.createTempSync();
  }

  Future _evalInIsolate(File tempFile) async {
    final uri = Uri.file(tempFile.path);
    final messagePort = ReceivePort();
    final completer = Completer();

    messagePort.listen((_) => _onIsolateMessage(_, completer));

    try {
      await Isolate.spawnUri(uri, [], messagePort.sendPort);
    } on IsolateSpawnException catch (e) {
      var message = e.message;
      message = message.replaceAll(
          RegExp(r'^.+script\.dart:\d+:\d+:\s*', multiLine: true), '');
      print('$message');

      completer.complete();
    }

    // Wait for the isolate to finish.
    await completer.future;
  }

  void _onIsolateMessage(dynamic message, Completer completer) {
    if (message == isolateCompleted) {
      completer.complete();
    }
  }
}
