import 'package:dartboard/src/keywords.dart';
import 'package:test/test.dart';

void main() {
  group('Parsing tests', () {
    test('Test suffix at end', () {
      var match = Keywords.findKeyword('var x = 5; end;');

      expect(match.keyword, equals(Keyword.end));
      expect(match.text, equals('var x = 5; '));
      expect(match.indices, isNotNull);
      expect(match.indices, isEmpty);
    });

    test('Test suffix not at end', () {
      var match = Keywords.findKeyword('end; var x = 5;');
      expect(match, isNull);
    });

    test('Test standalone alone', () {
      var match = Keywords.findKeyword('undo;');

      expect(match.keyword, equals(Keyword.undo));
      expect(match.text, equals(''));
      expect(match.indices, isNotNull);
      expect(match.indices, isEmpty);
    });

    test('Test standalone not alone', () {
      var match = Keywords.findKeyword('undo; var x = 5;');
      expect(match, isNull);
    });

    test('Test prefix at start', () {
      var match = Keywords.findKeyword('insert:2;var x = 5;');

      expect(match.keyword, equals(Keyword.insert));
      expect(match.text, equals('var x = 5;'));
      expect(match.indices, isNotNull);
      expect(match.indices, hasLength(1));
      expect(match.indices, contains(2));
    });

    test('Test prefix not at start', () {
      var match = Keywords.findKeyword('var x = 5; insert:1;');
      expect(match, isNull);
    });
  });
}
