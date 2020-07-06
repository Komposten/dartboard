import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:dart_repl/src/keywords.dart';
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
  static const String isolateCompleted = 'completed';

  String _cachedSegment = '';
  int _lines = 0;

  void run() async {
    var segment;

    while (true) {
      segment = _readSegment();

      if (segment == Keyword.exit.keyword) {
        break;
      }

      await _eval(segment);
      stdout.writeln();
    }

    exit(0);
  }

  String _readSegment() {
    var finished = false;
    var segment = _cachedSegment;

    while (!finished) {
      _printPrompt();

      var line = stdin.readLineSync();
      var keyword = Keywords.findKeyword(line);

      switch (keyword) {
        case Keyword.end:
          segment = _removeKeyword('$segment\n$line', Keyword.end.keyword);
          _cachedSegment = '';
          _lines = 0;
          finished = true;
          break;

        case Keyword.eval:
          segment = _removeKeyword('$segment\n$line', Keyword.eval.keyword);
          _cachedSegment = segment;
          finished = true;
          break;

        case Keyword.exit:
          segment = Keyword.exit.keyword;
          finished = true;
          break;

        case Keyword.echo:
          stdout.write('========');
          stdout.writeln(_addLineNumbers(segment));
          break;

        case Keyword.undo:
          // Move the cursor up one line to the undo command and clear that line.
          stdout.write('\u001b[F\u001b[K');

          // Remove everything after the last newline in segment.
          // This will remove the line added before undo was triggered.
          var lastNewline = segment.lastIndexOf('\n');
          if (lastNewline >= 0) {
            // Move it up again to the line we want to undo, and clear that line as well.
            stdout.write('\u001b[F\u001b[K');

            segment = segment.substring(0, lastNewline);
            _lines--;
          } else {
            segment = '';
            _lines = 0;
          }
          break;

        case Keyword.clear:
          segment = '';
          _lines = 0;
          break;

        default:
          segment += '\n$line';
          _lines++;
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

  String _removeKeyword(String segment, String keyword) {
    keyword = RegExp.escape(keyword);
    return segment.replaceAll(RegExp('\\s?$keyword\$'), '');
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
