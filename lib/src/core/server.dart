part of '../../astra.dart';

abstract class Runner<T> {
  T get server;

  Future<void> close({bool force = false});
}
