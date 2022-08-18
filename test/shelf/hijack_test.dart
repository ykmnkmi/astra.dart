// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  test('hijacking a non-hijackable request throws a StateError', () {
    void callback(StreamChannel<List<int>> channel) {}

    expect(() => Request('GET', localhostUri).hijack(callback), throwsStateError);
  });

  test(
      'hijacking a hijackable request throws a HijackException and calls '
      'onHijack', () {
    void onHijack(void Function(StreamChannel<List<int>>) callback) {
      var streamController = StreamController<List<int>>()
        ..add([1, 2, 3])
        ..close();

      var sinkController = StreamController<List<int>>();
      expect(sinkController.stream.first, completion(equals([4, 5, 6])));

      callback(StreamChannel(streamController.stream, sinkController));
    }

    var request = Request('GET', localhostUri, onHijack: expectAsync1(onHijack));

    void callback(StreamChannel<List<int>> channel) {
      expect(channel.stream.first, completion(equals([1, 2, 3])));

      channel.sink
        ..add([4, 5, 6])
        ..close();
    }

    expect(() => request.hijack(expectAsync1(callback)), throwsHijackException);
  });

  test('hijacking a hijackable request twice throws a StateError', () {
    void onHijack(void Function(StreamChannel<List<int>>) callback) {}

    // Assert that the [onHijack] callback is only called once.
    var request = Request('GET', localhostUri, onHijack: expectAsync1(onHijack, count: 1));

    void callback(StreamChannel<List<int>> channel) {}

    expect(() => request.hijack(callback), throwsHijackException);
    expect(() => request.hijack(callback), throwsStateError);
  });

  group('calling change', () {
    test('hijacking a non-hijackable request throws a StateError', () {
      var request = Request('GET', localhostUri);
      var newRequest = request.change();

      void callback(StreamChannel<List<int>> channel) {}

      expect(() => newRequest.hijack(callback), throwsStateError);
    });

    test('hijacking a hijackable request throws a HijackException and calls onHijack', () {
      void onHijack(void Function(StreamChannel<List<int>>) callback) {
        var streamController = StreamController<List<int>>()
          ..add(<int>[1, 2, 3])
          ..close();

        var sinkController = StreamController<List<int>>();
        expect(sinkController.stream.first, completion(equals(<int>[4, 5, 6])));

        callback(StreamChannel(streamController.stream, sinkController));
      }

      var request = Request('GET', localhostUri, onHijack: expectAsync1(onHijack));
      var newRequest = request.change();

      void callback(StreamChannel<List<int>> channel) {
        expect(channel.stream.first, completion(equals(<int>[1, 2, 3])));

        channel.sink
          ..add(<int>[4, 5, 6])
          ..close();
      }

      expect(() => newRequest.hijack(expectAsync1(callback)), throwsHijackException);
    });

    test('hijacking the original request after calling change throws a StateError', () {
      void onHijack(void Function(StreamChannel<List<int>>) callback) {}

      // Assert that the [onHijack] callback is only called once.
      var request = Request('GET', localhostUri, onHijack: expectAsync1(onHijack, count: 1));
      var newRequest = request.change();

      void callback(StreamChannel<List<int>> channel) {}

      expect(() => newRequest.hijack(callback), throwsHijackException);
      expect(() => request.hijack(callback), throwsStateError);
    });
  });
}
