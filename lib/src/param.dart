sealed class Param {
  final String type;
  final bool nullable;

  final dynamic value;

  Param({
    required this.type,
    this.nullable = false,
    this.value,
  });

  Param setValue(dynamic value);

  @override
  String toString() => 'Param(className: $type, isNullable: $nullable, value: $value)';
}

final class NamedParam extends Param {
  final Symbol named;

  NamedParam({
    required super.type,
    super.value,
    required this.named,
    super.nullable = false,
  });

  @override
  NamedParam setValue(dynamic value) {
    return NamedParam(
      named: named,
      type: type,
      nullable: nullable,
      value: value,
    );
  }

  @override
  String toString() {
    return 'NamedParam(named: $named, className: $type, isNullable: $nullable, value: $value)';
  }
}

final class PositionalParam extends Param {
  PositionalParam({
    required super.type,
    super.value,
    super.nullable = false,
  });

  @override
  PositionalParam setValue(dynamic value) {
    return PositionalParam(
      type: type,
      nullable: nullable,
      value: value,
    );
  }

  @override
  String toString() {
    return 'PositionalParam(className: $type, isNullable: $nullable, value: $value)';
  }
}
