library server.src.endpoints_v1;

import 'dart:async';
import 'dart:io';

import 'package:client/client.dart';

class NoOpPresenter extends Presenter {
  @override
  present() {}
}

class NoOpPresenterFactory extends PresenterFactory {
  @override
  Presenter getPresenter(Message) {
    return new NoOpPresenter();
  }
}

class Client {
  final bool isLegacy;
  final WebSocket webSocket;

  Client(this.webSocket, {this.isLegacy: false});
}

class V1Endpoints {
  static const version = 'v1';

  List<WebSocket> clients = [];
  List<String> messages = [];
  final HttpServer server;
  TransportAtomFactory atomFactory;
  List<Channel> channels =
      ['foo', 'bar', 'baz'].map((t) => new GroupChannel(t));
  Map<String, Function> _handlers = {};

  V1Endpoints(this.server) {
    atomFactory = new TransportAtomFactory(
        new MessageFactory(new NoOpPresenterFactory()), channels);
    _handlers['/'] = _handleLegacyWebSocket;
    _handlers['/$version/ws'] = _handleWebSocket;
    _handlers['/$version/files'] = _handleFile;

    server.listen(_handle);
  }

  Future _handleLegacyWebSocket(HttpRequest req) {
    return _handleWebSocket(req, legacy: true);
  }

  Future _handleWebSocket(HttpRequest req, {legacy: false}) async {
    _log(req);
    WebSocket ws = await WebSocketTransformer.upgrade(req);
    clients.add(ws);
    messages.forEach((m) => ws.add(m));

    ws.listen((d) {
      var atom = atomFactory.fromJson(d);

      switch (atom.type) {
        case AtomType.message:
          break;
        case AtomType.control:
          break;
      }

      clients.forEach((client) => client.add(d));
    })
      ..onDone(() => clients.remove(ws))
      ..onError((error) => print('ERROR: $error'));
  }

  void _handleFile(HttpRequest req) {
    req.response.statusCode = HttpStatus.NOT_IMPLEMENTED;
    req.response.close();
  }

  void _defaultHandler(HttpRequest req) {
    req.response.statusCode = HttpStatus.NOT_FOUND;
    req.response.close();
  }

  void _handle(HttpRequest req) {
    var handler = _handlers[req.uri.path] ?? _defaultHandler;
    handler(req);
    _log(req);
  }

  void _log(HttpRequest req) {
    var timestamp = new DateTime.now();
    print(
        "${timestamp.toIso8601String()} ${req.method}\t${req.uri.path}\t${req.response.statusCode}");
  }
}
