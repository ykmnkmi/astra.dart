import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:io' show HttpServer, HttpRequest;

import 'package:stack_trace/stack_trace.dart' show Trace;

import 'astra.dart';

Future<HttpServer> serve(Application application, Object? address, int port) {
  return HttpServer.bind(address, port).then<HttpServer>((HttpServer server) {
    runZonedGuarded<void>(
      () {
        server.listen((HttpRequest request) {
          final response = request.response;

          Future<DataStreamMessage> receive() {
            return request.first.then((bytes) => DataStreamMessage(bytes));
          }

          void start(int status, List<Header> headers) {
            response.statusCode = status;

            for (final header in headers) {
              response.headers.set(ascii.decode(header.name), ascii.decode(header.value), preserveHeaderCase: true);
            }
          }

          void send(List<int> bytes) {
            response.add(bytes);
          }

          Future<void>.sync(() => application(receive, start, send)).then<void>((_) {
            response.close();
          });
        });
      },
      (Object error, StackTrace stackTrace) {
        print(error);
        print(Trace.format(stackTrace));
      },
    );

    return server;
  });
}
