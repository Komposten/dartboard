import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dart_repl/src/evaluator.dart';
import 'package:dart_repl/src/keywords.dart';

/* TODO(komposten): Maybe add support for some codes like Ctrl+L for clearing screen.
    Will have to read character-by-character for that.

   TODO(komposten): Add an option to specify input stream.
    Maybe also output stream. Would require zone-age in the Isolate, though, to
    pipe it's output to the correct place.
n */
class DartRepl {
  static const String prompt = '   > ';
  static const String echoPrompt = '   | ';

  final Evaluator _evaluator;
  final List<String> _cachedSegment = <String>[];
  int _lines = 0;

  DartRepl() : _evaluator = Evaluator();

  void run() async {
    List<String> segment;

    while (true) {
      segment = _readSegment();

      if (segment.isNotEmpty && segment.first == Keyword.exit.value) {
        break;
      }

      await _eval(segment);
      stdout.writeln();
    }

    exit(0);
  }

  List<String> _readSegment() {
    var finished = false;
    var segment = List<String>.from(_cachedSegment);

    while (!finished) {
      _printPrompt();

      var line = stdin.readLineSync();
      var keywordMatch = Keywords.findKeyword(line);
      var keyword = keywordMatch?.keyword;

      if (keyword == Keyword.end) {
        line = keywordMatch.text;
        if (line.isNotEmpty) {
          segment.add(line);
        }
        _cachedSegment.clear();
        _lines = 0;
        finished = true;
      } else if (keyword == Keyword.eval) {
        line = keywordMatch.text;
        if (line.isNotEmpty) {
          segment.add(line);
        }
        _cachedSegment.clear();
        _cachedSegment.addAll(segment);
        finished = true;
      } else if (keyword == Keyword.exit) {
        segment.clear();
        segment.add(Keyword.exit.value);
        finished = true;
      } else if (keyword == Keyword.echo) {
        _echo(segment);
      } else if (keyword == Keyword.undo) {
        // Move the cursor up one line to the undo command and clear that line.
        stdout.write('${Csi.up}${Csi.clearLine}');

        if (segment.isNotEmpty) {
          // Move it up again to the line we want to undo, and clear that line as well.
          stdout.write('${Csi.up}${Csi.clearLine}');
          segment.removeLast();
          _lines--;
        }
      } else if (keyword == Keyword.clear) {
        segment.clear();
        _lines = 0;
      } else if (keyword == Keyword.delete) {
        var index = keywordMatch.indices[0] - 1;
        if (index >= 0 && index < segment.length) {
          segment.removeAt(index);
        }
        _lines--;
        _echo(segment);
      } else if (keyword == Keyword.insert) {
        var index = keywordMatch.indices[0] - 1;
        if (index < 0) {
          index = 0;
        } else if (index >= segment.length) {
          index = segment.length;
        }

        segment.insert(index, keywordMatch.text);
        _lines++;
        _echo(segment);
      } else if (keyword == Keyword.edit) {
        var index = keywordMatch.indices[0] - 1;
        if (index >= 0 && index < segment.length) {
          segment.removeAt(index);
          segment.insert(index, keywordMatch.text);
        }

        _echo(segment);
      } else {
        segment.add('$line');
        _lines++;
      }
    }

    return segment;
  }

  void _printPrompt() {
    var lineNumber = _lines + 1;
    stdout.write(_numberedPrompt(lineNumber, prompt));
  }

  void _echo(List<String> segment) {
    stdout.write('========');
    stdout.writeln(_addLineNumbers(segment));
  }

  String _addLineNumbers(List<String> segment) {
    var result = '';

    for (var i = 0; i < segment.length; i++) {
      var line = segment[i];
      var numberedPrompt = _numberedPrompt(i + 1, echoPrompt);
      result = '$result\n$numberedPrompt$line';
    }

    return result;
  }

  String _numberedPrompt(int number, String prompt) {
    var numberString = number.toString();

    // Remove characters from the start of the prompt so the number fits.
    var promptStart = min(numberString.length, prompt.length - 2);

    return '$numberString${Csi.green}${prompt.substring(promptStart)}${Csi.plain}';
  }

  Future<void> _eval(List<String> segment) async {
    await _evaluator.evaluate(segment);
  }
}

class Csi {
  static const up = '\x1b[F';
  static const clearLine = '\x1b[K';
  static const green = '\x1b[1;32m';
  static const plain = '\x1b[0m';
}