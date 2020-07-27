import 'dart:io';

import 'package:path/path.dart' as p;

Directory getRootDirectory() {
  var scriptUri = Platform.script;
  var baseDir = Directory.current;

  if (scriptUri.scheme == 'file') {
    baseDir = Directory(p.dirname(Platform.script.toFilePath()));
  }

  return _findRootDirectory(baseDir);
}

Directory _findRootDirectory(Directory startingPoint) {
  var directory = startingPoint;
  var foundRoot = false;

  while (!foundRoot) {
    var dirname = p.basename(directory.path);

    // Check if we are in a folder called dart_repl containing a pubspec file
    if (dirname == 'dart_repl') {
      var files = directory.listSync();
      foundRoot = files.any((element) => element.path.endsWith('pubspec.yaml'));
    }

    // If we're not in the correct folder, move to the parent
    if (!foundRoot) {
      directory = directory.parent;
    }
  }

  return directory;
}
