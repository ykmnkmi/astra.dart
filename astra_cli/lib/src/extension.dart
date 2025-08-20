import 'package:astra_cli/src/command.dart';

extension CliCommandExtension on CliCommand {
  bool? getBoolean(String name) {
    return argResults[name] as bool?;
  }

  int? getInteger(String name, [int? minValue]) {
    var value = argResults[name] as String?;

    if (value == null) {
      return null;
    }

    int parsed;

    try {
      parsed = int.parse(value);
    } on FormatException {
      usageException("'$name' must be integer, got '$value'.");
    }

    if (minValue != null && parsed < minValue) {
      usageException(
        '$name must be equal or greater than $minValue, got $parsed.',
      );
    }

    return parsed;
  }

  String? getString(String name) {
    return argResults[name] as String?;
  }

  List<String> getStringList(String name) {
    return argResults[name] as List<String>;
  }
}
