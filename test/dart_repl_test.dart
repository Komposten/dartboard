import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_repl/dart_repl.dart';
import 'package:test/test.dart';

void main() {
  group('Keyword tests', () {
    Process process;
    Stream<String> processOut;

    setUp(() async {
      process =
          await Process.start('dart', ['bin/dart_repl.dart'], runInShell: true);
      processOut = process.stdout.transform(utf8.decoder);
    });

    test('Test exit', () async {
      process.stdin.writeln('exit;');
      expect(await process.exitCode, equals(0));
    });

    test('Test echo', () async {
      var commands = ['var x = 5;', 'print(x);', 'echo;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        // Check the echo output to verify that the inputted code was kept.
        '========',
        '\n1  | var x = 5;',
        '\n2  | print(x);',
        '\n3  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test end', () async {
      var commands = ['var x = 5;', 'print(x);', 'end;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        '5\n',
        '\n1  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test eval', () async {
      var commands = ['var x = 5;', 'print(x);', 'eval;', 'echo;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        '5\n',
        '\n3  > ',
        // Check the echo output to verify that the inputted code was kept.
        '========',
        '\n1  | var x = 5;',
        '\n2  | print(x);',
        '\n3  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test undo with nothing to undo', () async {
      var commands = ['undo;'];
      var expected = [
        '1  > ',
        '${Csi.up}${Csi.clearLine}1  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test undo with code to undo', () async {
      var commands = ['var x = 5;', 'print(x);', 'undo;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        '${Csi.up}${Csi.clearLine}${Csi.up}${Csi.clearLine}2  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test clear', () async {
      var commands = ['var x = 5;', 'print(x);', 'clear;', 'echo;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        '1  > ',
        // Check the echo output to verify that the inputted code was cleared.
        '========',
        '\n1  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test delete', () async {
      var commands = ['var x = 5;', 'var y = 10;', 'print(x);', 'delete:2;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        '4  > ',
        '========',
        '\n1  | var x = 5;',
        '\n2  | print(x);',
        '\n3  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test insert', () async {
      var commands = ['var x = 5;', 'print(x);', 'insert:2;var y = 10;'];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        // Check the echo output to verify that the inputted code was kept.
        '========',
        '\n1  | var x = 5;',
        '\n2  | var y = 10;',
        '\n3  | print(x);',
        '\n4  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    test('Test edit', () async {
      var commands = [
        'var x = 5;',
        'var y = 10;',
        'print(x);',
        'edit:2;var z = 15;'
      ];
      var expected = [
        '1  > ',
        '2  > ',
        '3  > ',
        '4  > ',
        '========',
        '\n1  | var x = 5;',
        '\n2  | var z = 15;',
        '\n3  | print(x);',
        '\n4  > ',
      ];

      await _testCommands(commands, expected, process.stdin, processOut);
    });

    tearDown(() {
      process?.kill();
    });
  });
}

Future<void> _testCommands(List<String> commands, List<String> expectedLines,
    IOSink processIn, Stream<String> processOut) async {
  var jobCompleter = Completer();

  var expected = expectedLines.join();
  var actual = '';

  processOut.listen((line) {
    // Remove ANSI colour tags
    line = line.replaceAll(RegExp('\x1b\\[[^\x1b]+?m'), '');

    actual += line;

    if (actual.length == expected.length && actual == expected) {
      jobCompleter.complete();
    }
  });

  for (var command in commands) {
    processIn.writeln(command);
  }

  // Wait for all commands to finish before returning, or time out if it takes too long.
  var timeout = Duration(seconds: 2);
  await jobCompleter.future
      .timeout(timeout, onTimeout: () => _onTimeout(actual, expected, timeout));
}

void _onTimeout(String actual, String expected, Duration timeout) {
  expected = expected.replaceAll('\n', '\\n');
  actual = actual.replaceAll('\n', '\\n');
  fail(
      'Commands did not produce expected output and timed out after ${timeout.inSeconds} seconds.\n'
      'Data at time-out:\n'
      '  Expected: $expected\n'
      '    Actual: $actual');
}
