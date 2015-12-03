part of server.src.endpoints_v1;

class Configuration {
  final Iterable<Uri> CorsDomains;

  Configuration(this.CorsDomains);

  factory Configuration.defaultValues() => new Configuration([]);

  factory Configuration.fromFile(String path) {
    try {
      var configFile = new File(path);
      var jsonString = configFile.readAsStringSync();
      var configMap = JSON.decode(jsonString);
      Iterable<Uri> corsDomains =
          configMap['cors-domains']?.map(Uri.parse) ?? [];

      return new Configuration(corsDomains);
    } catch (e) {
      return new Configuration.defaultValues();
    }
  }
}
