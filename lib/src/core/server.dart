import 'types.dart';

abstract class Server<T> {
  void call(Application application);

  Future<void> close({bool force = false});
}
