import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartboard/src/utils.dart' as utils;
import 'package:path/path.dart' as p;

class Template {
  static const defaultTemplateUrl =
      'https://raw.githubusercontent.com/Komposten/dartboard/${utils.dartboardVersion}/lib/res/eval_template.dart';

  final String _templateUrl;
  final _completer = Completer<bool>();
  String _template;

  Template({String templateUrl})
      : _templateUrl = templateUrl ?? defaultTemplateUrl {
    _load();
  }

  String get code => _template;

  Future<bool> get ready async => _completer.future;

  void _load() async {
    try {
      var template = await _tryLoadTemplateFromFile();
      template ??= await _tryLoadTemplateFromUrl();

      _template = template;
      _trySaveTemplate();
      _completer.complete(true);
    } on HttpException catch (e, trace) {
      var error = utils.ResourceError(
          'No local template file found, and the fetch request to GitHub returned ${e.message}'
          '\nRequest URL: $_templateUrl');
      _completer.completeError(error, trace);
    } catch (e, trace) {
      var error =
          utils.ResourceError('Failed to load template file: ${e.toString()}');
      _completer.completeError(error, trace);
    }
  }

  Future<String> _tryLoadTemplateFromFile() async {
    try {
      var dartboardDir = utils.getRootDirectory().path;
      var path = p.join(dartboardDir, 'lib', 'res', 'eval_template.dart');
      return File(path).readAsString();
    } on utils.ResourceError {
      var templateFile = _getTemplateTempFile();

      if (await templateFile.exists()) {
        return templateFile.readAsString();
      } else {
        return null;
      }
    }
  }

  Future<String> _tryLoadTemplateFromUrl() async {
    var client = HttpClient();
    var request = await client.getUrl(Uri.parse(_templateUrl));
    var response = await request.close();

    if (response.statusCode == HttpStatus.ok) {
      return response.transform(utf8.decoder).join();
    }

    return Future.error(
        HttpException('${response.statusCode} (${response.reasonPhrase})'));
  }

  void _trySaveTemplate() {
    var file = _getTemplateTempFile();

    try {
      file.writeAsStringSync(_template);
    } catch (e) {
      utils.deleteSilently(file);
    }
  }

  File _getTemplateTempFile() {
    var tempDir = utils.getTempDir(root: true);
    return File(p.join(tempDir.path, 'template.dart'));
  }
}
