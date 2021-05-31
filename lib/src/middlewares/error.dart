import 'dart:async' show FutureOr;
import 'dart:io' show File;

import 'package:astra/astra.dart';
import 'package:stack_trace/stack_trace.dart' show Frame, Trace;

class ServerErrorMiddleware {
  ServerErrorMiddleware(
    this.application, {
    this.debug = false,
    this.handler,
  });

  final Application application;

  final bool debug;

  final ExceptionHandler? handler;

  Future<void> call(Request request, Start start, Respond respond) {
    var responseStarted = false;

    void starter(int status, [List<Header> headers = const <Header>[]]) {
      responseStarted = true;
      start(status, headers);
    }

    FutureOr<void> run() {
      return application(request, starter, respond);
    }

    FutureOr<void> catchError(Object error, StackTrace stackTrace) {
      if (responseStarted) {
        throw error;
      }

      if (debug) {
        final accept = request.headers.get('accept');

        if (accept != null && accept.contains('text/html')) {
          final html = template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
            switch (match[1]) {
              case 'type':
                return error.toString();
              case 'error':
                return error.toString();
              case 'trace':
                final trace = Trace.from(stackTrace);
                return renderFrames(trace.frames);
              default:
                return '';
            }
          });

          return HTMLResponse(html, status: 500)(request, start, respond);
        }

        final trace = Trace.format(stackTrace);
        final response = TextResponse('$error\n\n$trace', status: 500);
        return response(request, start, respond);
      }

      if (handler == null) {
        final response = TextResponse('Internal Server Error', status: 500);
        return response(request, start, respond);
      }

      FutureOr<Response> handle() {
        return handler!(request, error, stackTrace);
      }

      FutureOr<void> send(Response response) {
        return response(request, start, respond);
      }

      return Future<Response>.sync(handle).then<void>(send);
    }

    return Future<void>.sync(run).catchError(catchError);
  }
}

const String style =
    'body{font-family:"JetBrains Mono","Cascadia Mono","Fira Mono","Ubuntu Mono","DejaVu Sans Mono",Menlo,Consolas,"Liberation Mono",Monaco,"Lucida Console",monospace}'
    'pre{background-color: #eeeeee;border:1px solid lightgrey;margin:0.5em 0em 0em;padding:0.25em 0.5em}'
    '.traceback{border:1px solid lightgrey;overflow:hidden}'
    '.traceback>.title{background-color:#eeeeee;border-bottom:1px solid lightgrey;font-size:1.25em;margin:0em;padding:0.5em}'
    '.frame{padding:0.25em 0.5em}'
    '.frame>.library{color:#0175C2}'
    '.frame>.member{background-color:#eeeeee;border-radius:0.2em;padding:0em 0.2em}';

const String template = '<html>'
    '<head>'
    '<title>Astra Debugger</title>'
    '<style>$style</style>'
    '</head>'
    '<body>'
    '<h1>Astra: debugger</h1>'
    '<h2>{error}</h2>'
    '<div class="traceback">'
    '<p class="title">Traceback <span style="color:grey">(most recent call first)</span></p>'
    '{trace}'
    '</div>'
    '</body>'
    '</html>';

String renderFrames(List<Frame> frames) {
  final buffer = StringBuffer();

  for (final frame in frames) {
    if (frame.isCore) {
      continue;
    }

    final scheme = frame.uri.scheme;
    buffer
      ..write('<div class="frame">')
      ..write(scheme == 'file' ? 'File' : 'Package')
      ..write('&nbsp;<span class="library">')
      ..write(scheme == 'package'
          ? frame.library.replaceFirst('package:', '')
          : frame.library)
      ..write('</span>, line&nbsp;<i>')
      ..write(frame.line)
      ..write('</i>,&nbsp;column&nbsp;<i>')
      ..write(frame.column)
      ..write('</i>, in&nbsp;<span class="member">');

    var member = frame.member;

    if (member != null && member.contains('<fn>')) {
      member = member.replaceAll('<fn>', 'closure');
    }

    buffer..write(member)..write('</span>');

    if (scheme == 'file' && frame.line != null) {
      final lines = File.fromUri(frame.uri).readAsLinesSync();
      final line = lines[frame.line! - 1];
      final leftTrimmed = line.trimLeft();
      final column = (frame.column ?? 0) - line.length + leftTrimmed.length - 1;
      final code = leftTrimmed.trimRight();

      buffer.write('<br><pre style="">');

      if (column != 0) {
        buffer
          ..write(code.substring(0, column))
          ..write('<u>')
          ..write(code.substring(column, column + 1))
          ..write('</u>')
          ..write(code.substring(column + 1));
      } else {
        buffer.write(code);
      }

      buffer.write('</pre>');
    }

    buffer.write('</div>');
  }

  return buffer.toString();
}
