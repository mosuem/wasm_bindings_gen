import 'dart:io';

import 'package:example/bindings.dart';
import 'package:wasmi/execute.dart';
import 'package:wasmi/parse.dart';

int addTo42(int i) {
  //TODO: fetch in build.dart, get asset using AssetBundle interface
  final moduleDefinition = ModuleDefinition.parse(File('assets/add.wasm'));
  final module = Module(moduleDefinition);
  return AddModule(module).add(42, i);
}
