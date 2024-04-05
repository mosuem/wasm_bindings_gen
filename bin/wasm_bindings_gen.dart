import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as path;
import 'package:wasmi/parse.dart';
import 'package:wasmi/types.dart';

void main(List<String> args) {
  var fileName = args.first;
  var definition = ModuleDefinition.parse(File(fileName));

  final functions = definition.exportedFunctions.map(
    (e) {
      var functionType = e.func.functionType;
      if (functionType != null) {
        var list = functionType.parameterTypes;
        final parameters = List.generate(
          list.length,
          (index) => Parameter(
            (p0) => p0
              ..name = 'p$index'
              ..type = Reference(list[index].toDartType()),
          ),
        );
        final String resultType;
        if (functionType.resultTypes.isEmpty) {
          resultType = 'void';
        } else if (functionType.resultTypes.length == 1) {
          resultType = functionType.resultTypes.first.toDartType();
        } else {
          resultType = '(${functionType.resultTypes.join(',')})';
        }
        return Method(
          (p0) => p0
            ..name = e.name
            ..static = true
            ..requiredParameters.addAll(parameters)
            ..returns = Reference(resultType)
            ..lambda = true
            ..body = Code('''
module.invoke('${e.name}', ${parameters.map((e) => e.name).toList()})
'''),
        );
      }
    },
  );
  final className = args.length > 1
      ? args[1]
      : path.basenameWithoutExtension(fileName).capitalize();
  var c = Class(
    (p0) => p0
      ..name = className
      ..methods.addAll(functions.whereType()),
  );
  var l = Library(
    (p0) => p0.body.add(c),
  );
  final emitter = DartEmitter();
  print(DartFormatter().format('${l.accept(emitter)}'));
}

extension StringExtension on String {
  String capitalize() => isNotEmpty
      ? "${this[0].toUpperCase()}${substring(1).toLowerCase()}"
      : this;
}

extension on ValueType {
  String toDartType() => switch (this) {
        ValueType.i32 => 'int',
        ValueType.i64 => 'int',
        ValueType.f32 => 'double',
        ValueType.f64 => 'double',
        ValueType.v128 => 'List<int>',
        ValueType.funcref => 'Function',
        ValueType.externref => 'Object',
      };
}
