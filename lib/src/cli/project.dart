import 'dart:io';

import 'package:yaml/yaml.dart';

mixin Project {
  // TODO: `--directory` option
  Directory get directory {
    return Directory.current;
  }

  File get specificationFile {
    return File.fromUri(directory.uri.resolve('pubspec.yaml'));
  }

  Map<String, Object?>? cachedSpecification;

  Map<String, Object?> get specification {
    var specification = cachedSpecification;

    if (specification != null) {
      return specification;
    }

    var file = specificationFile;

    if (file.existsSync()) {
      var content = file.readAsStringSync();
      var yaml = loadYaml(content) as Map<Object?, Object?>;
      return yaml.cast<String, Object?>();
    }

    throw Exception('Failed to locate pubspec.yaml in \'${directory.path}\'');
  }

  String get package {
    return specification['name'] as String;
  }

  String get library {
    return '$package.dart';
  }
}
