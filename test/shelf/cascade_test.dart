// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:astra/core.dart';
import 'package:test/test.dart';

import 'test_util.dart';

Response handler1(Request request) {
  if (request.headers['one'] == 'false') {
    return Response.notFound('handler 1');
  }

  return Response.ok('handler 1');
}

Response handler2(Request request) {
  if (request.headers['two'] == 'false') {
    return Response.notFound('handler 2');
  }

  return Response.ok('handler 2');
}

Response handler3(Request request) {
  if (request.headers['three'] == 'false') {
    return Response.notFound('handler 3');
  }

  return Response.ok('handler 3');
}

void main() {
  group('a cascade with several handlers', () {
    var cascade = Cascade().add(handler1).add(handler2).add(handler3);
    var handler = cascade.handler;

    test('the first response should be returned if it matches', () async {
      var response = await makeSimpleRequest(handler);
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 1')));
    });

    test('the second response should be returned if it matches and the first doesn\'t', () async {
      var headers = <String, String>{'one': 'false'};
      var response = await handler(Request('GET', localhostUri, headers: headers));
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 2')));
    });

    test('the third response should be returned if it matches and the first two don\'t', () async {
      var headers = <String, String>{'one': 'false', 'two': 'false'};
      var response = await handler(Request('GET', localhostUri, headers: headers));
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 3')));
    });

    test('the third response should be returned if no response matches', () async {
      var headers = <String, String>{'one': 'false', 'two': 'false', 'three': 'false'};
      var response = await handler(Request('GET', localhostUri, headers: headers));
      expect(response.statusCode, equals(404));
      expect(response.readAsString(), completion(equals('handler 3')));
    });
  });

  test('a 404 response triggers a cascade by default', () async {
    Response handler1(Request request) {
      return Response.notFound('handler 1');
    }

    Response handler2(Request request) {
      return Response.ok('handler 2');
    }

    var cascade = Cascade().add(handler1).add(handler2);
    var response = await makeSimpleRequest(cascade.handler);
    expect(response.statusCode, equals(200));
    expect(response.readAsString(), completion(equals('handler 2')));
  });

  test('a 405 response triggers a cascade by default', () async {
    Response handler1(Request request) {
      return Response(405);
    }

    Response handler2(Request request) {
      return Response.ok('handler 2');
    }

    var cascade = Cascade().add(handler1).add(handler2);
    var response = await makeSimpleRequest(cascade.handler);
    expect(response.statusCode, equals(200));
    expect(response.readAsString(), completion(equals('handler 2')));
  });

  test('[statusCodes] controls which statuses cause cascading', () async {
    Response handler1(Request request) {
      return Response.found('/');
    }

    Response handler2(Request request) {
      return Response.forbidden('handler 2');
    }

    Response handler3(Request request) {
      return Response.notFound('handler 3');
    }

    Response handler4(Request request) {
      return Response.ok('handler 4');
    }

    var cascade = Cascade(statusCodes: <int>[302, 403]).add(handler1).add(handler2).add(handler3).add(handler4);
    var response = await makeSimpleRequest(cascade.handler);
    expect(response.statusCode, equals(404));
    expect(response.readAsString(), completion(equals('handler 3')));
  });

  test('[shouldCascade] controls which responses cause cascading', () async {
    bool shouldCascade(Response response) {
      return response.statusCode % 2 == 1;
    }

    Response handler1(Request request) {
      return Response.movedPermanently('/');
    }

    Response handler2(Request request) {
      return Response.forbidden('handler 2');
    }

    Response handler3(Request request) {
      return Response.notFound('handler 3');
    }

    Response handler4(Request request) {
      return Response.ok('handler 4');
    }

    var cascade = Cascade(shouldCascade: shouldCascade).add(handler1).add(handler2).add(handler3).add(handler4);
    var response = await makeSimpleRequest(cascade.handler);
    expect(response.statusCode, equals(404));
    expect(response.readAsString(), completion(equals('handler 3')));
  });

  group('errors', () {
    test('getting the handler for an empty cascade fails', () {
      expect(() => Cascade().handler, throwsStateError);
    });

    test('passing [statusCodes] and [shouldCascade] at the same time fails', () {
      bool shouldCascade(Response response) {
        return false;
      }

      expect(() => Cascade(statusCodes: <int>[404, 405], shouldCascade: shouldCascade), throwsArgumentError);
    });
  });
}
