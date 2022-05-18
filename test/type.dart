
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
  var resolvedUnit = await session.getResolvedUnit(library.absolute.path);

  if (resolvedUnit is! ResolvedUnitResult) {
    print('unit not resolved, got ${resolvedUnit.runtimeType}');
    exit(0);
  }

  print(getTargetType('Hello', resolvedUnit));
}

// ignore_for_file: avoid_print