import 'dart:convert';

import 'package:shelf_client/shelf_client.dart';

Future<void> fetchRepositories(
  void Function(int totalCount) onOk,
  void Function(int statusCode) onElse,
) async {
  var client = Client();

  var response = await client.get(
    Uri(
      scheme: 'https',
      host: 'api.github.com',
      path: 'search/repositories',
      queryParameters: <String, String>{'q': 'Dart HTTP client'},
    ),
    headers: <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  );

  if (response.statusCode == 200) {
    var stringBody = await response.readAsString();
    var jsonResponse = jsonDecode(stringBody) as Map<String, Object?>;
    var totalCount = jsonResponse['total_count'] as int;
    onOk(totalCount);
  } else {
    onElse(response.statusCode);
  }

  client.close();
}
