import 'dart:io' show File, HttpStatus;

import 'package:stack_trace/stack_trace.dart' show Trace;

import 'http.dart';
import 'request.dart';
import 'response.dart';
import 'types.dart';

Application error(Application application,
    {bool debug = false, ExceptionHandler? handler}) {
  return (Request request) async {
    var start = request.start;
    var responseStarted = false;

    request.start = (int status, {List<Header>? headers, bool buffer = true}) {
      responseStarted = true;
      start(status, headers: headers, buffer: buffer);
    };

    try {
      await application(request);
    } catch (error, stackTrace) {
      if (responseStarted) {
        rethrow;
      }

      if (debug) {
        var accept = request.headers.get('accept');
        if (accept != null && accept.contains('text/html')) {
          var html = template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
            switch (match[1]) {
              case 'type':
                return error.toString();
              case 'error':
                return error.toString();
              case 'trace':
                return renderFrames(Trace.from(stackTrace));
              default:
                return '';
            }
          });

          var response = TextResponse.html(html, status: 500);
          return response(request);
        }

        var trace = Trace.format(stackTrace);
        var response = TextResponse('$error\n\n$trace',
            status: HttpStatus.internalServerError);
        return response(request);
      }

      if (handler == null) {
        var response = TextResponse('Internal Server Error',
            status: HttpStatus.internalServerError);
        return response(request);
      }

      var response = await handler(request, error, stackTrace);
      return response(request);
    }
  };
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

String renderFrames(Trace trace) {
  var buffer = StringBuffer();

  for (var frame in trace.frames) {
    if (frame.isCore) {
      continue;
    }

    var scheme = frame.uri.scheme;
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

    buffer
      ..write(member)
      ..write('</span>');

    if (scheme == 'file' && frame.line != null) {
      var lines = File.fromUri(frame.uri).readAsLinesSync();
      var line = lines[frame.line! - 1];
      var leftTrimmed = line.trimLeft();
      var column = (frame.column ?? 0) - line.length + leftTrimmed.length - 1;
      var code = leftTrimmed.trimRight();

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

  return '$buffer';
}
