part of '../../http.dart';

class Incoming extends Stream<Uint8List> {
  Incoming(this.headers, this.transferLength, this.stream);

  final Headers headers;

  // The transfer length if the length of the message body as it
  // appears in the message (RFC 2616 section 4.4). This can be -1 if
  // the length of the massage body is not known due to transfer
  // codings.
  final int transferLength;

  final Stream<Uint8List> stream;

  final Completer<bool> dataCompleter = Completer<bool>();

  bool fullBodyRead = false;

  bool upgraded = false;

  bool hasSubscriber = false;

  String? method;

  Uri? uri;

  Future<bool> get dataDone {
    return dataCompleter.future;
  }

  void close(bool closing) {
    fullBodyRead = true;
    hasSubscriber = true;
    dataCompleter.complete(closing);
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData, //
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    hasSubscriber = true;

    void onError(dynamic error) {
      throw HttpException(error.message as String, uri: uri);
    }

    return stream.handleError(onError).listen(onData, //
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }
}
