import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dartboard/src/template.dart';
import 'package:dartboard/src/utils.dart' as utils;
import 'package:path/path.dart' as p;

class Evaluator {
  static const isolateCompleted = 'completed';
  static Template _template;

  final StreamSink<String> _outputSink;
  final File _codeOutputFile;

  String _code;
  int _offset;

  Evaluator({StreamSink<String> outputSink, File codeOutputFile})
      : _outputSink = outputSink,
        _codeOutputFile = codeOutputFile {
    _template ??= Template();
  }

  Future<bool> get ready async => _template.ready;

  Future<void> evaluate(List<String> lines) async {
    if (_template.code == null) {
      throw StateError('evaluate must not be called before ready is true');
    }

    _prepareCode(lines);
    var file = _writeCodeFile();
    await _evalInIsolate(file);
  }

  void _prepareCode(List<String> lines) {
    var imports = <String>[];

    imports = lines
        .where((element) => element.trimLeft().startsWith('import'))
        .toList();
    imports.forEach((import) => lines.remove(import));

    var importString = imports.join('\n');
    var codeString = lines.join('\n');

    // Add the imports
    _code = _template.code.replaceFirst('//imports//', importString);
    // Count the number of lines before //code//
    _offset = _linesBefore('//code//', _template.code);
    // Add the code and finish message
    _code = _code
        .replaceFirst('//code//', codeString)
        .replaceFirst('//messageFinished//', isolateCompleted);
  }

  int _linesBefore(String string, String code) {
    var index = code.indexOf(string);
    code = code.substring(0, index);

    return RegExp(r'\n').allMatches(code).length;
  }

  File _writeCodeFile() {
    File file;

    if (_codeOutputFile != null) {
      file = _codeOutputFile;
    } else {
      final tempDir = utils.getTempDir();
      file = File(p.join(tempDir.path, 'script.dart'));
    }

    file.createSync();
    file.writeAsStringSync(_code);
    return file;
  }

  Future<void> _evalInIsolate(File tempFile) async {
    final uri = Uri.file(tempFile.path);
    final messagePort = ReceivePort();
    final completer = Completer();

    messagePort.listen((_) => _onIsolateMessage(_, completer));

    try {
      await Isolate.spawnUri(
          uri, [tempFile.path, _offset.toString()], messagePort.sendPort);
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
    } else {
      if (_outputSink != null) {
        _outputSink.add('$message\n');
      } else {
        print(message);
      }
    }
  }
}
