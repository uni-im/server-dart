import 'dart:io';
import 'dart:convert';

import "./endpoints_v1.dart";

List<WebSocket> clients = new List();
List<String> messages = new List();

main(List<String> args) async {
  HttpServer.bind('0.0.0.0', 8081).then((server) {
    var v1Endpoints = new V1Endpoints(server);
  });
}

void _register(WebSocket ws) {
  // Add client to list
  clients.add(ws);

  // Send all preceding messages
  messages.forEach((m) => ws.add(m));

  // Setup listener
  ws.listen((d) {
    var blob = JSON.decode(d);

    if (blob['type'] != 'AtomType.control') {
      // Queue noncontrol messages
      messages.add(d);
    }

    // Broadcast message
    clients.forEach((client) => client.add(d));

    // Log message
    print(d);
  })
    ..onDone(() => clients.remove(ws))
    ..onError(() => print('error'));
}
