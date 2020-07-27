import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:dartboard/src/evaluator.dart';
import 'package:dartboard/src/keywords.dart';
import 'package:dartboard/src/parser.dart';

/* TODO(komposten): Maybe add support for some codes like Ctrl+L for clearing screen.
    Will have to read character-by-character for that.
n */
class DartRepl {
  static const String prompt = '   > ';
  static const String echoPrompt = '   | ';

  final bool _terminateOnExit;
  final Parser _parser;
  final Evaluator _evaluator;
  final StreamSink<String> _outputSink;
  final Stream<String> _inputStream;
  final Queue<String> _inputQueue = ListQueue();
  Completer<String> _inputCompleter;

  bool _running = false;
  Completer<bool> _exitCompleter;

  DartRepl(
      {bool terminateOnExit = true,
      StreamSink<String> outputSink,
      Stream<String> inputStream})
      : _terminateOnExit = terminateOnExit,
        _outputSink = outputSink,
        _inputStream = inputStream,
        _evaluator = Evaluator(outputSink: outputSink),
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

  /// Completes with [true] when the repl has exited due to an [exit;] command.
  Future<bool> get done => _exitCompleter.future;

  void run() async {
    if (_running) {
      throw StateError('This DartRepl instance is already running!');
    }

    List<Block> codeBlocks;
    _running = true;
    _exitCompleter = Completer();

    while (_running) {
      codeBlocks = await _readCodeBlock();

      for (var codeBlock in codeBlocks) {
        if (codeBlock.text.isNotEmpty &&
            codeBlock.text.first == Keyword.exit.value) {
          _running = false;
          break;
        } else if (codeBlock.type == BlockType.Eval) {
          await _eval(codeBlock.text);
          println();
        } else if (codeBlock.type == BlockType.CommandSequence) {
          print(codeBlock.text.join());
        } else {
          var text = codeBlock.text;

          if (codeBlock.type == BlockType.Echo) {
            text = _addLineNumbers(text);
          }

          var output = text.join('\n');
          if (output.isNotEmpty) {
            println(output);
          }
        }
      }
    }

    if (_terminateOnExit) {
      exit(0);
    } else {
      _exitCompleter.complete(true);
    }
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
