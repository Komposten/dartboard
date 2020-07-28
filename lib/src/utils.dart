import 'dart:io';

import 'package:path/path.dart' as p;

const dartboardVersion = '0.1.0';

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

    // Check if we are in a folder called dartboard containing a pubspec file
    if (dirname == 'dartboard') {
      var files = directory.listSync();
      foundRoot = files.any((element) => element.path.endsWith('pubspec.yaml'));
    }

    // If we're not in the correct folder, move to the parent
    if (!foundRoot) {
      var parent = directory.parent;

      if (parent.path == directory.path) {
        throw ResourceError('Could not find dartboard\'s root directory!');
      }

      directory = parent;
    }
  }

  return directory;
}

Directory getTempDir({bool root = false}) {
  final parentPath = p.join(Directory.systemTemp.path, 'dartboard');
  final parentDir = Directory(parentPath);

  if (!parentDir.existsSync()) {
    parentDir.createSync();
  }

  if (root) {
    return parentDir;
  } else {
    return parentDir.createTempSync();
  }
}

void deleteSilently(File file) {
  try {
    if (file.existsSync()) {
      file.deleteSync();
    }
  } catch (_) {
    //ignore
  }
}

class ResourceError extends Error {
  String message;

  ResourceError(this.message);

  @override
  String toString() {
    if (message != null) {
      return 'Resource error: ' + message;
    }
    return 'Resource error';
  }
}
