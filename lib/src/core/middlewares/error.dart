import 'dart:async' show FutureOr;
import 'dart:convert' show ascii;
import 'dart:io' show File;

import 'package:stack_trace/stack_trace.dart' show Frame, Trace;

import '../http.dart';
import '../request.dart';
import '../response.dart';
import '../type.dart';

class ServerErrorMiddleware implements ApplicationController {
  ServerErrorMiddleware(this.application, {this.debug = false, this.handler});

  final Application application;

  final bool debug;

  final ExceptionHandler? handler;

  @override
  FutureOr<void> call(Map<String, Object?> scope, Receive receive, Start start, Respond respond) {
    if (scope['type'] != 'http') {
      return application(scope, receive, start, respond);
    }

    var responseStarted = false;

    void starter(int status, List<Header> headers) {
      responseStarted = true;
      start(status, headers);
    }

    return Future<void>.sync(() => application(scope, receive, starter, respond)).catchError((Object error, StackTrace stackTrace) {
      if (responseStarted) {
        throw error;
      }

      final request = Request(scope);

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

          return HTMLResponse(html, status: 500).call(scope, start, respond);
        }

        final trace = Trace.format(stackTrace);
        return TextResponse('$error\n\n$trace', status: 500).call(scope, start, respond);
      }

      if (handler == null) {
        return TextResponse('Internal Server Error', status: 500).call(scope, start, respond);
      }

      return Future<Response>.sync(() => handler!(request, error, stackTrace)).then<void>((response) => response(scope, start, respond));
    });
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
    '<h1>Astra Debugger</h1>'
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
      ..write(scheme == 'package' ? frame.library.replaceFirst('package:', '') : frame.library)
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
      String code;

      if (frame.column != null) {
        code = lines[frame.line! - 1].substring(frame.column! - 1).trimRight();
      } else {
        code = lines[frame.line! - 1].trim();
      }

      buffer..write('<br><pre>')..write(code)..write('</pre>');
    }

    buffer.write('</div>');
  }

  return buffer.toString();
}
