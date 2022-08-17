// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  test('forwards the request and response if both handlers are null', () async {
    var middleware = createMiddleware();

    Response handlerWrapper(Request request) {
      return syncHandler(request, headers: {'from': 'innerHandler'});
    }

    var handler = const Pipeline().addMiddleware(middleware).addHandler(handlerWrapper);
    var response = await makeSimpleRequest(handler);
    expect(response.headers['from'], 'innerHandler');
  });

  group('requestHandler', () {
    test('sync null response forwards to inner handler', () async {
      var middleware = createMiddleware(requestHandler: (request) => null);
      var handler = const Pipeline().addMiddleware(middleware).addHandler(syncHandler);
      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], isNull);
    });

    test('async null response forwards to inner handler', () async {
      var middleware = createMiddleware(requestHandler: (request) => Future.value(null));
      var handler = const Pipeline().addMiddleware(middleware).addHandler(syncHandler);
      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], isNull);
    });

    test('sync response is returned', () async {
      var middleware = createMiddleware(requestHandler: (request) => middlewareResponse);
      var handler = const Pipeline().addMiddleware(middleware).addHandler(failHandler);
      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], 'middleware');
    });

    test('async response is returned', () async {
      var middleware = createMiddleware(requestHandler: (request) => Future.value(middlewareResponse));
      var handler = const Pipeline().addMiddleware(middleware).addHandler(failHandler);
      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], 'middleware');
    });

    group('with responseHandler', () {
      test('with sync result, responseHandler is not called', () async {
        var middleware = createMiddleware(
            requestHandler: (request) => middlewareResponse,
            responseHandler: (response) => fail('should not be called'));
        var handler = const Pipeline().addMiddleware(middleware).addHandler(syncHandler);
        var response = await makeSimpleRequest(handler);
        expect(response.headers['from'], 'middleware');
      });

      test('with async result, responseHandler is not called', () async {
        var middleware = createMiddleware(
            requestHandler: (request) => Future.value(middlewareResponse),
            responseHandler: (response) => fail('should not be called'));
        var handler = const Pipeline().addMiddleware(middleware).addHandler(syncHandler);
        var response = await makeSimpleRequest(handler);
        expect(response.headers['from'], 'middleware');
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


      var handler = const Pipeline().addMiddleware(middleware).addHandler((request) {
        return syncHandler(request, headers: {'from': 'handler'});
      });

      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], 'middleware');
    });

    test('innerHandler async response is seen, async value continues', () async {
      var handler = const Pipeline().addMiddleware(createMiddleware(responseHandler: (response) {
        expect(response.headers['from'], 'handler');
        return Future.value(middlewareResponse);
      })).addHandler((request) {
        return Future(() => syncHandler(request, headers: {'from': 'handler'}));
      });

      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], 'middleware');
    });
  });

  group('error handling', () {
    test('sync error thrown by requestHandler bubbles down', () {
      var handler = const Pipeline()
          .addMiddleware(createMiddleware(requestHandler: (request) => throw 'middleware error'))
          .addHandler(failHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('async error thrown by requestHandler bubbles down', () {
      var handler = const Pipeline()
          .addMiddleware(createMiddleware(requestHandler: (request) => Future.error('middleware error')))
          .addHandler(failHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('throw from responseHandler does not hit error handler', () {
      var middleware = createMiddleware(
          responseHandler: (response) {
            throw 'middleware error';
          },
          errorHandler: (e, s) => fail('should never get here'));

      var handler = const Pipeline().addMiddleware(middleware).addHandler(syncHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('requestHandler throw does not hit errorHandlers', () {
      var middleware = createMiddleware(
          requestHandler: (request) {
            throw 'middleware error';
          },
          errorHandler: (e, s) => fail('should never get here'));

      var handler = const Pipeline().addMiddleware(middleware).addHandler(syncHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('inner handler throws, is caught by errorHandler with response', () async {
      var middleware = createMiddleware(errorHandler: (error, stack) {
        expect(error, 'bad handler');
        return middlewareResponse;
      });

      var handler = const Pipeline().addMiddleware(middleware).addHandler((request) {
        throw 'bad handler';
      });

      var response = await makeSimpleRequest(handler);
      expect(response.headers['from'], 'middleware');
    });

    test('inner handler throws, is caught by errorHandler and rethrown', () {
      var middleware = createMiddleware(errorHandler: (Object error, stack) {
        expect(error, 'bad handler');
        throw error;
      });

      var handler = const Pipeline().addMiddleware(middleware).addHandler((request) {
        throw 'bad handler';
      });

      expect(makeSimpleRequest(handler), throwsA('bad handler'));
    });

    test(
        'error thrown by inner handler without a middleware errorHandler is '
        'rethrown', () {
      var middleware = createMiddleware();

      var handler = const Pipeline().addMiddleware(middleware).addHandler((request) {
        throw 'bad handler';
      });

      expect(makeSimpleRequest(handler), throwsA('bad handler'));
    });

    test("doesn't handle HijackException", () {
      var middleware = createMiddleware(errorHandler: (error, stack) {
        fail("error handler shouldn't be called");
      });

      var handler = const Pipeline().addMiddleware(middleware).addHandler((request) => throw const HijackException());

      expect(makeSimpleRequest(handler), throwsHijackException);
    });
  });
}

Response failHandler(Request request) => fail('should never get here');

final Response middlewareResponse = Response.ok('middleware content', headers: {'from': 'middleware'});
