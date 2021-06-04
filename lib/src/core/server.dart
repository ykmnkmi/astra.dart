import 'types.dart';

abstract class Server {
  void mount(Application application);

  void handle(Handler handler);

  Future<void> close({bool force = false});
}
