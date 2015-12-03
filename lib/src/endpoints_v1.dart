library server.src.endpoints_v1;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:client/client.dart';
import 'package:http_server/http_server.dart';
import 'package:googleapis/storage/v1.dart' as google;
import 'package:googleapis_auth/auth_io.dart';

part 'configuration.dart';
part 'presenters.dart';

const _scopes = const [google.StorageApi.DevstorageReadWriteScope];

class V1Endpoints {
  static const version = 'v1';
  Configuration configuration;

  TransportAtomFactory _transportFactory;
  MessageFactory _messageFactory;
  List<Channel> _channels = [];
  List<WebSocket> clients = [];
  List<MessageAtom> messages = [];
  final HttpServer server;
  Map<String, Function> _handlers = {};

  google.StorageApi _storageClient;

  V1Endpoints(this.server) {
    _handlers['/$version/ws'] = _handleWs;
    _handlers['/$version/upload'] = _handleUpload;
    _messageFactory = new MessageFactory(new ServerPresenterFactory());
    _transportFactory = new TransportAtomFactory(_messageFactory, _channels);
    server.listen(_handle);

    configuration = new Configuration.fromFile('/tmp/config.json');

    // Setup google webstorage
    new File("/tmp/service.json").readAsString()
      ..then((String json) {
        var credentials = new ServiceAccountCredentials.fromJson(json);
        clientViaServiceAccount(credentials, _scopes)
          ..then((client) => _storageClient = new google.StorageApi(client))
          ..catchError((e) => _log('Unable to create storage client: $e'));
      })
      ..catchError((e) => _log('Unable to load service credential file: $e'));
  }

  Future _handleWs(HttpRequest req) async {
    var ws = await WebSocketTransformer.upgrade(req);
    clients.add(ws);

    messages.forEach((m) {
      ws.add(m.marshal());
    });

    ws.listen((data) {
      var atom = _transportFactory.fromJson(data);

      if (atom is MessageAtom) {
        messages.add(atom);
      }

      _log(atom);
      clients.forEach((client) => client.add(data));
    });
  }

  Future _handleUpload(HttpRequest req) async {
    if (_storageClient == null) {
      return _closeConnection(HttpStatus.SERVICE_UNAVAILABLE, req);
    }

    var bodyStream;
    var request = await HttpBodyHandler.processRequest(req);
    HttpBodyFileUpload upload = request.body['file'];

    if (upload == null) {
      return _closeConnection(HttpStatus.BAD_REQUEST, req);
    }

    if (upload.content is String) {
      bodyStream = new Stream.fromIterable([UTF8.encode(upload.content)]);
    } else {
      bodyStream = new Stream.fromIterable([upload.content]);
    }

    _storageClient.buckets.get('uni-im-files')
      ..then((bucket) {
        google.Media media = new google.Media(bodyStream, upload.content.length,
            contentType: upload.contentType.toString());

        _storageClient.objects.insert(null, bucket.name,
            uploadMedia: media,
            name: upload.filename,
            predefinedAcl: 'publicRead')
          ..then((o) {
            var response = {
              'link': o.mediaLink,
              'content-type': upload.contentType.toString()
            };
            _log("Successfully uploaded file: ${upload.filename}");
            req.response.write(JSON.encode(response));
            req.response.close();
          })
          ..catchError(_log);
      })
      ..catchError(_log);
  }

  void _defaultHandler(HttpRequest req) {
    _closeConnection(HttpStatus.NOT_FOUND, req);
  }

  void _closeConnection(int status, HttpRequest req) {
    req.response.statusCode = status;
    req.response.close();
  }

  void _validateCorsDomains(HttpRequest req) {
    var allowedOrigin = 'origin';
    var requestingOrigin = req.headers.value('origin');

    var isValidOrigin = configuration.CorsDomains
        .any((domain) => domain.origin == requestingOrigin);

    if (isValidOrigin) {
      allowedOrigin = requestingOrigin;
    }

    req.response.headers.add("Access-Control-Allow-Origin", allowedOrigin);
    req.response.headers
        .add("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    req.response.headers.add("Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept");
  }

  void _log(dynamic message) {
    print("${new DateTime.now()} $message");
  }

  void _handle(HttpRequest req) {
    _validateCorsDomains(req);
    (_handlers[req.uri.path] ?? _defaultHandler)(req);
  }
}
