import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:astra/src/cli/type.dart';

Future<void> main() async {
  var directory = Directory.fromUri(Uri(path: 'example'));
  var library = File.fromUri(Uri(path: 'example/lib/example.dart'));

  var collection = AnalysisContextCollection(includedPaths: <String>[directory.absolute.path]);
  var context = collection.contextFor(directory.absolute.path);
  var session = context.currentSession;
  var resolvedLibrary = await session.getResolvedLibrary(library.absolute.path);

  if (resolvedLibrary is! ResolvedLibraryResult) {
    print('library not resolved, got ${resolvedLibrary.runtimeType}');
    exit(0);
  }

  print(getTargetType('example', resolvedLibrary.element));
}
