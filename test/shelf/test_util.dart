// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:astra/core.dart';
import 'package:test/test.dart';

// "hello,"
const List<int> helloBytes = <int>[104, 101, 108, 108, 111, 44];

// " world"
const List<int> worldBytes = <int>[32, 119, 111, 114, 108, 100];

final Matcher throwsHijackException = throwsA(isA<HijackException>());

/// A simple, synchronous handler for [Request].
///
/// By default, replies with a status code 200, empty headers, and
/// `Hello from ${request.url.path}`.
Response syncHandler(Request request, {int? statusCode, Map<String, String>? headers}) {
  return Response(statusCode ?? 200, headers: headers, body: 'Hello from ${request.requestedUri.path}');
}

/// Calls [syncHandler] and wraps the response in a [Future].
Future<Response> asyncHandler(Request request) {
  return Future<Response>(() => syncHandler(request));
}

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeSimpleRequest(Handler handler) => Future.sync(() => handler(request));

final Request request = Request('GET', localhostUri);

final Uri localhostUri = Uri.parse('http://localhost/');
