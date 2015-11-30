import 'dart:async';
import 'dart:io';

import 'package:client/client.dart';

class ServerPresenter extends Presenter {
  present() {}
}

class ServerPresenterFactory extends PresenterFactory {
  @override
  Presenter getPresenter(Message m) => new ServerPresenter();
}

class V1Endpoints {
  static const version = 'v1';

  TransportAtomFactory _transportFactory;
  MessageFactory _messageFactory;
  List<Channel> _channels = [];
  List<WebSocket> clients = [];
  List<MessageAtom> messages = [];
  final HttpServer server;
  Map<String, Function> _handlers = {};

  V1Endpoints(this.server) {
    _handlers['/$version/ws'] = _handleWs;
    _handlers['/$version/upload'] = _handleUpload;
    _messageFactory = new MessageFactory(new ServerPresenterFactory());
    _transportFactory = new TransportAtomFactory(_messageFactory, _channels);
    server.listen(_handle);
  }

  Future _handleWs(HttpRequest req) async {
    var ws = await WebSocketTransformer.upgrade(req);
    clients.add(ws);

    messages.forEach((m) {
      ws.add(m.marshal());
    });

    ws.listen((data) {
      var atom = _transportFactory.fromJson(data);
      var now = new DateTime.now();

      if (atom is MessageAtom) {
        messages.add(atom);
      }

      print("${now}: $atom");
      clients.forEach((client) => client.add(data));
    });
  }

  void _handleUpload(HttpRequest req) {
    req.response.statusCode = HttpStatus.NOT_IMPLEMENTED;
  }

  void _defaultHandler(HttpRequest req) {
    req.response.statusCode = HttpStatus.NOT_FOUND;
    req.response.close();
  }

  void _handle(HttpRequest req) {
    (_handlers[req.uri.path] ?? _defaultHandler)(req);
  }
}
