import 'dart:io';

void main() {
  print(File('../ng/README.md').existsSync());
}