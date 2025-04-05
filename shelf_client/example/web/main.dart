import 'package:shelf_client_example/example.dart';
import 'package:web/web.dart' hide Client;

Future<void> main() async {
  var body = document.body!;

  fetchRepositories(
    (int totalCount) {
      body.append(Text('Number of repositories: $totalCount.'));
    },
    (int statusCode) {
      body.append(Text('Request failed with status: $statusCode.'));
    },
  );
}
