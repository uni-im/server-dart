import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:client/client.dart';

class V1Endpoints {
  static const version = 'v1';

  TransportAtomFactory _transportFactory;
  MessageFactory _serverMessageFactory;
  List<Channel> _channels = [];
  List<WebSocket> clients = [];
  List<Message> messages = [];
  final HttpServer server;
  Map<String, Function> _handlers = {};

  V1Endpoints(this.server) {
    _handlers['/$version/ws'] = _handleWs;
    _handlers['/$version/upload'] = _handleUpload;
    _transportFactory =
        new TransportAtomFactory(_serverMessageFactory, _channels);
    server.listen(_handle);
  }

  void _handleWs(HttpRequest req) {
    req.response.statusCode = HttpStatus.NOT_IMPLEMENTED;
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
