import 'package:shelf_client_example/example.dart';

void main() {
  fetchRepositories(
    (int totalCount) {
      print('Number of repositories: $totalCount.');
    },
    (int statusCode) {
      print('Request failed with status: $statusCode.');
    },
  );
}
