import 'connection.dart';
import 'types.dart';

abstract class Server extends Stream<Connection> {
  void mount(Application application);

  void handle(Handler handler);

  Future<void> close({bool force = false});
}
