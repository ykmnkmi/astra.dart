library astra.test.shelf.utils;

import 'package:astra/core.dart';

const List<int> helloWorldBytes = <int>[
  104,
  101,
  108,
  108,
  111,
  32,
  119,
  111,
  114,
  108,
  100
];

Response syncHandler(Request request,
    {int? statusCode, Map<String, String>? headers}) {
  return Response(
      status: statusCode ?? 200,
      headers: headers,
      content: 'Hello from ${request.uri.path}');
}

Future<Response> asyncHandler(Request request) {
  return Future<Response>(() => syncHandler(request));
}
