// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:test/test.dart';

import 'test_util.dart';

final Response middlewareResponse = Response.ok('middleware content', headers: <String, String>{'from': 'middleware'});

Response failHandler(Request request) {
  fail('should never get here');
}

void main() {
  test('forwards the request and response if both handlers are null', () async {
    Response handler(Request request) {
      return syncHandler(request, headers: <String, String>{'from': 'innerHandler'});
    }

    var response = await makeSimpleRequest(createMiddleware().handle(handler));
    expect(response.headers['from'], equals('innerHandler'));
  });

  group('requestHandler', () {
    test('sync null response forwards to inner handler', () async {
      Response? requestHandler(request) {
        return null;
      }

      var middleware = createMiddleware(requestHandler: requestHandler);
      var response = await makeSimpleRequest(middleware.handle(syncHandler));
      expect(response.headers['from'], isNull);
    });

    test('async null response forwards to inner handler', () async {
      Future<Response?> requestHandler(Request request) {
        return Future<Response?>.value(null);
      }

      var middleware = createMiddleware(requestHandler: requestHandler);
      var response = await makeSimpleRequest(middleware.handle(syncHandler));
      expect(response.headers['from'], isNull);
    });

    test('sync response is returned', () async {
      Response requestHandler(Request request) {
        return middlewareResponse;
      }

      var middleware = createMiddleware(requestHandler: requestHandler);
      var response = await makeSimpleRequest(middleware.handle(failHandler));
      expect(response.headers['from'], equals('middleware'));
    });

    test('async response is returned', () async {
      Future<Response> requestHandler(Request request) {
        return Future<Response>.value(middlewareResponse);
      }

      var middleware = createMiddleware(requestHandler: requestHandler);
      var response = await makeSimpleRequest(middleware.handle(failHandler));
      expect(response.headers['from'], equals('middleware'));
    });

    group('with responseHandler', () {
      test('with sync result, responseHandler is not called', () async {
        Response requestHandler(Request request) {
          return middlewareResponse;
        }

        Response responseHandler(Response response) {
          fail('should not be called');
        }

        var middleware = createMiddleware(requestHandler: requestHandler, responseHandler: responseHandler);
        var response = await makeSimpleRequest(middleware.handle(syncHandler));
        expect(response.headers['from'], equals('middleware'));
      });

      test('with async result, responseHandler is not called', () async {
        Future<Response> requestHandler(Request request) {
          return Future<Response>.value(middlewareResponse);
        }

        Response responseHandler(Response response) {
          fail('should not be called');
        }

        var middleware = createMiddleware(requestHandler: requestHandler, responseHandler: responseHandler);
        var response = await makeSimpleRequest(middleware.handle(syncHandler));
        expect(response.headers['from'], equals('middleware'));
      });
    });
  });

  group('responseHandler', () {
    test('innerHandler sync response is seen, replaced value continues', () async {
      Response responseHandler(Response response) {
        expect(response.headers['from'], 'handler');
        return middlewareResponse;
      }

      var middleware = createMiddleware(responseHandler: responseHandler);

      Response handler(Request request) {
        return syncHandler(request, headers: <String, String>{'from': 'handler'});
      }

      var response = await makeSimpleRequest(middleware.handle(handler));
      expect(response.headers['from'], equals('middleware'));
    });

    test('innerHandler async response is seen, async value continues', () async {
      Future<Response> responseHandler(Response response) {
        expect(response.headers['from'], 'handler');
        return Future<Response>.value(middlewareResponse);
      }

      var middleware = createMiddleware(responseHandler: responseHandler);

      Future<Response> handler(Request request) {
        return Future(() => syncHandler(request, headers: <String, String>{'from': 'handler'}));
      }

      var response = await makeSimpleRequest(middleware.handle(handler));
      expect(response.headers['from'], equals('middleware'));
    });
  });

  group('error handling', () {
    test('sync error thrown by requestHandler bubbles down', () {
      Response requestHandler(Request request) {
        throw 'middleware error';
      }

      var middleware = createMiddleware(requestHandler: requestHandler);
      expect(makeSimpleRequest(middleware.handle(failHandler)), throwsA('middleware error'));
    });

    test('async error thrown by requestHandler bubbles down', () {
      Future<Response> requestHandler(Request request) {
        return Future<Response>.error('middleware error');
      }

      var middleware = createMiddleware(requestHandler: requestHandler);
      expect(makeSimpleRequest(middleware.handle(failHandler)), throwsA('middleware error'));
    });

    test('throw from responseHandler does not hit error handler', () {
      Future<Response> responseHandler(Response response) {
        throw 'middleware error';
      }

      Response errorHandler(Object error, StackTrace stack) {
        fail('should never get here');
      }

      var middleware = createMiddleware(responseHandler: responseHandler, errorHandler: errorHandler);
      expect(makeSimpleRequest(middleware.handle(syncHandler)), throwsA('middleware error'));
    });

    test('requestHandler throw does not hit errorHandlers', () {
      Response requestHandler(Request request) {
        throw 'middleware error';
      }

      Response errorHandler(Object error, StackTrace stack) {
        fail('should never get here');
      }

      var middleware = createMiddleware(requestHandler: requestHandler, errorHandler: errorHandler);
      expect(makeSimpleRequest(middleware.handle(syncHandler)), throwsA('middleware error'));
    });

    test('inner handler throws, is caught by errorHandler with response', () async {
      Response errorHandler(Object error, StackTrace stack) {
        expect(error, 'bad handler');
        return middlewareResponse;
      }

      var middleware = createMiddleware(errorHandler: errorHandler);

      Response handler(Request request) {
        throw 'bad handler';
      }

      var response = await makeSimpleRequest(middleware.handle(handler));
      expect(response.headers['from'], equals('middleware'));
    });

    test('inner handler throws, is caught by errorHandler and rethrown', () {
      Response errorHandler(Object error, StackTrace stack) {
        expect(error, 'bad handler');
        throw error;
      }

      var middleware = createMiddleware(errorHandler: errorHandler);

      Response handler(Request request) {
        throw 'bad handler';
      }

      expect(makeSimpleRequest(middleware.handle(handler)), throwsA('bad handler'));
    });

    test('error thrown by inner handler without a middleware errorHandler is rethrown', () {
      var middleware = createMiddleware();

      Response handler(Request request) {
        throw 'bad handler';
      }

      expect(makeSimpleRequest(middleware.handle(handler)), throwsA('bad handler'));
    });

    test('doesn\'t handle HijackException', () {
      Response errorHandler(Object error, StackTrace stack) {
        fail('error handler shouldn\'t be called');
      }

      var middleware = createMiddleware(errorHandler: errorHandler);

      Response handler(Request request) {
        throw const HijackException();
      }

      expect(makeSimpleRequest(middleware.handle(handler)), throwsHijackException);
    });
  });
}
