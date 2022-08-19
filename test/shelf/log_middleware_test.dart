// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:astra/core.dart';
import 'package:astra/middlewares.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  late bool gotLog;

  setUp(() {
    gotLog = false;
  });

  void logger(String msg, bool isError) {
    expect(gotLog, isFalse);
    gotLog = true;
    expect(isError, isFalse);
    expect(msg, contains('GET'));
    expect(msg, contains('[200]'));
  }

  test('logs a request with a synchronous response', () async {
    var handler = logRequests(logger: logger).handle(syncHandler);
    await makeSimpleRequest(handler);
    expect(gotLog, isTrue);
  });

  test('logs a request with an asynchronous response', () async {
    var handler = logRequests(logger: logger).handle(asyncHandler);
    await makeSimpleRequest(handler);
    expect(gotLog, isTrue);
  });

  test('logs a request with an asynchronous error response', () {
    void logger(String message, bool isError) {
      expect(gotLog, isFalse);
      gotLog = true;
      expect(isError, isTrue);
      expect(message, contains('\tGET\t/'));
      expect(message, contains('testing logging throw'));
    }

    Response throwingHandler(Request request) {
      throw 'testing logging throw';
    }

    var handler = logRequests(logger: logger).handle(throwingHandler);
    expect(makeSimpleRequest(handler), throwsA('testing logging throw'));
  });

  test("doesn't log a HijackException", () {
    Response throwingHandler(request) {
      throw const HijackException();
    }

    var handler = logRequests(logger: logger).handle(throwingHandler);

    void onComplete() {
      expect(gotLog, isFalse);
    }

    expect(makeSimpleRequest(handler).whenComplete(onComplete), throwsHijackException);
  });
}
