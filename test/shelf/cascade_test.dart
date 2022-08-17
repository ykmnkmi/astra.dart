// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:astra/core.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  group('a cascade with several handlers', () {
    late Handler handler;

    setUp(() {
      handler = Cascade().add((request) {
        if (request.headers['one'] == 'false') {
          return Response.notFound('handler 1');
        } else {
          return Response.ok('handler 1');
        }
      }).add((request) {
        if (request.headers['two'] == 'false') {
          return Response.notFound('handler 2');
        } else {
          return Response.ok('handler 2');
        }
      }).add((request) {
        if (request.headers['three'] == 'false') {
          return Response.notFound('handler 3');
        } else {
          return Response.ok('handler 3');
        }
      }).handler;
    });

    test('the first response should be returned if it matches', () async {
      var response = await makeSimpleRequest(handler);
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 1')));
    });

    test(
        'the second response should be returned if it matches and the first '
        "doesn't", () async {
      var headers = {'one': 'false'};
      var response = await handler(Request('GET', localhostUri, headers: headers));
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 2')));
    });

    test('the third response should be returned if it matches and the first two don\'t', () async {
      var headers = {'one': 'false', 'two': 'false'};
      var response = await handler(Request('GET', localhostUri, headers: headers));
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 3')));
    });

    test('the third response should be returned if no response matches', () async {
      var headers = {'one': 'false', 'two': 'false', 'three': 'false'};
      var response = await handler(Request('GET', localhostUri, headers: headers));
      expect(response.statusCode, equals(404));
      expect(response.readAsString(), completion(equals('handler 3')));
    });
  });

  test('a 404 response triggers a cascade by default', () async {
    var handler = Cascade() //
        .add((request) => Response.notFound('handler 1'))
        .add((request) => Response.ok('handler 2'))
        .handler;

    var response = await makeSimpleRequest(handler);
    expect(response.statusCode, equals(200));
    expect(response.readAsString(), completion(equals('handler 2')));
  });

  test('a 405 response triggers a cascade by default', () async {
    var handler = Cascade().add((request) => Response(405)).add((request) => Response.ok('handler 2')).handler;
    var response = await makeSimpleRequest(handler);
    expect(response.statusCode, equals(200));
    expect(response.readAsString(), completion(equals('handler 2')));
  });

  test('[statusCodes] controls which statuses cause cascading', () async {
    var handler = Cascade(statusCodes: [302, 403])
        .add((request) => Response.found('/'))
        .add((request) => Response.forbidden('handler 2'))
        .add((request) => Response.notFound('handler 3'))
        .add((request) => Response.ok('handler 4'))
        .handler;

    var response = await makeSimpleRequest(handler);
    expect(response.statusCode, equals(404));
    expect(response.readAsString(), completion(equals('handler 3')));
  });

  test('[shouldCascade] controls which responses cause cascading', () async {
    var handler = Cascade(shouldCascade: (response) => response.statusCode % 2 == 1)
        .add((request) => Response.movedPermanently('/'))
        .add((request) => Response.forbidden('handler 2'))
        .add((request) => Response.notFound('handler 3'))
        .add((request) => Response.ok('handler 4'))
        .handler;

    var response = await makeSimpleRequest(handler);
    expect(response.statusCode, equals(404));
    expect(response.readAsString(), completion(equals('handler 3')));
  });

  group('errors', () {
    test('getting the handler for an empty cascade fails', () {
      expect(() => Cascade().handler, throwsStateError);
    });

    test('passing [statusCodes] and [shouldCascade] at the same time fails', () {
      expect(() => Cascade(statusCodes: [404, 405], shouldCascade: (_) => false), throwsArgumentError);
    });
  });
}
