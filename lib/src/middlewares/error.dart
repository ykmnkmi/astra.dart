import 'dart:convert';
import 'dart:io';

import 'package:astra/core.dart';
import 'package:stack_trace/stack_trace.dart';

class ServerErrorMiddleware {
  ServerErrorMiddleware(
      {this.debug = false,
      this.headers = const <String, String>{'content-type': 'text/html'},
      this.handler});

  final bool debug;

  final Map<String, String> headers;

  final HttpErrorHandler? handler;

  Handler call(Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (error, stackTrace) {
        if (debug) {
          var accept = request.headers['accept'];

          if (accept != null && accept.contains('text/html')) {
            var trace = Trace.from(stackTrace);
            var body = render(error, trace);
            return Response.internalServerError(body: body, headers: headers);
          }

          var trace = Trace.format(stackTrace);
          return Response.internalServerError(body: '$error\n$trace');
        }

        var errorHandler = this.handler;

        if (errorHandler == null) {
          return Response.internalServerError();
        }

        return errorHandler(request, error, stackTrace);
      }
    };
  }

  String renderPageTitle(Object error, Trace trace) {
    var parts = error.toString().split(':');
    var type = parts.length > 1 ? parts.removeAt(0).trim() : 'Error';
    var message = parts.join(':').trim();
    return '$type: $message';
  }

  String render(Object error, Trace trace) {
    return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>${renderPageTitle(error, trace)}</title>
    <style>
      body {
        font-family: "JetBrains Mono", "Cascadia Mono", "Fira Mono", "Ubuntu Mono", "DejaVu Sans Mono", Menlo, Consolas, "Liberation Mono", Monaco, "Lucida Console", monospace;
      }

      pre {
        background-color: #EEEEEE;
        border: 1px solid lightgrey;
        margin: 0.5em 0em 0em;
        padding: 0.25em 0.5em 0.35em;
      }

      .traceback {
        border: 1px solid lightgrey;
        overflow:hidden;
      }

      .traceback > .title {
        background-color: #EEEEEE;
        border-bottom: 1px solid lightgrey;
        font-size: 1.25em;
        margin: 0em;
        padding: 0.5em
      }

      .frame {
        padding: 0.25em 0.5em;
      }

      .frame > .library {
        color:#0175C2;
      }

      .frame > .member {
        background-color: #EEEEEE;
        border-radius: 0.2em;
        padding: 0em 0.2em;
      }
    </style>
  </head>
  <body>
    ${renderType(error, trace)}
    ${renderMessage(error, trace)}
    <div class="traceback">
      ${renderTitle(error, trace)}
      ${renderFrames(error, trace).join('\n      ')}
    </div>
  </body>
</html>
''';
  }

  String renderType(Object error, Trace trace) {
    var parts = error.toString().split(':');
    var type = parts.length > 1 ? parts[0].trim() : 'Error';
    return '<h1>$type</h1>';
  }

  String renderMessage(Object error, Trace trace) {
    var parts = error.toString().split(':');
    var message = parts.skip(1).join(':').trim();
    return '<h2>$message</h2>';
  }

  String renderTitle(Object error, Trace trace) {
    return '<p class="title">Traceback <span style="color:grey">(most recent call last)</span></p>';
  }

  Iterable<String> renderFrames(Object error, Trace trace) sync* {
    var frames = trace.frames.reversed.toList();
    var frame = frames.removeLast();

    for (var frame in frames) {
      if (frame.isCore) {
        continue;
      }

      yield renderFrame(frame);
    }

    yield renderFrame(frame, true);
  }

  String renderFrame(Frame frame, [bool full = false]) {
    var result = ''
        '<div class="frame"><span class="library">${frame.library}</span>, line '
        '<i>${frame.line}</i> column <i>${frame.column}<i>, in <span class="member">'
        '${htmlEscape.convert(frame.member!)}</span>';

    if (full && frame.uri.scheme == 'file' && frame.line != null) {
      var file = File.fromUri(frame.uri);
      var lines = file.readAsLinesSync();
      var line = frame.line ?? 1;
      result = '$result<br><pre>${renderLine(line, lines[line - 1])}</pre>';
    }

    return '$result</div>';
  }

  String renderLine(int lineNo, String line) {
    return line.trim();
  }
}
