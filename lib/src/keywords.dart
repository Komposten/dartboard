class Keywords {
  static KeywordMatch findKeyword(String text) {
    text = text.trim();

    Keyword keyword;
    RegExpMatch match;

    for (keyword in Keyword.values) {
      match = keyword.pattern.firstMatch(text);

      if (match != null) {
        break;
      }
    }

    if (match != null) {
      text = text.substring(0, match.start) + text.substring(match.end);
      var indices = <int>[];

      for (var i = 0; i < keyword.indices; i++) {
        indices.add(int.tryParse(match.group(i + 1)));
      }

      return KeywordMatch(keyword, text, indices);
    }

    return null;
  }
}

class KeywordMatch {
  final Keyword keyword;
  final String text;
  final List<int> indices;

  const KeywordMatch(this.keyword, this.text, this.indices);
}

class Keyword {
  final String value;
  final int indices;
  final _KeywordType _type;
  final RegExp pattern;

  Keyword._internal(this.value, this._type, {this.indices = 0})
      : pattern = _generatePattern(value, _type, indices);

  static final Keyword end = Keyword._internal('end', _KeywordType.Suffix);
  static final Keyword eval = Keyword._internal('eval', _KeywordType.Suffix);
  static final Keyword exit =
      Keyword._internal('exit', _KeywordType.Standalone);
  static final Keyword undo =
      Keyword._internal('undo', _KeywordType.Standalone);
  static final Keyword echo =
      Keyword._internal('echo', _KeywordType.Standalone);
  static final Keyword clear =
      Keyword._internal('clear', _KeywordType.Standalone);
  static final Keyword delete =
      Keyword._internal('delete', _KeywordType.Prefix, indices: 1);
  static final Keyword insert =
      Keyword._internal('insert', _KeywordType.Prefix, indices: 1);
  static final Keyword edit =
      Keyword._internal('edit', _KeywordType.Prefix, indices: 1);

  static final _values = [
    end,
    eval,
    exit,
    undo,
    echo,
    clear,
    delete,
    edit,
    insert
  ];

  static List<Keyword> get values => _values;

  int getIndex(String string) {
    var result = -1;

    if (_type == _KeywordType.Prefix) {
      var group1 = pattern.firstMatch(string).group(1);

      if (group1 != null) {
        result = int.tryParse(group1) ?? result;
      }
    }

    return result;
  }

  static RegExp _generatePattern(
      String value, _KeywordType _type, int _indices) {
    var pattern = value;

    for (var i = 0; i < _indices; i++) {
      pattern += r':(\d+)';
    }

    pattern += ';';

    switch (_type) {
      case _KeywordType.Prefix:
        pattern = '^$pattern';
        break;

      case _KeywordType.Suffix:
        pattern = '$pattern\$';
        break;

      case _KeywordType.Standalone:
        pattern = '^$pattern\$';
        break;

      default:
        break;
    }

    return RegExp(pattern);
  }
}

enum _KeywordType { Prefix, Suffix, Standalone }
