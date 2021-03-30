void serve(void Function(Map<String, Object>) show) {}

void handler(Map<String, Object> scope) {}

void main(List<String> arguments) {
  serve(handler);
}
