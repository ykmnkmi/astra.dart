import 'package:astra/core.dart';
import 'package:astra/test.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('response', () {
    test('hello', () async {
      Response handler(Request request) {
        return Response.ok('hello world!');
      }

      var client = TestClient(handler);
      var response = await client.get(Uri(path: ''));
      expect(response.body, 'hello world!');
    });
  });
}
