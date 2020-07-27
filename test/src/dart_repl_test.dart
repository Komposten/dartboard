import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_repl/dart_repl.dart';
import 'package:test/test.dart';

void main() {
  group('REPL tests using custom streams', () {
    DartRepl repl;
    StreamController<String> processIn;
    Stream<String> processOut;

    setUp(() {
      var outputSink = StreamController<String>();

      processOut = outputSink.stream;
      processIn = StreamController();
      repl = DartRepl(terminateOnExit: false, outputSink: outputSink, inputStream: processIn.stream);
      repl.run();
    });

    test('Test exit', () async {
      processIn.add('exit;');
      expect(await repl.done, isTrue);
    }, timeout: Timeout(Duration(seconds: 2)));

    test('Test calling run() when already running', () {
      expect(() => repl.run(), throwsStateError);
    });

    test('Test restarting after exit', () async {
      processIn.add('exit;');
      await repl.done;
      repl.run();

      var commands = ['print(\'Test\');', 'end;'];
      var expected = [
        '1  > ',
        '1  > ', // Two 1's since we restarted.
        '2  > ',
        'Test\n',
        '\n1  > '
      ];

      await _testCommands(commands, expected, processIn, processOut);
    });

    test('Test eval and echo', () async {
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

      await _testCommands(commands, expected, processIn, processOut);
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

      await _testCommands(commands, expected, processIn, processOut);
    });
  });

  group('REPL tests using default streams', () {
    Process process;
    Stream<String> processOut;
    StreamSink<String> processIn;

    setUp(() async {
      process =
          await Process.start('dart', ['bin/dart_repl.dart'], runInShell: true);
      processOut = process.stdout.transform(utf8.decoder);

      var inStreamController = StreamController<String>();
      inStreamController.stream.listen((event) => process.stdin.writeln(event));
      processIn = inStreamController;
    });

    test('Test exit', () async {
      processIn.add('exit;');
      expect(await process.exitCode, equals(0));
    });

    test('Test eval and echo', () async {
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

      await _testCommands(commands, expected, processIn, processOut);
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

      await _testCommands(commands, expected, processIn, processOut);
    });
  });
}

Future<void> _testCommands(List<String> commands, List<String> expectedLines,
    StreamSink<String> processIn, Stream<String> processOut) async {
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
    processIn.add(command);
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
