import 'dart:async';
import 'dart:io';

import 'package:astra/core.dart';

Application get application => Example();

class Example extends Application {
  int count = 0;

  @override
  Handler get entryPoint {
    return (Request request) async {
      count += 1;

      return switch (request.url.path) {
        '' => Response.ok('hello world!'),
        'count' => Response.ok('count: $count'),
        'readme' => Response.ok(File('README.md').openRead()),
        'error' => throw Exception('some message'),
        _ => Response.notFound('Request for "${request.url}"'),
      };
    };
  }

  @override
  Future<void> reload() async {
    count = 0;
    // ...
  }

  @override
  Future<void> close() async {
    // ignore: avoid_print
    print('closing ...');
    // ...
  }
}
