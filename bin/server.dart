import 'dart:io';

import "package:server/server.dart";

List<WebSocket> clients = new List();
List<String> messages = new List();

main(List<String> args) async {
  HttpServer.bind('0.0.0.0', 8081).then((server) {
    new V1Endpoints(server);
  });
}
