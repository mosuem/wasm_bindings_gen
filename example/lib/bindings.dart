import 'package:wasmi/execute.dart';

class AddModule {
  AddModule(this.module);

  final Module module;

  int add(
    int p0,
    int p1,
  ) =>
      module.invoke('add', [p0, p1]) as int;
}
