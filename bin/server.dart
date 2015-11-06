import 'dart:io';

List<WebSocket> clients = new List();
List<String> messages = new List();

main(List<String> args) async {
  HttpServer.bind('0.0.0.0', 8080).then((server) {
    server
        .asyncMap(WebSocketTransformer.upgrade)
        .handleError((e) => print("Error: $e"))
        .forEach(_register);
  });
}

void _register(WebSocket ws) {
  // Add client to list
  clients.add(ws);

  // Send all preceding messages
  messages.forEach((m) => ws.add(m));

  // Setup listener
  ws.listen((d) {
    // Queue messages
    messages.add(d);

    // Broadcast message
    clients.forEach((client) => client.add(d));

    // Log message
    print(d);
  })
    ..onDone(() => clients.remove(ws))
    ..onError(() => print('error'));
}