import 'dart:convert';

import 'package:shelf_client/shelf_client.dart';

Future<void> main(List<String> arguments) async {
  var client = Client();

  var response = await client.get(Uri(
    scheme: 'https',
    host: 'www.googleapis.com',
    path: 'books/v1/volumes',
    queryParameters: {'q': '{http}'},
  ));

  if (response.statusCode == 200) {
    var stringBody = await response.readAsString();
    var jsonResponse = jsonDecode(stringBody) as Map<String, Object?>;
    var itemCount = jsonResponse['totalItems'];
    print('Number of books about http: $itemCount.');
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }

  client.close();
}
