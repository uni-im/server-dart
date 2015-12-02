part of server.src.endpoints_v1;

class Configuration {
  final Iterable<Uri> CorsDomains;

  Configuration(this.CorsDomains);

  factory Configuration.defaultValues() => new Configuration([]);

  factory Configuration.fromFile(String path) {
    new File(path).readAsString().then((v) {
      var configMap = JSON.decode(v);
      Iterable<Uri> corsDomains =
          configMap['cors-domains']?.map(Uri.parse) ?? [];

      return new Configuration(corsDomains);
    }).catchError((e) {
      print('Used default configuration: $e');
      return new Configuration.defaultValues();
    }, test: (e) => e is FileSystemException);
  }
}
