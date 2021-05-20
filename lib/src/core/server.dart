import 'types.dart';

abstract class Server<T> {
  void mount(Application application);

  Future<void> close({bool force = false});
}
