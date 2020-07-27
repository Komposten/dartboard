import 'package:dart_repl/dart_repl.dart';
import 'package:dart_repl/src/keywords.dart';

class Parser {
  final _code = <String>[];
  var _lines = 0;

  int get lineCount => _lines;

  List<Block> parseLine(String line) {
    var blocks = <Block>[];

    var keywordMatch = Keywords.findKeyword(line);
    var keyword = keywordMatch?.keyword;

    if (keyword == Keyword.end) {
      line = keywordMatch.text;
      if (line.isNotEmpty) {
        _code.add(line);
      }
      _lines = 0;

      blocks.add(Block(_code, BlockType.Eval));
      _code.clear();
    } else if (keyword == Keyword.eval) {
      line = keywordMatch.text;
      if (line.isNotEmpty) {
        _code.add(line);
        _lines++;
      }

      blocks.add(Block(_code, BlockType.Eval));
    } else if (keyword == Keyword.exit) {
      _code.clear();
      _code.add(Keyword.exit.value);
      blocks.add(Block(_code, BlockType.Plain));
    } else if (keyword == Keyword.echo) {
        blocks.addAll(_echo(_code));
    } else if (keyword == Keyword.undo) {
      var result = <String>[];

      // Move the cursor up one line to the undo command and clear that line.
      result.add('${Csi.up}${Csi.clearLine}');

      if (_code.isNotEmpty) {
        // Move it up again to the line we want to undo, and clear that line as well.
        result.add('${Csi.up}${Csi.clearLine}');
        _code.removeLast();
        _lines--;
      }

      blocks.add(Block(result, BlockType.CommandSequence));
    } else if (keyword == Keyword.clear) {
      _code.clear();
      _lines = 0;
      blocks.add(Block(_code, BlockType.Plain));
    } else if (keyword == Keyword.delete) {
      var index = keywordMatch.indices[0] - 1;
      if (index >= 0 && index < _code.length) {
        _code.removeAt(index);
      }
      _lines--;
      blocks.addAll(_echo(_code));
    } else if (keyword == Keyword.insert) {
      var index = keywordMatch.indices[0] - 1;
      if (index < 0) {
        index = 0;
      } else if (index >= _code.length) {
        index = _code.length;
      }

      _code.insert(index, keywordMatch.text);
      _lines++;
      blocks.addAll(_echo(_code));
    } else if (keyword == Keyword.edit) {
      var index = keywordMatch.indices[0] - 1;
      if (index >= 0 && index < _code.length) {
        _code.removeAt(index);
        _code.insert(index, keywordMatch.text);
      }

      blocks.addAll(_echo(_code));
    } else {
      _code.add('$line');
      _lines++;
      blocks.add(Block([], BlockType.Plain));
    }

    return blocks;
  }

  List<Block> _echo(List<String> code) {
    var result = <Block>[];

    result.add(Block(['========'], BlockType.Plain));
    result.add(Block(code.toList(), BlockType.Echo));

    return result;
  }
}

class Block {
  final List<String> text;
  final BlockType type;

  Block(List<String> text, this.type) : text = text.toList();
}

enum BlockType {
  Eval, Echo, Plain, CommandSequence
}
