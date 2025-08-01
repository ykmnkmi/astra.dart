/// A enumeration representing types of server implementations.
enum ServerType {
  /// Represents the HTTP/1.x shelf server.
  shelf('HTTP/1.x shelf server.');

  // Constructor for the ServerType enumeration.
  const ServerType(this.description);

  /// The human-readable description of this server type.
  final String description;

  /// The default server type, which is the 'shelf' server.
  static const ServerType defaultType = shelf;

  /// Retrieves the names of available server types.
  static List<String> get names {
    return <String>[for (var type in values) type.name];
  }

  /// Retrieves descriptions of available server types.
  static Map<String, String> get descriptions {
    return <String, String>{
      for (var type in values) type.name: type.description,
    };
  }
}
