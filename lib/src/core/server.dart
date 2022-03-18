abstract class Server {
  Uri get url;

  Future<void> close();
}
