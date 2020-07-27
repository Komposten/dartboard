import 'dart:async';
import 'dart:io';

import 'package:dart_repl/src/evaluator.dart';
import 'package:dart_repl/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Code generation', () {
    File codeFile;
    Directory resourceDir;

    setUpAll(() {
      codeFile = _getCodeFile();
      resourceDir = _getResourceDirectory();
    });

    test('code added correctly', () {
      var evaluator = Evaluator(codeOutputFile: codeFile);
      var code = [
        'import \'dart:io\';',
        'var file = File(\'file\');',
        'print(utf8.encode(file.path));',
        'import \'dart:convert\';'
      ];
      evaluator.evaluate(code);

      var expected =
          _readFile(p.join(resourceDir.path, 'populated_template.txt'));
      var actual = _readFile(codeFile.path);

      expect(actual, equals(expected));
    });
  });

  group('Code output', () {
    test('Custom output stream', () async {
      var controller = StreamController<String>();
      var evaluator = Evaluator(outputSink: controller.sink);
      var expected = 'Hello World!\n';
      var actual = '';

      controller.stream.listen((event) {
        print('Event: $event');
        actual += event;
      });

      await evaluator.evaluate(['print(\'Hello World!\');']);

      expect(actual, equals(expected));
      await controller.close();
    });
  });
}

File _getCodeFile() {
  final parentPath = p.join(Directory.systemTemp.path, 'dart_repl');
  final parentDir = Directory(parentPath);

  if (!parentDir.existsSync()) {
    parentDir.createSync();
  }

  return File(p.join(parentPath, 'tests.dart'));
}

Directory _getResourceDirectory() {
  var directory = getRootDirectory();
  return Directory(p.join(directory.path, 'test', 'res'));
}

String _readFile(String path) {
  return File(path).readAsStringSync().replaceAll('\r\n', '\n');
}
