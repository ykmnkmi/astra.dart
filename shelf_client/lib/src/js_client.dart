/// @docImport 'package:web/web.dart';
library;

import 'dart:async' show Completer, Future, FutureOr;
import 'dart:convert' show ByteConversionSink;
import 'dart:js_interop'
    show
        FunctionToJSExportedDartFunction,
        JS,
        JSFunction,
        JSFunctionUtilExtension,
        JSObject,
        JSPromise,
        JSUint8Array,
        JSUint8ArrayToUint8List,
        Uint8ListToJSUint8Array;
import 'dart:typed_data' show Uint8List;

import 'package:shelf/shelf.dart' show Pipeline, Request, Response;
import 'package:shelf_client/src/base_client.dart';
import 'package:shelf_client/src/client.dart';
import 'package:web/web.dart' as web;

/// Create an [JSClient].
Client createClient({Pipeline? pipeline}) {
  return JSClient(pipeline: pipeline);
}

@JS('Function')
external JSFunction _createFunction(String functionBody);

@JS('_fetch')
external JSPromise<_JSResponse> _fetch(
  String method,
  String url,
  web.Headers headers,
  JSUint8Array body,
  web.AbortSignal signal,
);

extension type _JSResponse(JSObject _) implements JSObject {
  external int get status;

  external web.Headers get headers;

  external JSUint8Array get body;
}

extension on JSPromise<_JSResponse> {
  external void then(JSFunction callback);
}

extension on web.Headers {
  external void forEach(JSFunction fn);
}

/// A `dart:js_interop`-based HTTP [Client] backed by
/// [`fetch`](https://fetch.spec.whatwg.org/).
base class JSClient extends BaseClient {
  // TODO(fetch): Make it streaming and handle errors.
  static final _init = _createFunction('''
window._fetch ??= (method, url, headers, body, signal) => {
  method = method.toUpperCase();

  const options = {method, headers, signal};

  if (method != 'GET' && method != 'HEAD') {
    options.body = body;
  }

  return fetch(url, options).then((response) => {
    return response.arrayBuffer().then((buffer) => {
      return {
        status: response.status,
        headers: response.headers,
        body: new Uint8Array(buffer),
      };
    });
  });
};''');

  JSClient({Pipeline? pipeline})
    : _pipeline = pipeline,
      _abortController = web.AbortController(),
      _closed = false {
    _init.callAsFunction();
  }

  /// The underlying [Pipeline] used to handle requests.
  final Pipeline? _pipeline;

  final web.AbortController _abortController;

  bool _closed;

  @override
  Future<Response> send(Request request) {
    if (_closed) {
      return Future<Response>.error(StateError('Client is already closed.'));
    }

    Future<Response> handler(Request request) {
      var requestStream = request.read();
      var requestBodyCompleter = Completer<Uint8List>();

      void onRequestBytes(List<int> bytes) {
        requestBodyCompleter.complete(Uint8List.fromList(bytes));
      }

      var sink = ByteConversionSink.withCallback(onRequestBytes);

      requestStream.listen(
        sink.add,
        onError: requestBodyCompleter.completeError,
        onDone: sink.close,
        cancelOnError: true,
      );

      Future<Response> onBytes(Uint8List bytes) {
        var jsHeaders = web.Headers();

        request.headers.forEach((name, value) {
          jsHeaders.set(name, value);
        });

        var jsRequestBodyBytes = bytes.toJS;

        var jsResponsePromise = _fetch(
          request.method,
          '${request.requestedUri}',
          jsHeaders,
          jsRequestBodyBytes,
          _abortController.signal,
        );

        var responseCompleter = Completer<Response>();

        void onResponse(_JSResponse jsResponse) {
          var status = jsResponse.status;
          var headers = <String, String>{};
          var body = jsResponse.body.toDart;

          jsResponse.headers.forEach(
            (String value, String name) {
              headers[name.toLowerCase()] = value;
            }.toJS,
          );

          responseCompleter.complete(
            Response(status, headers: headers, body: body),
          );
        }

        jsResponsePromise.then(onResponse.toJS);
        return responseCompleter.future;
      }

      return requestBodyCompleter.future.then<Response>(onBytes);
    }

    FutureOr<Response> Function(Request) handle;

    if (_pipeline != null) {
      handle = _pipeline.addHandler(handler);
    } else {
      handle = handler;
    }

    return Future<Response>.value(handle(request));
  }

  /// {@macro astra_client_close}
  ///
  /// Terminates all active connections.
  @override
  FutureOr<void> close() {
    _abortController.abort();
    _closed = true;
  }
}
