import 'dart:io';

import 'package:dartboard/src/template.dart';
import 'package:dartboard/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Load from URL', () {
    test('Default URL', () async {
      await _testWithOverrides(() async {
        var template = Template();
        await expectLater(template.ready, completes);
      });
    });

    test('Non-existent URL', () async {
      await _testWithOverrides(() async {
        var url =
            'https://raw.githubusercontent.com/Komposten/dartboard/master/idont.exist';
        var template = Template(templateUrl: url);
        await expectLater(
            template.ready, throwsA(predicate((e) => e is ResourceError)));
      });
    });
  });

  group('Load from file', () {
    test('Load from temp', () async {
      // First load from file to cache a copy in temp.
      var template = Template();
      await template.ready;

      // Now attempt to load from cache.
      await _testWithOverrides(() async {
        var template = Template(templateUrl: null);
        await expectLater(template.ready, completes);
      }, overrideTemp: false);
    });

    test('Load from file', () async {
      await _testWithOverrides(() async {
        var template = Template(templateUrl: null);
        await expectLater(template.ready, completes);
      }, overrideCurrent: false);
    });
  });
}

void _testWithOverrides(Function body,
    {bool overrideCurrent = true, bool overrideTemp = true}) async {
  await IOOverrides.runWithIOOverrides(
      body,
      TestIOOverrides(
        overrideCurrent: overrideCurrent,
        overrideTemp: overrideTemp,
      ));
}

/// IOOverrides which overrides [Directory.current] and [Directory.systemTemp]
/// to make sure [Template] can't load the template from file.
class TestIOOverrides extends IOOverrides {
  final actualCurrent = Directory.current;
  final actualTemp = Directory.systemTemp;
  final dartboardTemp = getTempDir(root: true);
  final bool overrideCurrent;
  final bool overrideTemp;

  TestIOOverrides({this.overrideCurrent = true, this.overrideTemp = true});

  @override
  Directory getCurrentDirectory() {
    if (overrideCurrent) {
      return Directory(p.rootPrefix(actualCurrent.absolute.path));
    } else {
      return actualCurrent;
    }
  }

  @override
  Directory getSystemTempDirectory() {
    if (overrideTemp) {
      var parent = Directory(p.join(dartboardTemp.path, 'tests'));
      parent.createSync(recursive: true);

      return parent.createTempSync();
    } else {
      return actualTemp;
    }
  }
}
