import 'dart:io';

final packageEntryRe = RegExp('^  (\\w+): (.+)\$', multiLine: true);

void main() {
  var versionsUri = Uri.file('tool/package_versions.yaml');
  var resolvedVersionsUri = Directory.current.uri.resolveUri(versionsUri);
  var versionsFile = File.fromUri(resolvedVersionsUri);

  var versions = <String, String>{};

  var lines = versionsFile.readAsLinesSync();

  for (int i = 0; i < lines.length; i += 1) {
    var line = lines[i];

    if (line.isEmpty) {
      continue;
    }

    var parts = line.split(':');
    versions[parts[0]] = parts[1].trimLeft();
  }

  String replace(Match match) {
    return '  ${match[1]}: ${versions[match[1]]}';
  }

  run(Directory.current, replace);

  var directories = Directory.current.listSync(recursive: true);

  for (int i = 0; i < directories.length; i += 1) {
    run(directories[i], replace);
  }
}

void run(FileSystemEntity directory, String Function(Match match) replace) {
  if (directory is Directory) {
    var pubspecFile = File.fromUri(directory.uri.resolve('pubspec.yaml'));

    if (pubspecFile.existsSync()) {
      var oldPubspec = pubspecFile.readAsStringSync();
      var newContent = oldPubspec.replaceAllMapped(packageEntryRe, replace);
      pubspecFile.writeAsStringSync(newContent);
    }
  }
}
