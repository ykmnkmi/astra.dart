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

    var parsed = int.tryParse(value);

    if (parsed == null) {
      usageException("'$name' must be integer");
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
