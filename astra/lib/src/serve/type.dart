enum ServerType {
  shelf('HTTP/1.x shelf server.');

  const ServerType(this.description);

  final String description;

  static const ServerType defaultType = shelf;

  static List<String> get names {
    return <String>[shelf.name];
  }

  static Map<String, String> get descriptions {
    return <String, String>{shelf.name: shelf.description};
  }
}
