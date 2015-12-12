# server-dart
A simple dart websocket multiplexer

## Building

Given you have a valid Dart runtime, you can get the dependencies:
```
pub upgrade
```

And run the server:
```
dart bin/server.dart
```

Tagged releases are built and deployed as docker containers. Given a valid docker configuration you can start an instance with:
```
docker run -v $PATH_TO_CONFIGS_AND_CREDENTIALS:/tmp -p 8081:8081 benjica/uni-im-server-dart:latest
```
