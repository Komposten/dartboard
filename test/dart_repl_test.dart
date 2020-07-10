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
      var output = await _runCommands(
          commands, [1, 1, 1, 4], 5, process.stdin, processOut);

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
      var output = await _runCommands(
          commands, [1, 1, 1, 3], 5, process.stdin, processOut);

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
          commands, [1, 1, 1, 3, 4], 5, process.stdin, processOut);

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
          await _runCommands(commands, [1, 1], 5, process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('${Csi.up}${Csi.clearLine}1  > '));
    });

    test('Test undo with code to undo', () async {
      var commands = ['var x = 5;', 'print(x);', 'undo;'];
      var output = await _runCommands(
          commands, [1, 1, 1, 1], 12, process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3],
          equals('${Csi.up}${Csi.clearLine}${Csi.up}${Csi.clearLine}2  > '));
    });

    test('Test clear', () async {
      var commands = ['var x = 5;', 'print(x);', 'clear;', 'echo;'];
      var output = await _runCommands(
          commands, [1, 1, 1, 1, 2], 5, process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3], equals('1  > '));
      // Check the echo output to verify that code was cleared.
      expect(output[4], equals('========'));
      expect(output[5], equals('1  > '));
    });

    test('Test delete', () async {
      var commands = ['var x = 5;', 'var y = 10;', 'print(x);', 'delete:2;'];
      var output = await _runCommands(
          commands, [1, 1, 1, 1, 4], 5, process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3], equals('4  > '));
      expect(output[4], equals('========'));
      expect(output[5], equals('1  | var x = 5;'));
      expect(output[6], equals('2  | print(x);'));
      expect(output[7], equals('3  > '));
    });

    test('Test insert', () async {
      var commands = ['var x = 5;', 'print(x);', 'insert:2;var y = 10;'];
      var output = await _runCommands(
          commands, [1, 1, 1, 5], 5, process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3], equals('========'));
      expect(output[4], equals('1  | var x = 5;'));
      expect(output[5], equals('2  | var y = 10;'));
      expect(output[6], equals('3  | print(x);'));
      expect(output[7], equals('4  > '));
    });

    test('Test edit', () async {
      var commands = [
        'var x = 5;',
        'var y = 10;',
        'print(x);',
        'edit:2;var z = 15;'
      ];
      var output = await _runCommands(
          commands, [1, 1, 1, 1, 5], 5, process.stdin, processOut);

      expect(output[0], equals('1  > '));
      expect(output[1], equals('2  > '));
      expect(output[2], equals('3  > '));
      expect(output[3], equals('4  > '));
      expect(output[4], equals('========'));
      expect(output[5], equals('1  | var x = 5;'));
      expect(output[6], equals('2  | var z = 15;'));
      expect(output[7], equals('3  | print(x);'));
      expect(output[8], equals('4  > '));
    });

    tearDown(() {
      process?.kill();
    });
  });
}

Future<List<String>> _runCommands(
    List<String> commands,
    List<int> linesPerCommand,
    int lastLineLength,
    IOSink processIn,
    Stream<String> processOut) async {
  var commandCounter = 0;
  var result = <String>[];
  var commandCompleter = Completer();

  var currentBlock = '';

  processOut.listen((line) {
    // Remove ANSI colour tags
    line = line.replaceAll(RegExp('\x1b\\[[^\x1b]+?m'), '');

    // Add the line to the currentBlock block
    currentBlock += line;

    // Split the block on newline characters
    var split2 = _split(currentBlock, '\n');
    var isLastCommand = commandCounter == linesPerCommand.length - 1;

    // Check if the block has the correct amount of lines in it
    if (split2.length >= linesPerCommand[commandCounter]) {
      // If this is not the final command, or it's the final command and the last
      // line has the expected length, complete.
      if (!isLastCommand || split2.last.length >= lastLineLength) {
        result.addAll(split2);
        currentBlock = '';

        if (!commandCompleter.isCompleted) {
          commandCompleter.complete();
        }
      }
      // If it is the last command and we don't have the expected length,
      // start a 1-second timer after which we time out the operation.
      else if (isLastCommand) {
        // Start a 1 second timer.
        Future.delayed(Duration(seconds: 5), commandCompleter.complete);
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
