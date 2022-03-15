import 'dart:convert';
import 'dart:io';

import 'package:astra/src/core/exception.dart';
import 'package:shelf/shelf.dart';
import 'package:stack_trace/stack_trace.dart';

Middleware error({bool debug = false, ErrorHandler? errorHandler, Map<String, Object>? headers}) {
  var htmlHeaders = <String, Object>{
    ...?headers,
    'content-type': 'text/html; charset=utf-8',
  };

  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } catch (error, stackTrace) {
        if (debug) {
          var accept = request.headers['accept'];

          if (accept != null && accept.contains('text/html')) {
            var body = template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
              var parts = error.toString().split(':');
              var type = parts.length > 1 ? parts.removeAt(0).trim() : 'Error';
              var message = parts.join(':').trim();

              switch (match[1]) {
                case 'type':
                  return type;
                case 'message':
                  return message;
                case 'trace':
                  return renderFrames(Trace.from(stackTrace));
                default:
                  return '';
              }
            });

            return Response.internalServerError(body: body, headers: htmlHeaders);
          }

          return Response.internalServerError(
              body: '$error\n${Trace.format(stackTrace)}', headers: headers);
        }

        if (errorHandler == null) {
          return Response.internalServerError(body: 'Internal Server Error', headers: headers);
        }

        return errorHandler(request, error, stackTrace);
      }
    };
  };
}

const String template = '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>{type}: {message}</title>
    <style>
      body {
        font-family: "JetBrains Mono", "Cascadia Mono", "Fira Mono", "Ubuntu Mono", "DejaVu Sans Mono", Menlo, Consolas, "Liberation Mono", Monaco, "Lucida Console", monospace;
      }

      pre {
        background-color: #EEEEEE;
        border: 1px solid lightgrey;
        margin: 0.5em 0em 0em;
        padding: 0.25em 0.5em;
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
    <h1>{type}</h1>
    <h2>{message}</h2>
    <div class="traceback">
      <p class="title">Traceback <span style="color:grey">(most recent call last)</span></p>
{trace}
    </div>
  </body>
</html>
''';

String renderFrames(Trace trace) {
  var buffer = StringBuffer();
  var frames = trace.frames.reversed.toList();
  var frame = frames.removeLast();

  for (var frame in frames) {
    if (frame.isCore) {
      continue;
    }

    writeFrame(buffer, frame);
  }

  writeFrame(buffer, frame, true);
  return buffer.toString().trimRight();
}

void writeFrame(StringBuffer buffer, Frame frame, [bool full = false]) {
  buffer
    ..write('      <div class="frame">\n        ')
    ..write('&nbsp;<span class="library">')
    ..write(frame.library)
    ..write('</span>, line&nbsp;<i>')
    ..write(frame.line)
    ..write('</i>,&nbsp;column&nbsp;<i>')
    ..write(frame.column)
    ..write('</i>, in&nbsp;<span class="member">');

  var member = frame.member;

  buffer
    ..write(htmlEscape.convert(member!))
    ..write('</span>');

  if (full && frame.uri.scheme == 'file' && frame.line != null) {
    var file = File.fromUri(frame.uri);
    var lines = file.readAsLinesSync();
    var line = frame.line! - 4;
    var column = frame.column! - 1;
    buffer.write('\n        <br>\n        <pre>');

    if (line++ > 0) {
      writeLine(buffer, line, lines);
    }

    if (line++ > 0) {
      writeLine(buffer, line, lines);
    }

    writeLine(buffer, ++line, lines);

    buffer
      ..write('\n    \t')
      ..write(' ' * column)
      ..write('^');

    if (line++ < lines.length) {
      writeLine(buffer, line, lines);
    }

    if (line++ < lines.length) {
      writeLine(buffer, line, lines);
    }

    buffer.write('</pre>');
  }

  buffer.write('\n      </div>\n');
}

void writeLine(StringBuffer buffer, int lineNo, List<String> lines) {
  buffer
    ..writeln()
    ..write((lineNo + 1).toString().padLeft(4))
    ..write('\t')
    ..write(lines[lineNo]);
}
