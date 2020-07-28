import 'dart:io';

import 'package:dartboard/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() {
  test('Correct version number', () {
    var expected = _getExpectedVersion();
    var actual = dartboardVersion;

    expect(actual, equals(expected));
  });
}

String _getExpectedVersion() {
  var pubspecDir = getRootDirectory();
  var pubspecFile = File(p.join(pubspecDir.path, 'pubspec.yaml'));
  var pubspec = yaml.loadYaml(pubspecFile.readAsStringSync());

  return pubspec['version'];
}
