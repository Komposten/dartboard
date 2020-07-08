import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

class Evaluator {
  static const String isolateCompleted = 'completed';

  final String _template;

  String _code;
  int _offset;

  Evaluator() : _template = _loadTemplate();

  static String _loadTemplate() {
    var dartReplDir = p.dirname(Platform.script.toFilePath());
    var path = p.join(dartReplDir, '..', 'lib', 'res', 'eval_template.dart');
    return File(path).readAsStringSync();
  }

  Future<void> evaluate(List<String> lines) async {
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
    _code = _template.replaceFirst('//imports//', importString);
    // Count the number of lines before //code//
    _offset = _linesBefore('//code//', _template);
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
    final tempDir = _getTempDir();
    final tempFile = File(p.join(tempDir.path, 'script.dart'));

    tempFile.createSync();
    tempFile.writeAsStringSync(_code);
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
    }
  }
}
