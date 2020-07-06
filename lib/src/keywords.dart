class Keywords {
  static Keyword findKeyword(String text) {
    text = text.trim();

    return Keyword.values
        .firstWhere((keyword) => keyword.inString(text), orElse: () => null);
  }
}

class Keyword {
  final String keyword;
  final bool _requiresSeparateLine;

  const Keyword._internal(this.keyword, this._requiresSeparateLine);

  static const end = Keyword._internal('end;', false);
  static const eval = Keyword._internal('eval;', false);
  static const exit = Keyword._internal('exit;', true);
  static const undo = Keyword._internal('undo;', true);
  static const echo = Keyword._internal('echo;', true);

  static const _values = [end, eval, exit, undo, echo];

  static List<Keyword> get values => _values;

  bool inString(String string) {
    if (_requiresSeparateLine) {
      return keyword == string;
    } else {
      return string.endsWith(keyword);
    }
  }
}
