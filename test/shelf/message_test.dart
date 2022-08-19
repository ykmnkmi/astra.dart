// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:shelf/src/message.dart';
import 'package:test/test.dart';

import 'test_util.dart';

class TestMessage extends Message {
  TestMessage({Object? body, Map<String, Object>? headers, Map<String, Object>? context, Encoding? encoding})
      : super(body, headers: headers, context: context, encoding: encoding);

  @override
  Message change({Object? body, Map<String, String>? headers, Map<String, Object>? context}) {
    throw UnimplementedError();
  }
}

void main() {
  group('headers', () {
    test('message headers are case insensitive', () {
      var message = TestMessage(headers: <String, Object>{'foo': 'bar'});
      expect(message.headers, containsPair('foo', 'bar'));
      expect(message.headers, containsPair('Foo', 'bar'));
      expect(message.headers, containsPair('FOO', 'bar'));
      expect(message.headersAll, containsPair('foo', <String>['bar']));
      expect(message.headersAll, containsPair('Foo', <String>['bar']));
      expect(message.headersAll, containsPair('FOO', <String>['bar']));
    });

    test('null header value becomes default', () {
      var message = TestMessage();
      expect(message.headers, equals(<String, Object>{'content-length': '0'}));
      expect(message.headers, containsPair('CoNtEnT-lEnGtH', '0'));
      expect(message.headers, same(TestMessage().headers));
      expect(() => message.headers['h1'] = 'value1', throwsUnsupportedError);
      expect(() => message.headersAll['h1'] = <String>['value1'], throwsUnsupportedError);
    });

    test('headers are immutable', () {
      var message = TestMessage(headers: <String, Object>{'h1': 'value1'});
      expect(() => message.headers['h1'] = 'value1', throwsUnsupportedError);
      expect(() => message.headers['h1'] = 'value2', throwsUnsupportedError);
      expect(() => message.headers['h2'] = 'value2', throwsUnsupportedError);
      expect(() => message.headersAll['h1'] = <String>['value1'], throwsUnsupportedError);
      expect(() => message.headersAll['h1'] = <String>['value2'], throwsUnsupportedError);
      expect(() => message.headersAll['h2'] = <String>['value2'], throwsUnsupportedError);
    });

    test('headers with multiple values', () {
      var headers = <String, Object>{
        'a': 'A',
        'b': <String>['B1', 'B2']
      };

      var message = TestMessage(headers: headers);
      expect(message.headers, containsPair('a', 'A'));
      expect(message.headers, containsPair('b', 'B1,B2'));
      expect(message.headers, containsPair('content-length', '0'));
      expect(message.headersAll, containsPair('a', <String>['A']));
      expect(message.headersAll, containsPair('b', <String>['B1', 'B2']));
      expect(message.headersAll, containsPair('content-length', <String>['0']));
    });
  });

  group('context', () {
    test('is accessible', () {
      var message = TestMessage(context: <String, Object>{'foo': 'bar'});
      expect(message.context, containsPair('foo', 'bar'));
    });

    test('null context value becomes empty and immutable', () {
      var message = TestMessage();
      expect(message.context, isEmpty);
      expect(() => message.context['key'] = 'value', throwsUnsupportedError);
    });

    test('is immutable', () {
      var message = TestMessage(context: <String, Object>{'key': 'value'});
      expect(() => message.context['key'] = 'value', throwsUnsupportedError);
      expect(() => message.context['key2'] = 'value', throwsUnsupportedError);
    });
  });

  group('readAsString', () {
    test('supports a null body', () {
      var request = TestMessage();
      expect(request.readAsString(), completion(equals('')));
    });

    test('supports a Stream<List<int>> body', () {
      var controller = StreamController<Object>();
      var request = TestMessage(body: controller.stream);
      expect(request.readAsString(), completion(equals('hello, world')));

      controller.add(helloBytes);

      void callback() {
        controller
          ..add(worldBytes)
          ..close();
      }

      return Future<void>(callback);
    });

    test('defaults to UTF-8', () {
      var request = TestMessage(body: Stream.value(<int>[195, 168]));
      expect(request.readAsString(), completion(equals('è')));
    });

    test('the content-type header overrides the default', () {
      var body = Stream<List<int>>.value(<int>[195, 168]);
      var headers = <String, Object>{'content-type': 'text/plain; charset=iso-8859-1'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.readAsString(), completion(equals('Ã¨')));
    });

    test('an explicit encoding overrides the content-type header', () {
      var body = Stream<List<int>>.value(<int>[195, 168]);
      var headers = <String, Object>{'content-type': 'text/plain; charset=iso-8859-1'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.readAsString(latin1), completion(equals('Ã¨')));
    });
  });

  group('read', () {
    test('supports a null body', () {
      var request = TestMessage();
      expect(request.read().toList(), completion(isEmpty));
    });

    test('supports a Stream<List<int>> body', () {
      var controller = StreamController<Object>();
      var request = TestMessage(body: controller.stream);
      expect(request.read().toList(), completion(equals(<List<int>>[helloBytes, worldBytes])));

      controller.add(helloBytes);

      void callback() {
        controller
          ..add(worldBytes)
          ..close();
      }

      return Future<void>(callback);
    });

    test('supports a List<int> body', () {
      var request = TestMessage(body: helloBytes);
      expect(request.read().toList(), completion(equals(<List<int>>[helloBytes])));
    });

    test('throws when calling read()/readAsString() multiple times', () {
      Message request;

      request = TestMessage();
      expect(request.read().toList(), completion(isEmpty));
      expect(() => request.read(), throwsStateError);

      request = TestMessage();
      expect(request.readAsString(), completion(isEmpty));
      expect(() => request.readAsString(), throwsStateError);

      request = TestMessage();
      expect(request.readAsString(), completion(isEmpty));
      expect(() => request.read(), throwsStateError);

      request = TestMessage();
      expect(request.read().toList(), completion(isEmpty));
      expect(() => request.readAsString(), throwsStateError);
    });
  });

  group('content-length', () {
    test('is 0 with a default body and without a content-length header', () {
      var request = TestMessage();
      expect(request.contentLength, isZero);
    });

    test('comes from a byte body', () {
      var request = TestMessage(body: <int>[1, 2, 3]);
      expect(request.contentLength, equals(3));
    });

    test('comes from a string body', () {
      var request = TestMessage(body: 'foobar');
      expect(request.contentLength, equals(6));
    });

    test('is set based on byte length for a string body', () {
      var request = TestMessage(body: 'fööbär');
      expect(request.contentLength, equals(9));

      request = TestMessage(body: 'fööbär', encoding: latin1);
      expect(request.contentLength, equals(6));
    });

    test('is null for a stream body', () {
      var request = TestMessage(body: Stream<List<int>>.empty());
      expect(request.contentLength, isNull);
    });

    test('uses the content-length header for a stream body', () {
      var body = Stream<List<int>>.empty();
      var headers = <String, Object>{'content-length': '42'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.contentLength, equals(42));
    });

    test('real body length takes precedence over content-length header', () {
      var body = <int>[1, 2, 3];
      var headers = <String, Object>{'content-length': '42'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.contentLength, equals(3));
    });

    test('is null for a chunked transfer encoding', () {
      var body = '1\r\na0\r\n\r\n';
      var headers = <String, Object>{'transfer-encoding': 'chunked'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.contentLength, isNull);
    });

    test('is null for a non-identity transfer encoding', () {
      var body = '1\r\na0\r\n\r\n';
      var headers = <String, Object>{'transfer-encoding': 'custom'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.contentLength, isNull);
    });

    test('is set for identity transfer encoding', () {
      var body = '1\r\na0\r\n\r\n';
      var headers = <String, Object>{'transfer-encoding': 'identity'};
      var request = TestMessage(body: body, headers: headers);
      expect(request.contentLength, equals(9));
    });
  });

  group('mimeType', () {
    test('is null without a content-type header', () {
      expect(TestMessage().mimeType, isNull);
    });

    test('comes from the content-type header', () {
      var headers = <String, Object>{'content-type': 'text/plain'};
      expect(TestMessage(headers: headers).mimeType, equals('text/plain'));
    });

    test('doesn\'t include parameters', () {
      var headers = <String, Object>{'content-type': 'text/plain; foo=bar; bar=baz'};
      expect(TestMessage(headers: headers).mimeType, equals('text/plain'));
    });
  });

  group('encoding', () {
    test('is null without a content-type header', () {
      expect(TestMessage().encoding, isNull);
    });

    test('is null without a charset parameter', () {
      var headers = <String, Object>{'content-type': 'text/plain'};
      expect(TestMessage(headers: headers).encoding, isNull);
    });

    test('is null with an unrecognized charset parameter', () {
      var headers = <String, Object>{'content-type': 'text/plain; charset=fblthp'};
      expect(TestMessage(headers: headers).encoding, isNull);
    });

    test('comes from the content-type charset parameter', () {
      var headers = <String, Object>{'content-type': 'text/plain; charset=iso-8859-1'};
      expect(TestMessage(headers: headers).encoding, equals(latin1));
    });

    test('comes from the content-type charset parameter with a different case', () {
      var headers = <String, Object>{'Content-Type': 'text/plain; charset=iso-8859-1'};
      expect(TestMessage(headers: headers).encoding, equals(latin1));
    });

    test('defaults to encoding a String as UTF-8', () {
      expect(TestMessage(body: 'è').read().toList(), completion(contains(<int>[195, 168])));
    });

    test('uses the explicit encoding if available', () {
      expect(TestMessage(body: 'è', encoding: latin1).read().toList(), completion(contains(<int>[232])));
    });

    test('adds an explicit encoding to the content-type', () {
      var headers = <String, Object>{'content-type': 'text/plain'};
      var request = TestMessage(body: 'è', encoding: latin1, headers: headers);
      expect(request.headers, containsPair('content-type', 'text/plain; charset=iso-8859-1'));
    });

    test('adds an explicit encoding to the content-type with a different case', () {
      var headers = <String, Object>{'content-type': 'text/plain'};
      var request = TestMessage(body: 'è', encoding: latin1, headers: headers);
      expect(request.headers, containsPair('Content-Type', 'text/plain; charset=iso-8859-1'));
    });

    test('sets an absent content-type to application/octet-stream in order to set the charset', () {
      var request = TestMessage(body: 'è', encoding: latin1);
      expect(request.headers, containsPair('content-type', 'application/octet-stream; charset=iso-8859-1'));
    });

    test('overwrites an existing charset if given an explicit encoding', () {
      var headers = <String, Object>{'content-type': 'text/plain; charset=whatever'};
      var request = TestMessage(body: 'è', encoding: latin1, headers: headers);
      expect(request.headers, containsPair('content-type', 'text/plain; charset=iso-8859-1'));
    });
  });
}
