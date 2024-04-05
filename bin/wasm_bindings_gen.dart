import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as path;
import 'package:wasmi/parse.dart';
import 'package:wasmi/types.dart' as wasmi_types;

void main(List<String> args) {
  final fileName = args.first;
  final definition = ModuleDefinition.parse(File(fileName));

  final className = args.length > 1
      ? args[1]
      : path.basenameWithoutExtension(fileName).capitalize();

  Library l = _toDartCode(className, definition);

  final emitter = DartEmitter();
  print(DartFormatter().format('${l.accept(emitter)}'));
}

Library _toDartCode(String className, ModuleDefinition definition) {
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
      ..methods.addAll(definition.exportedFunctions
          .map((function) => _toDartMethod(function))
          .whereType()),
  );
  return Library(
    (lb) => lb
      ..body.add(c)
      ..directives.add(
        Directive.import('package:wasmi/execute.dart'),
      ),
  );
}

Method? _toDartMethod(ExportedFunction function) {
  final functionType = function.func.functionType;
  if (functionType != null) {
    final parameterTypes = functionType.parameterTypes;
    final parameters = List.generate(
      parameterTypes.length,
      (index) => Parameter(
        (pb) => pb
          ..name = 'p$index'
          ..type = Reference(parameterTypes[index].toDartType()),
      ),
    );
    String resultType = functionType.toDartType();
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
  } else {
    //TODO: Should this be a function without signature?
    return null;
  }
}

extension on wasmi_types.FunctionType {
  String toDartType() {
    if (resultTypes.isEmpty) {
      return 'void';
    } else if (resultTypes.length == 1) {
      return resultTypes.first.toDartType();
    } else {
      return '(${resultTypes.join(',')})';
    }
  }
}

extension on wasmi_types.ValueType {
  String toDartType() => switch (this) {
        wasmi_types.ValueType.i32 => 'int',
        wasmi_types.ValueType.i64 => 'int',
        wasmi_types.ValueType.f32 => 'double',
        wasmi_types.ValueType.f64 => 'double',
        wasmi_types.ValueType.v128 => 'List<int>',
        wasmi_types.ValueType.funcref => 'Function',
        wasmi_types.ValueType.externref => 'Object',
      };
}

extension StringExtension on String {
  String capitalize() => isNotEmpty
      ? "${this[0].toUpperCase()}${substring(1).toLowerCase()}"
      : this;
}
