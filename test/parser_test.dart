import 'package:dart_repl/dart_repl.dart';
import 'package:dart_repl/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group('Keyword tests', () {
    Parser parser;

    setUp(() async {
      parser = Parser();
    });

    test('Test exit', () async {
      var blocks = parser.parseLine('exit;');
      expect(blocks.length, equals(1));
      _expectBlock(blocks.first, ['exit'], BlockType.Plain);
    });

    test('Test echo', () async {
      var commands = ['var x = 5;', 'print(x);', 'echo;'];
      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      var blocks = parser.parseLine(commands[2]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectBlock(blocks.last, [commands[0], commands[1]], BlockType.Echo);
    });

    test('Test end', () async {
      var commands = ['var x = 5;', 'print(x);', 'end;'];
      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      var blocks = parser.parseLine(commands[2]);

      expect(blocks.length, equals(1));
      _expectBlock(blocks.first, [commands[0], commands[1]], BlockType.Eval);
    });

    test('Test eval', () async {
      var commands = ['var x = 5;', 'print(x);', 'eval;', 'echo;'];
      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      var blocks = parser.parseLine(commands[2]);

      expect(blocks.length, equals(1));
      _expectBlock(blocks.first, [commands[0], commands[1]], BlockType.Eval);

      // Check the echo output to verify that the inputted code was kept.
      blocks = parser.parseLine(commands[3]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectBlock(blocks.last, [commands[0], commands[1]], BlockType.Echo);
    });

    test('Test undo with nothing to undo', () async {
      var blocks = parser.parseLine('undo;');

      expect(blocks.length, equals(1));
      _expectBlock(
          blocks.first, ['${Csi.up}${Csi.clearLine}'], BlockType.Plain);
    });

    test('Test undo with code to undo', () async {
      var commands = ['var x = 5;', 'print(x);', 'undo;', 'echo;'];
      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      var blocks = parser.parseLine(commands[2]);

      expect(blocks.length, equals(1));
      _expectBlock(
          blocks.first,
          ['${Csi.up}${Csi.clearLine}', '${Csi.up}${Csi.clearLine}'],
          BlockType.Plain);

      // Check the echo output to verify that the inputted code was cleared.
      blocks = parser.parseLine(commands[3]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectBlock(blocks.last, [commands[0]], BlockType.Echo);
    });

    test('Test clear', () async {
      var commands = ['var x = 5;', 'print(x);', 'clear;', 'echo;'];

      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      _expectSingleEmptyBlock(parser.parseLine(commands[2]));

      // Check the echo output to verify that the inputted code was cleared.
      var blocks = parser.parseLine(commands[3]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectEmptyBlock(blocks.last, BlockType.Echo);
    });

    test('Test delete', () async {
      var commands = ['var x = 5;', 'var y = 10;', 'print(x);', 'delete:2;'];

      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      _expectSingleEmptyBlock(parser.parseLine(commands[2]));

      var blocks = parser.parseLine(commands[3]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectBlock(blocks.last, [commands[0], commands[2]], BlockType.Echo);
    });

    test('Test insert', () async {
      var commands = ['var x = 5;', 'print(x);', 'insert:2;var y = 10;'];

      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));

      var blocks = parser.parseLine(commands[2]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectBlock(blocks.last, [commands[0], 'var y = 10;', commands[1]],
          BlockType.Echo);
    });

    test('Test edit', () async {
      var commands = [
        'var x = 5;',
        'var y = 10;',
        'print(x);',
        'edit:2;var z = 15;'
      ];

      _expectSingleEmptyBlock(parser.parseLine(commands[0]));
      _expectSingleEmptyBlock(parser.parseLine(commands[1]));
      _expectSingleEmptyBlock(parser.parseLine(commands[2]));

      var blocks = parser.parseLine(commands[3]);

      expect(blocks.length, equals(2));
      _expectBlock(blocks.first, ['========'], BlockType.Plain);
      _expectBlock(blocks.last, [commands[0], 'var z = 15;', commands[2]],
          BlockType.Echo);
    });
  });
}

void _expectBlock(Block block, List<String> text, BlockType type) {
  expect(block.text, equals(text));
  expect(block.type, equals(type));
}

void _expectSingleEmptyBlock(List<Block> blocks) {
  expect(blocks.length, equals(1));
  var block = blocks.first;
  _expectEmptyBlock(block);
}

void _expectEmptyBlock(Block block, [BlockType type = BlockType.Plain]) {
  expect(block.text, isEmpty);
  expect(block.type, equals(type));
}
