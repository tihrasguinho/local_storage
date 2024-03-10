import 'param.dart';

class Class {
  final Type type;
  final Function constructor;
  final List<Param> params;

  const Class({required this.type, required this.constructor, required this.params});

  @override
  String toString() => 'Class(type: $type, constructor: $constructor, params: $params)';
}
