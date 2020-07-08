import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('dart_repl tests', () {
    Process process;
    Stream<String> processOut;

    setUp(() async {
      process = await Process.start('dart', ['bin/dart_repl.dart'],
          runInShell: true);
      processOut = process.stdout
          .transform(utf8.decoder)
          .transform(LineSplitter());
    });

    test('Test exit', () async {
      process.stdin.writeln('exit;');
      expect(await process.exitCode, equals(0));
    });

    test('Test end', () async {
      process.stdin.writeln('var x = 5;');
      process.stdin.writeln('print(x);');
      process.stdin.writeln('end;');

      var lines = await getLines([0], processOut);
      expect(lines[0], equals('1  > 2  > 3  > 5'));
    });

    /*
      TODO(komposten): Write more tests.

      TODO(komposten): Also, maybe prefix all output lines from the eval. That would
        allow us to split the processOut output here and have getLines return the lines properly.
        .
        OR Read one line at a time in the tests: stdin-stdout-stdin-stdout
           This might be a better solution. Add a list parameter to getLines which
           takes all the stdin commands as separate strings. getLines can then run one stdin
           and then wait for stdout to happen before running the next.
     */

    tearDown(() {
      process?.kill();
    });
  });
}

Future<List<String>> getLines(List<int> lineNumbers, Stream<String> processOut) async {
  var result = <String>[];
  var counter = 0;
  var completer = Completer<List<String>>();

  processOut.listen((line) {
    // Remove ANSI colour tags
    line = line.replaceAll(RegExp('\u001b\\[.+?m'), '');

    if (lineNumbers.contains(counter)) {
      result.add(line);
      lineNumbers.remove(counter);
    }

    if (lineNumbers.isEmpty) {
      completer.complete(result);
    }

    counter++;
  });

  return await completer.future;
}
