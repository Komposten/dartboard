import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:dart_repl/src/evaluator.dart';
import 'package:dart_repl/src/keywords.dart';

/* TODO(komposten): Maybe add support for some codes like Ctrl+L for clearing screen.
    Will have to read character-by-character for that.
n */
class DartRepl {
  static const String prompt = '   > ';
  static const String echoPrompt = '   | ';

  final Evaluator _evaluator;
  final List<String> _cachedSegment = <String>[];
  final StreamSink<String> _outputSink;
  final Stream<String> _inputStream;
  final Queue<String> _inputQueue = ListQueue();
  Completer<String> _inputCompleter;

  int _lines = 0;

  DartRepl({StreamSink<String> outputSink, Stream<String> inputStream})
      : _outputSink = outputSink,
        _inputStream = inputStream,
        _evaluator = Evaluator() {
    if (_inputStream != null) {
      _inputStream.listen((event) {
        if (_inputCompleter != null && !_inputCompleter.isCompleted) {
          _inputCompleter.complete(event);
        } else {
          _inputQueue.add(event);
        }
      });
    }
  }

  void run() async {
    List<String> segment;

    while (true) {
      segment = await _readSegment();

      if (segment.isNotEmpty && segment.first == Keyword.exit.value) {
        break;
      }

      await _eval(segment);
      println();
    }

    exit(0);
  }

  Future<List<String>> _readSegment() async {
    var finished = false;
    var segment = List<String>.from(_cachedSegment);

    while (!finished) {
      _printPrompt();

      var line = await _readLine();

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
          _lines++;
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
        print('${Csi.up}${Csi.clearLine}');

        if (segment.isNotEmpty) {
          // Move it up again to the line we want to undo, and clear that line as well.
          print('${Csi.up}${Csi.clearLine}');
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

  Future<String> _readLine() async {
    if (_inputStream != null) {
      return Future(_waitForInput);
    } else {
      return stdin.readLineSync();
    }
  }

  Future<String> _waitForInput() async {
    if (_inputQueue.isNotEmpty) {
      return _inputQueue.removeFirst();
    } else {
      _inputCompleter = Completer();
      return await _inputCompleter.future;
    }
  }

  void _printPrompt() {
    var lineNumber = _lines + 1;
    print(_numberedPrompt(lineNumber, prompt));
  }

  void _echo(List<String> segment) {
    print('========');
    println(_addLineNumbers(segment));
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

  void println([String message]) {
    print('${message ?? ''}\n');
  }

  void print([String message]) {
    message = message ?? '';
    if (_outputSink != null) {
      _outputSink.add(message);
    } else {
      stdout.write(message);
    }
  }
}

class Csi {
  static const up = '\x1b[F';
  static const clearLine = '\x1b[K';
  static const green = '\x1b[1;32m';
  static const plain = '\x1b[0m';
}
