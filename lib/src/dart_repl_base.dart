import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:dart_repl/src/evaluator.dart';
import 'package:dart_repl/src/keywords.dart';
import 'package:dart_repl/src/parser.dart';

/* TODO(komposten): Maybe add support for some codes like Ctrl+L for clearing screen.
    Will have to read character-by-character for that.
n */
class DartRepl {
  static const String prompt = '   > ';
  static const String echoPrompt = '   | ';

  final Parser _parser;
  final Evaluator _evaluator;
  final StreamSink<String> _outputSink;
  final Stream<String> _inputStream;
  final Queue<String> _inputQueue = ListQueue();
  Completer<String> _inputCompleter;

  DartRepl({StreamSink<String> outputSink, Stream<String> inputStream})
      : _outputSink = outputSink,
        _inputStream = inputStream,
        _evaluator = Evaluator(),
        _parser = Parser() {
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
    List<Block> codeBlocks;
    var running = true;

    while (running) {
      codeBlocks = await _readCodeBlock();

      for (var codeBlock in codeBlocks) {
        if (codeBlock.text.isNotEmpty &&
            codeBlock.text.first == Keyword.exit.value) {
          running = false;
          break;
        } else if (codeBlock.type == BlockType.Eval) {
          await _eval(codeBlock.text);
          println();
        } else {
          var text = codeBlock.text;

          if (codeBlock.type == BlockType.Echo) {
            text = _addLineNumbers(text);
          }

          var output = text.join('\n');
          print(output);
          if (output.isNotEmpty) {
            println();
          }
        }
      }
    }

    exit(0);
  }

  Future<List<Block>> _readCodeBlock() async {
    _printPrompt();
    var line = await _readLine();
    return _parser.parseLine(line);
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
    var lineNumber = _parser.lineCount + 1;
    print(_numberedPrompt(lineNumber, prompt));
  }

  List<String> _addLineNumbers(List<String> lines) {
    var result = <String>[];

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var numberedPrompt = _numberedPrompt(i + 1, DartRepl.echoPrompt);
      result.add('$numberedPrompt$line');
    }

    return result;
  }

  String _numberedPrompt(int number, String prompt) {
    var numberString = number.toString();

    // Remove characters from the start of the prompt so the number fits.
    var promptStart = min(numberString.length, prompt.length - 2);

    return '$numberString${Csi.green}${prompt.substring(promptStart)}${Csi.plain}';
  }

  Future<void> _eval(List<String> code) async {
    await _evaluator.evaluate(code);
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
