import 'dart:async' show Completer, Future, FutureOr;
import 'dart:convert' show ByteConversionSink;
import 'dart:js_interop'
    show
        JS,
        JSAny,
        JSArray,
        JSArrayToList,
        JSFunction,
        JSFunctionUtilExtension,
        JSObject,
        JSPromise,
        JSPromiseToFuture,
        JSString,
        JSUint8Array,
        JSUint8ArrayToUint8List,
        StringToJSString,
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
external JSFunction _createFetch(
  String url,
  String body,
  String headers,
  String method,
  String expression,
);

extension type _JSResponse(JSObject _) implements JSObject {
  external int get status;

  external web.Headers get headers;

  external JSUint8Array get body;
}

@JS('Array.from')
external JSArray<T> arrayFrom<T extends JSAny?>(JSAny? arrayLike);

extension on web.Headers {
  external JSAny entries();
}

extension on JSArray<JSString> {
  external String operator [](int index);
}

/// A `dart:js_interop`-based HTTP [Client].
base class JSClient extends BaseClient {
  static final _fetch = _createFetch('url', 'body', 'headers', 'method', '''
  method = method.toUpperCase();

  const options = {headers: headers, method: method};

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
''');

  JSClient({Pipeline? pipeline})
      : _pipeline = pipeline,
        _closed = false;

  /// The underlying [Pipeline] used to handle requests.
  final Pipeline? _pipeline;

  bool _closed;

  @override
  Future<Response> send(Request request) {
    if (_closed) {
      return Future<Response>.error(StateError('Client is already closed.'));
    }

    Future<Response> handler(Request request) {
      var requestStream = request.read();
      var requestBodyCompleter = Completer<Uint8List>.sync();

      void onRequestBytes(List<int> bytes) {
        requestBodyCompleter.complete(Uint8List.fromList(bytes));
      }

      var sink = ByteConversionSink.withCallback(onRequestBytes);
      requestStream.listen(sink.add,
          onError: requestBodyCompleter.completeError,
          onDone: sink.close,
          cancelOnError: true);

      Future<Response> onBytes(Uint8List bytes) {
        var jsRequestBodyBytes = bytes.toJS;

        var jsHeaders = web.Headers();

        request.headers.forEach((String name, String value) {
          jsHeaders.set(name, value);
        });

        var jsPromise = _fetch.callAsFunction(
            null,
            '${request.requestedUri}'.toJS,
            jsRequestBodyBytes,
            jsHeaders,
            request.method.toJS);

        var jsResponsePrmoise = jsPromise as JSPromise<_JSResponse>;
        return jsResponsePrmoise.toDart.then<Response>(_onResponse);
      }

      return requestBodyCompleter.future.then<Response>(onBytes);
    }

    FutureOr<Response> Function(Request) handle;

    if (_pipeline case var pipeline?) {
      handle = pipeline.addHandler(handler);
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
    _closed = true;
  }

  static Response _onResponse(_JSResponse jsResponse) {
    var status = jsResponse.status;
    var headers = <String, List<String>>{};
    var body = jsResponse.body.toDart;

    var jsEntries = arrayFrom<JSArray<JSString>>(jsResponse.headers.entries());
    var entries = jsEntries.toDart;

    for (var i = 0; i < entries.length; i += 1) {
      var entry = entries[i];
      var name = entry[0];
      var value = entry[1];

      if (value.contains(',')) {
        headers[name] = _parseHeaderValues(value);
      } else {
        headers[name] = <String>[value];
      }
    }

    return Response(status, headers: headers, body: body);
  }
}

List<String> _parseHeaderValues(String value) {
  var values = <String>[];

  var inQuote = false;
  var escapeNext = false;

  var length = value.length;
  var start = 0;

  for (var offset = 0; offset < length; offset += 1) {
    if (escapeNext) {
      escapeNext = false;
      continue;
    }

    switch (value[offset]) {
      case '"':
        inQuote = !inQuote;
        break;

      case '\\':
        escapeNext = true;
        break;

      case ',':
        if (!inQuote) {
          values.add(value.substring(start, offset).trim());
          start = offset + 1;
        }

        break;
    }
  }

  // Add the last value if exists
  if (start < length) {
    values.add(value.substring(start).trim());
  }

  return values;
}
