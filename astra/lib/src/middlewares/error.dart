import 'dart:async' show Future;
import 'dart:convert' show htmlEscape;
import 'dart:io' show File;
import 'dart:isolate' show Isolate;

import 'package:astra/src/core/error.dart';
import 'package:astra/src/core/handler.dart';
import 'package:astra/src/core/middleware.dart';
import 'package:astra/src/core/request.dart';
import 'package:astra/src/core/response.dart';
import 'package:astra/src/middlewares/utils.dart';
import 'package:stack_trace/stack_trace.dart' show Frame, Trace;

String _renderPageTitle(Object error, Trace trace) {
  var parts = error.toString().split(':');
  var type = parts.length > 1 ? parts.removeAt(0).trim() : 'Error';
  var message = parts.join(':');
  return '$type: $message';
}

String _renderType(Object error, Trace trace) {
  var parts = error.toString().split(':');
  var type = parts.length > 1 ? parts[0].trim() : 'Error';
  return '<h1>$type</h1>';
}

String _renderMessage(Object error, Trace trace) {
  var parts = error.toString().split(':');
  var message = parts.skip(1).join(':');
  return '<h2>$message</h2>';
}

String _renderTitle(Object error, Trace trace) {
  return '<p class="title">Traceback</p>';
}

String _renderFrame(Frame frame, [bool full = false]) {
  var Frame(:library, :line, :column, :member) = frame;

  var result =
      '<div class="frame">'
      '<span class="library">${library.replaceAll('\\', '/')}</span> '
      '$line:$column, '
      'in <span class="member">${htmlEscape.convert(member!)}</span>';

  if (full && frame.line != null) {
    Uri uri;

    if (frame.uri.scheme == 'package') {
      uri = Isolate.resolvePackageUriSync(frame.uri)!;
    } else {
      uri = frame.uri;
    }

    var file = File.fromUri(uri);
    var lines = file.readAsLinesSync();
    var line = frame.line ?? 1;
    result = '$result<br><pre>${lines[line - 1].trim()}</pre>';
  }

  return '$result</div>';
}

Iterable<String> _renderFrames(Object error, Trace trace) sync* {
  var frames = trace.frames.reversed.toList();
  var lastFrame = frames.removeLast();

  for (var frame in frames) {
    if (isCoreFrame(frame)) {
      continue;
    }

    yield _renderFrame(frame);
  }

  yield _renderFrame(lastFrame, true);
}

String _render(Object error, Trace trace) {
  return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>${_renderPageTitle(error, trace)}</title>
    <style>
      html, body {
        heidht: 100%;
        margin: 0;
        width: 100%;
      }

      body {
        font-family: monospace;
        font-size: 16px;
      }

      main {
        margin: 1em auto;
        max-width: 64em;
      }

      pre {
        background-color: #EEEEEE;
        border: 1px solid lightgrey;
        margin: 0.5em 0em 0em;
        padding: 0.25em 0.5em 0.35em;
      }

      .traceback {
        border: 1px solid lightgrey;
        overflow: hidden;
      }

      .traceback > .title {
        background-color: #EEEEEE;
        border-bottom: 1px solid lightgrey;
        font-size: 1.25em;
        margin: 0em;
        padding: 0.5em
      }

      .frame {
        padding: 0.5em;
      }

      .frame > .library {
        color:#0175C2;
      }

      .frame > .member {
        background-color: #EEEEEE;
        border-radius: 0.2em;
        padding: 0.05em 0.3em;
      }
    </style>
  </head>
  <body>
    <main>
      ${_renderType(error, trace)}
      ${_renderMessage(error, trace)}
      <div class="traceback">
        ${_renderTitle(error, trace)}
        ${_renderFrames(error, trace).join('\n      ')}
      </div>
    </main>
  </body>
</html>
''';
}

/// Middleware which catches errors thrown by inner handlers and returns a
/// response with a 500 status code.
///
/// If [debug] is `true`, the error message and stack trace are returned in the
/// response body. If [debug] is `false` (the default), a generic error message
/// is returned.
Middleware error({bool debug = false, ErrorHandler? errorHandler}) {
  Handler middleware(Handler innerHandler) {
    Future<Response> handler(Request request) async {
      try {
        return await innerHandler(request);
      } on HijackException {
        rethrow;
      } catch (error, stackTrace) {
        if (debug) {
          var accept = request.headers['accept'];

          if (accept != null && accept.contains('text/html')) {
            const headers = <String, String>{'content-type': 'text/html'};

            var trace = Trace.from(stackTrace);
            var body = _render(error, trace);
            return Response.internalServerError(body: body, headers: headers);
          }

          var trace = Trace.format(stackTrace);
          return Response.internalServerError(body: '$error\n$trace');
        }

        if (errorHandler == null) {
          return Response.internalServerError();
        }

        return errorHandler(request, error, stackTrace);
      }
    }

    return handler;
  }

  return middleware;
}
