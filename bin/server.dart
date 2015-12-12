import 'dart:io';

import "package:server/server.dart";

main(List<String> args) async {
  // Bind to the default port on any interface
  HttpServer.bind('0.0.0.0', 8081).then((server) {
    // Instantiate a new handler
    new V1Endpoints(server);
  });
}
