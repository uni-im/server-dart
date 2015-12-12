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

/// Required scopes for connecting to google cloud storage
const _scopes = const [google.StorageApi.DevstorageReadWriteScope];

/// A endpoint class that registers listeners for a backend service
class V1Endpoints {
  /// The current version of the endpoints
  static const version = 'v1';

  /// The configuration for the endpoint instance
  Configuration configuration;

  /// A list of detected channels
  List<Channel> _channels = [];

  /// A collection of current web socket connections
  List<WebSocket> clients = [];

  /// A collection of strings representing requested paths and a corresponding
  /// handler function for the connection.
  Map<String, Function> _handlers = {};

  /// A factory for instantianting messages
  MessageFactory _messageFactory;

  /// A collection of messages recived by web socket connections
  List<MessageAtom> messages = [];

  /// A connection client for making API calls to the Google Cloud Storage
  /// service.
  google.StorageApi _storageClient;

  /// A factory for deserialized json messages
  TransportAtomFactory _transportFactory;

  V1Endpoints(HttpServer server) {
    // register handlers
    _handlers['/$version/ws'] = _handleWs;
    _handlers['/$version/upload'] = _handleUpload;

    // Setup factories
    _messageFactory = new MessageFactory(new ServerPresenterFactory());
    _transportFactory = new TransportAtomFactory(_messageFactory, _channels);

    // Bind to stream of incoming HTTP requests
    server.listen(_handle);

    // Attempt to build configuration from default configuration file
    configuration = new Configuration.fromFile('/tmp/config.json');

    // Setup google webstorage by reading credential file
    new File("/tmp/service.json").readAsString()
      ..then((String json) {
        // Parse json service file into a credential object
        var credentials = new ServiceAccountCredentials.fromJson(json);

        // Create a new storage client based on the credentialing and
        // api scopes. Any errors are logged to stdout.
        clientViaServiceAccount(credentials, _scopes)
          ..then((client) => _storageClient = new google.StorageApi(client))
          ..catchError((e) => _log('Unable to create storage client: $e'));
      })
      ..catchError((e) => _log('Unable to load service credential file: $e'));
  }

  /// A handler for incoming web connections
  Future _handleWs(HttpRequest req) async {
    // Convert the incoming HTTP request into a websocket connection
    var ws = await WebSocketTransformer.upgrade(req);

    // Add the connection to the list of active clients
    clients.add(ws);

    // Send all preceding messages to the new client
    messages.forEach((m) {
      ws.add(m.marshal());
    });

    // Subscribe to the stream of incoming data from the web socket and
    // convert the json blob into a TransportAtom
    ws.listen((data) {
      var atom = _transportFactory.fromJson(data);

      // Store message in collection of previous messages
      if (atom is MessageAtom) {
        messages.add(atom);
      }

      // Log data event and send the data to all active clients
      _log(atom);
      clients.forEach((client) => client.add(data));
    });
  }

  /// Handles requests that indicate a file upload
  Future _handleUpload(HttpRequest req) async {
    // Return error to client when the persistance mechanism is unavailable
    if (_storageClient == null) {
      return _closeConnection(HttpStatus.SERVICE_UNAVAILABLE, req);
    }

    // Setup file upload parameters
    var bodyStream;
    var request = await HttpBodyHandler.processRequest(req);
    HttpBodyFileUpload upload = request.body['file'];

    if (upload == null) {
      // Return error to client if upload data is malformed
      return _closeConnection(HttpStatus.BAD_REQUEST, req);
    }

    // Configure input data stream depending on type
    bodyStream = upload.content is String
        ? new Stream.fromIterable([UTF8.encode(upload.content)])
        : new Stream.fromIterable([upload.content]);

    // Make api call to Google Cloud Storage for a bucket
    _storageClient.buckets.get('uni-im-files')
      ..then((bucket) {
        // Prepare api object to upload user uploaded file
        google.Media media = new google.Media(bodyStream, upload.content.length,
            contentType: upload.contentType.toString());

        // Make an api call to upload the file
        _storageClient.objects.insert(null, bucket.name,
            uploadMedia: media,
            name: upload.filename,
            predefinedAcl: 'publicRead')
          ..then((o) {
            // Successful uploads will create a response JSON token returned
            // to the client
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

  /// The default handler returns a 404
  void _defaultHandler(HttpRequest req) {
    _closeConnection(HttpStatus.NOT_FOUND, req);
  }

  /// A helper function to close a client connection with a given status code
  void _closeConnection(int status, HttpRequest req) {
    req.response.statusCode = status;
    req.response.close();
  }

  /// If client is making a request from a page served on a differnt host or
  /// port the response should include an appropriate CORS header to validate
  /// the response. The configuration object allows for a list of acceptable
  /// origins and updates all response to inlcude a valid origin value to allow
  /// requests to complete. If a request is made from an unspecified origin the
  /// CORS headers will return the default value of origin causing the client
  /// code to fail.
  void _validateCorsDomains(HttpRequest req) {
    var allowedOrigin = 'origin';
    var requestingOrigin = req.headers.value('origin');

    // Compare the request origin with the list of valid origins
    var isValidOrigin = configuration.CorsDomains
        .any((domain) => domain.origin == requestingOrigin);

    if (isValidOrigin) {
      // update allowed origin if validated
      allowedOrigin = requestingOrigin;
    }

    // Update respone headers with a altered CORS value
    req.response.headers.add("Access-Control-Allow-Origin", allowedOrigin);
    req.response.headers
        .add("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    req.response.headers.add("Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept");
  }

  /// A logging helper
  void _log(dynamic message) {
    print("${new DateTime.now()} $message");
  }

  /// All requests enter this handler which maps the request path with an
  /// registered handler
  void _handle(HttpRequest req) {
    _validateCorsDomains(req);
    (_handlers[req.uri.path] ?? _defaultHandler)(req);
  }
}
