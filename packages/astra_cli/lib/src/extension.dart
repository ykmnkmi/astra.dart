import 'package:astra_cli/src/command.dart';

extension CliCommandExtension on CliCommand {
  bool? getBoolean(String name) {
    return argResults[name] as bool?;
  }

  int? getInteger(String name) {
    var value = argResults[name] as String?;

    if (value == null) {
      return null;
    }

    var parsed = num.parse(value);

    if (parsed < 0 || parsed is double) {
      usageException('$name must be positive integer');
    }

    return parsed as int;
  }

  String? getString(String name) {
    return argResults[name] as String?;
  }

  List<String> getStringList(String name) {
    return argResults[name] as List<String>;
  }
}
