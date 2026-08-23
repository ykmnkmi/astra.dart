import 'package:hooks/hooks.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    await ZigBuilder(
      assetName: 'src/ffi.dart',
      zigDir: 'native/',
    ).run(input: input, output: output);
  });
}
