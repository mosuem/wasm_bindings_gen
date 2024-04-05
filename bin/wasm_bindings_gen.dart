import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as path;
import 'package:wasmi/parse.dart';
import 'package:wasmi/types.dart';

void main(List<String> args) {
  final fileName = args.first;
  final definition = ModuleDefinition.parse(File(fileName));

  final functions = definition.exportedFunctions.map(
    (function) {
      final functionType = function.func.functionType;
      if (functionType != null) {
        final list = functionType.parameterTypes;
        final parameters = List.generate(
          list.length,
          (index) => Parameter(
            (pb) => pb
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
          (mb) => mb
            ..name = function.name
            ..requiredParameters.addAll(parameters)
            ..returns = Reference(resultType)
            ..lambda = true
            ..body = Code('''
module.invoke('${function.name}', ${parameters.map((e) => e.name).toList()}) as $resultType
'''),
        );
      }
    },
  );
  final className = args.length > 1
      ? args[1]
      : path.basenameWithoutExtension(fileName).capitalize();
  final c = Class(
    (cb) => cb
      ..name = className
      ..fields.add(Field(
        (fb) => fb
          ..name = 'module'
          ..type = Reference('Module')
          ..modifier = FieldModifier.final$,
      ))
      ..constructors.add(Constructor(
        (conb) => conb.requiredParameters.add(Parameter(
          (pb) => pb
            ..name = 'module'
            ..toThis = true,
        )),
      ))
      ..methods.addAll(functions.whereType()),
  );
  final l = Library(
    (lb) => lb
      ..body.add(c)
      ..directives.add(
        Directive.import('package:wasmi/execute.dart'),
      ),
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
