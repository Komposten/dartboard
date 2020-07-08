import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_repl/dart_repl.dart';
import 'package:test/test.dart';

void main() {
  group('dart_repl tests', () {
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
      var output =
          await _runCommands(commands, [1, 1, 1, 4], process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      // Check the echo output to verify that the inputted code was kept.
      expect(output[3], equals('========'));
      expect(output[4], equals('1  | var x = 5;'));
      expect(output[5], equals('2  | print(x);'));
      expect(output[6], equals('3  > '));
    });

    test('Test end', () async {
      var commands = ['var x = 5;', 'print(x);', 'end;'];
      var output =
          await _runCommands(commands, [1, 1, 1, 3], process.stdin, processOut);

      /* TODO(komposten): There is still a concurrency bug!
           It sometimes happens that we get: ("1  > ", "2  > ", "3  > ", "5", "", "")
           instead of: ("1  > ", "2  > ", "3  > ", "5", "", "1  > ")
           .
           This is because the final newline and prompt are printed in separate statements.
           So, if we receive stdout between these statements, we return from _runCommands
           with an empty string in the last spot instead of the expected prompt.
           .
           Solution: Maybe pass in a "last statement" parameter which we can look for
           after the final command?
       */
      print(output.map((e) => '"$e"'));

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3], equals('5'));
      expect(output[4], equals(''));
      expect(output[5], equals('1  > '));
    });

    test('Test eval', () async {
      var commands = ['var x = 5;', 'print(x);', 'eval;', 'echo;'];
      var output = await _runCommands(
          commands, [1, 1, 1, 3, 4], process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3], equals('5'));
      expect(output[4], equals(''));
      expect(output[5], equals('3  > '));
      // Check the echo output to verify that the inputted code was kept.
      expect(output[6], equals('========'));
      expect(output[7], equals('1  | var x = 5;'));
      expect(output[8], equals('2  | print(x);'));
      expect(output[9], equals('3  > '));
    });

    test('Test undo with nothing to undo', () async {
      var commands = ['undo;'];
      var output =
          await _runCommands(commands, [1, 1], process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('${Csi.up}${Csi.clearLine}1  > '));
    });

    test('Test undo with code to undo', () async {
      var commands = ['var x = 5;', 'print(x);', 'undo;'];
      var output =
          await _runCommands(commands, [1, 1, 1, 1], process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3],
          equals('${Csi.up}${Csi.clearLine}${Csi.up}${Csi.clearLine}2  > '));
    });

    /*
      TODO(komposten): Write more tests.
     */

    tearDown(() {
      process?.kill();
    });
  });
}

Future<List<String>> _runCommands(
    List<String> commands,
    List<int> linesPerCommand,
    IOSink processIn,
    Stream<String> processOut) async {
  var commandCounter = 0;
  var result = <String>[];
  var commandCompleter = Completer();

  var currentBlock = '';

  processOut.listen((line) {
    // Remove ANSI colour tags
    line = line.replaceAll(RegExp('\x1b\\[[^\x1b]+?m'), '');

    print('Output: "${line.replaceAll('\x1b', 'ESC')}"');

    // Add the line to the currentBlock block
    currentBlock += line;

    // Split the block on newline characters
    var split2 = _split(currentBlock, '\n');

    // Check if the block has the correct amount of lines in it
    if (split2.length >= linesPerCommand[commandCounter]) {
      result.addAll(split2);
      currentBlock = '';

      if (!commandCompleter.isCompleted) {
        commandCompleter.complete();
      }
    }
  });

  for (var command in commands) {
    // Wait for the active operation to finish (i.e. output to be received).
    await commandCompleter.future;
    commandCounter++;

    // Execute the next command.
    commandCompleter = Completer();
    processIn.writeln(command);
    await processIn.flush();
  }

  // Wait for the final operation to finish before returning.
  await commandCompleter.future;

  return result;
}

List<String> _split(String string, String pattern) {
  var result = <String>[];
  var previous = 0;
  var index = 0;

  while ((index = string.indexOf(pattern, previous)) != -1) {
    result.add(string.substring(previous, index));
    previous = index + pattern.length;
  }

  result.add(string.substring(previous));

  return result;
}
