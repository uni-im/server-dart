import 'dart:io';

class V1Endpoints {
  static const version = 'v1';

  List<WebSocket> clients = [];
  List<String> messages = [];
  final HttpServer server;
  Map<String, Function> _handlers = {};

  V1Endpoints(this.server) {
    _handlers['/$version/ws'] = _handleWs;
    _handlers['/$version/upload'] = _handleUpload;

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
    var handler = _handlers[req.uri.path] ?? _defaultHandler;

    handler(req);
  }
}
