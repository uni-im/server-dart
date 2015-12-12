part of server.src.endpoints_v1;

/// Allows for the abstraction and deserialization of a json configuation file
/// containing runtime parameters
class Configuration {
  /// An unmodifiable list of domains which are allowed to make requests from
  final Iterable<Uri> CorsDomains;

  Configuration(this.CorsDomains);

  /// A factory function for creating default configuration options
  factory Configuration.defaultValues() => new Configuration([]);

  /// A factory function that reads a given file path and creates a immutable
  /// configuration object.
  factory Configuration.fromFile(String path) {
    try {
      var configFile = new File(path);
      var jsonString = configFile.readAsStringSync();
      var configMap = JSON.decode(jsonString);
      Iterable<Uri> corsDomains =
          configMap['cors-domains']?.map(Uri.parse) ?? [];

      return new Configuration(corsDomains);
    } catch (e) {
      // Any errors end up returning a default configuration
      return new Configuration.defaultValues();
    }
  }
}
