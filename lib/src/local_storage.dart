import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:local_storage/local_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'class.dart';
import 'param.dart';

bool _isSubtype<S, T>() => <S>[] is List<T>;

const _separator = '::separator::';
const _null = '::null::';
const _listNull = '::listNull::';

class LocalStorage implements LocalStorageBase {
  final File _storage;

  late final Map<Type, Class> _classes;

  late final StreamController<Map<String, dynamic>> _controller;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  LocalStorage._(this._storage) {
    _classes = {};
    _controller = StreamController<Map<String, dynamic>>.broadcast();
    if (!_storage.existsSync()) {
      _storage.createSync(recursive: true);

      final map = <String, dynamic>{
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      _storage.writeAsStringSync(jsonEncode(map));
    }
  }

  static Future<LocalStorage> instance() async {
    final documentsDir = await getApplicationSupportDirectory();

    final file = File(p.join(documentsDir.path, 'local_storage', 'database.json'));

    return LocalStorage._(file);
  }

  @override
  void clear() {
    return _storage.writeAsStringSync(
      jsonEncode(
        {
          'version': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  @override
  T? get<T>(String key) {
    if (_isSubtype<T, Entity>()) {
      if (!_classes.containsKey(T)) {
        throw ArgumentError('The class ${T.toString()} is not registered!');
      }

      final cls = _classes[T]!;

      final params = cls.params;

      final source = _getJson(key);

      if (source == null) return null;

      if (source.length - 2 != params.length) {
        throw ArgumentError('The class ${T.toString()} has ${params.length} params, but the source has ${source.length - 2} params!');
      }

      for (var i = 0; i < params.length; i++) {
        final param = params[i];

        if (_classes.keys.map((e) => e.toString()).contains(param.type)) {
          final innerSource = Map<String, dynamic>.from(source.entries.elementAt(i + 2).value);

          final innerData = _classes.entries.firstWhere((e) => e.key.toString() == param.type).value;

          final innerParams = innerData.params;

          for (var j = 0; j < innerParams.length; j++) {
            final innerParam = innerParams[j];

            final innerBytes = innerSource.entries.elementAt(j + 2).value['value'];
            final innerValue = (innerBytes as List).map((e) => e as int).toList();

            innerParams[j] = innerParam.setValue(_decodeParam(innerParam.type, innerValue));
          }

          final innerEntity = Function.apply(
            innerData.constructor,
            innerData.params.whereType<PositionalParam>().map((param) => param.value).toList(),
            innerData.params.whereType<NamedParam>().fold(<Symbol, dynamic>{}, (prev, next) => {...?prev, next.named: next.value}),
          );

          params[i] = param.setValue(innerEntity);
        } else {
          final bytes = source.entries.elementAt(i + 2).value['value'];
          final value = (bytes as List).map((e) => e as int).toList();

          params[i] = param.setValue(_decodeParam(param.type, value));
        }
      }

      return Function.apply(
        cls.constructor,
        params.whereType<PositionalParam>().map((param) => param.value).toList(),
        params.whereType<NamedParam>().fold(<Symbol, dynamic>{}, (prev, next) => {...?prev, next.named: next.value}),
      );
    } else {
      if (_isSubtype<T, List>() || _isSubtype<T, List?>()) {
        final value = _getJson(key);

        if (value == null) return null;

        final type = T.toString();

        final decoded = _decodeParam(T.toString(), (value[type.endsWith('?') ? type.substring(0, type.length - 1) : type] as List).map((e) => e as int).toList());

        if (decoded == _null) return null;

        return decoded as T;
      } else if (_isSubtype<T, String>() || _isSubtype<T, String?>()) {
        final value = _getJson(key);

        if (value == null) return null;

        final decoded = _decodeParam('String', (value['String'] as List).map((e) => e as int).toList());

        if (decoded == _null) return null;

        return decoded as T;
      }

      return null;
    }
  }

  @override
  void remove(String key) {
    final source = _getStorage();

    source.remove(key);

    _storage.writeAsStringSync(jsonEncode(source));
  }

  @override
  void set<T>(String key, T value) {
    if (_isSubtype<T, Entity>()) {
      if (!_classes.containsKey(T)) {
        throw ArgumentError('The class ${T.toString()} is not registered!');
      }

      final cls = _classes[T]!;

      final params = cls.params;

      _encodePropToParam(params, value as Entity);

      final map = params.fold(
        <String, dynamic>{
          '__type': T.toString(),
          '__nullable': T.toString().endsWith('?'),
        },
        (prev, next) => {
          ...prev,
          params.indexOf(next).toString(): {
            '__type': next.type,
            '__nullable': next.nullable,
            if (next.value is List<int>) 'value': next.value,
            if (next.value is Map<String, dynamic>) ...next.value,
          },
        },
      );

      return _updateFile(key, map);
    } else {
      if (_isSubtype<T, List>() || _isSubtype<T, List?>()) {
        final list = T.toString();
        final type = list.endsWith('?') ? list.substring(0, list.length - 1) : list;
        final nullable = T.toString().endsWith('?');

        switch (list) {
          case 'List<String>' || 'List<int>' || 'List<double>' || 'List<bool>':
            {
              final content = (value as List).join(',');

              return _updateFile(
                key,
                {
                  '__type': type,
                  '__nullable': nullable,
                  type: utf8.encode(content),
                },
              );
            }
          case 'List<String?>' || 'List<int?>' || 'List<double?>' || 'List<bool?>':
            {
              final content = (value as List).map((e) => e ?? _null).join(',');

              return _updateFile(
                key,
                {
                  '__type': type,
                  '__nullable': nullable,
                  type: utf8.encode(content),
                },
              );
            }
          case 'List<String>?' || 'List<int>?' || 'List<double>?' || 'List<bool>?':
            {
              final content = (value as List?)?.join(',') ?? _listNull;

              return _updateFile(
                key,
                {
                  '__type': type,
                  '__nullable': nullable,
                  type: utf8.encode(content),
                },
              );
            }
          case 'List<String?>?' || 'List<int?>?' || 'List<double?>?' || 'List<bool?>?':
            {
              final content = (value as List?)?.map((e) => e ?? _null).join(',') ?? _listNull;

              return _updateFile(
                key,
                {
                  '__type': type,
                  '__nullable': nullable,
                  type: utf8.encode(content),
                },
              );
            }
          case 'List<DateTime>' || 'List<DateTime?>':
            {
              final content = (value as List).map((e) => e?.millisecondsSinceEpoch ?? _null).join(',');

              return _updateFile(
                key,
                {
                  '__type': type,
                  '__nullable': nullable,
                  type: utf8.encode(content),
                },
              );
            }
          case 'List<DateTime>?' || 'List<DateTime?>?':
            {
              final content = (value as List?)?.map((e) => e?.millisecondsSinceEpoch ?? _null).join(',') ?? _listNull;

              return _updateFile(
                key,
                {
                  '__type': type,
                  '__nullable': nullable,
                  type: utf8.encode(content),
                },
              );
            }
          default:
            throw UnsupportedError('Unsupported list type: $list');
        }
      } else if (_isSubtype<T, String>() || _isSubtype<T, String?>()) {
        return _updateFile(
          key,
          {
            '__type': 'String',
            '__nullable': T.toString().endsWith('?'),
            'String': utf8.encode(value == null ? _null : value as String),
          },
        );
      } else if (_isSubtype<T, int>() || _isSubtype<T, int?>()) {
        return _updateFile(
          key,
          {
            '__type': 'int',
            '__nullable': T.toString().endsWith('?'),
            'int': value != null ? utf8.encode('${value as int}') : utf8.encode(_null),
          },
        );
      } else if (_isSubtype<T, double>() || _isSubtype<T, double?>()) {
        return _updateFile(
          key,
          {
            '__type': 'double',
            '__nullable': T.toString().endsWith('?'),
            'double': value != null ? utf8.encode('${value as double}') : utf8.encode(_null),
          },
        );
      } else if (_isSubtype<T, bool>() || _isSubtype<T, bool?>()) {
        return _updateFile(
          key,
          {
            '__type': 'bool',
            '__nullable': T.toString().endsWith('?'),
            'bool': value != null ? utf8.encode('${value as bool}') : utf8.encode(_null),
          },
        );
      } else if (_isSubtype<T, DateTime>() || _isSubtype<T, DateTime?>()) {
        return _updateFile(
          key,
          {
            '__type': 'DateTime',
            '__nullable': T.toString().endsWith('?'),
            'DateTime': value != null ? utf8.encode('${(value as DateTime).millisecondsSinceEpoch}') : utf8.encode(_null),
          },
        );
      } else {
        throw UnsupportedError('Unsupported type: $T');
      }
    }
  }

  @override
  void registrar<T extends Entity>(Function constructor) {
    final constructorRegex = RegExp(r'\((.+)\)\s\=\>\s(.+)');

    final type = constructorRegex.firstMatch(constructor.runtimeType.toString())?.group(2) ?? '';

    assert(type == T.toString(), 'The constructor type should be ${T.toString()}!');

    final strParams = constructorRegex.firstMatch(constructor.runtimeType.toString())?.group(1) ?? '';

    if (strParams.isEmpty) return;

    final cls = Class(
      type: T,
      constructor: constructor,
      params: _extractParams(strParams),
    );

    _classes[T] = cls;
  }

  List<Param> _extractParams(String strParams) {
    final params = <Param>[];

    final posParams = strParams.replaceFirst(RegExp(r'{(.+)}'), '').replaceAll(RegExp(r'(\[|\])'), '').split(',').where((param) => param.trim().isNotEmpty).toList();

    params.addAll(
      posParams.map(
        (param) {
          return PositionalParam(
            type: param.trim().replaceFirst('?', ''),
            nullable: param.trim().endsWith('?'),
          );
        },
      ),
    );

    final namedParamsRegex = RegExp(r'(\{(.+)\})');

    final namedParams = namedParamsRegex.firstMatch(strParams)?.group(2);

    if (namedParams == null) return [];

    final splited = namedParams.split(',');

    params.addAll(
      splited.map(
        (param) {
          final match = RegExp(r'(required )?([\w\?]+)\s([\w]+)').firstMatch(param.trim())!;
          final type = match.group(2)!;
          final nullable = type.endsWith('?');
          final name = match.group(3)!;

          return NamedParam(
            type: type.replaceFirst('?', ''),
            nullable: nullable,
            named: Symbol(name),
          );
        },
      ),
    );

    return params;
  }

  void _encodePropToParam(List<Param> params, Entity entity) {
    for (var i = 0; i < entity.props.length; i++) {
      final prop = entity.props[i];

      switch (prop) {
        case String value:
          params[i] = params[i].setValue(utf8.encode(value));
          break;
        case List<String> value:
          params[i] = params[i].setValue(utf8.encode(value.join(_separator)));
          break;
        case int value:
          params[i] = params[i].setValue(utf8.encode('$value'));
          break;
        case List<int> value:
          params[i] = params[i].setValue(utf8.encode(value.join(_separator)));
          break;
        case double value:
          params[i] = params[i].setValue(utf8.encode('$value'));
          break;
        case List<double> value:
          params[i] = params[i].setValue(utf8.encode(value.join(_separator)));
          break;
        case bool value:
          params[i] = params[i].setValue(utf8.encode('$value'));
          break;
        case List<bool> value:
          params[i] = params[i].setValue(utf8.encode(value.join(_separator)));
          break;
        case DateTime value:
          params[i] = params[i].setValue(utf8.encode('${value.millisecondsSinceEpoch}'));
          break;
        case List<DateTime> value:
          params[i] = params[i].setValue(utf8.encode(value.map((e) => e.millisecondsSinceEpoch).join(_separator)));
          break;
        case Entity value:
          if (!_classes.containsKey(value.runtimeType)) {
            throw Exception('The entity type ${value.runtimeType} is not registered!');
          } else {
            final data = _classes[value.runtimeType]!;

            if (value.props.length != data.params.length) {
              throw Exception('The number of parameters does not match!');
            }

            final innerParams = data.params;

            _encodePropToParam(innerParams, value);

            final innerMap = innerParams.fold(
              <String, dynamic>{},
              (prev, next) => {
                ...prev,
                innerParams.indexOf(next).toString(): {
                  '__type': next.type,
                  '__nullable': next.nullable,
                  'value': next.value,
                },
              },
            );

            params[i] = params[i].setValue(innerMap);
          }
          break;
        case dynamic value:
          if (value == null) {
            params[i] = params[i].setValue(utf8.encode(_null));
            break;
          } else {
            break;
          }
      }
    }
  }

  void _updateFile(String key, dynamic value) {
    final map = Map<String, dynamic>.from(jsonDecode(_storage.readAsStringSync()));

    map[key] = value;

    map['updated_at'] = DateTime.now().toIso8601String();

    _storage.writeAsStringSync(jsonEncode(map));
  }

  Map<String, dynamic> _getStorage() {
    return Map<String, dynamic>.from(jsonDecode(_storage.readAsStringSync()));
  }

  Map<String, dynamic>? _getJson(String key) {
    final source = _getStorage();

    if (!source.containsKey(key)) return null;

    return Map<String, dynamic>.from(source[key]);
  }

  dynamic _decodeParam(String type, List<int> value) {
    final decoded = String.fromCharCodes(value);

    if (decoded == _null || decoded == _listNull) return null;

    return switch (type) {
      'String' => decoded,
      'List<String>' || 'List<String>?' => decoded.split(','),
      'List<String?>' || 'List<String?>?' => decoded.split(',').map((e) => e == _null ? null : e).toList(),
      'int' => int.parse(decoded),
      'List<int>' || 'List<int>?' => decoded.split(',').map((e) => int.parse(e)).toList(),
      'List<int?>' || 'List<int?>?' => decoded.split(',').map((e) => e == _null ? null : int.parse(e)).toList(),
      'double' => double.parse(decoded),
      'List<double>' || 'List<double>?' => decoded.split(',').map((e) => double.parse(e)).toList(),
      'List<double?>' || 'List<double?>?' => decoded.split(',').map((e) => e == _null ? null : double.parse(e)).toList(),
      'bool' => decoded == 'true',
      'List<bool>' || 'List<bool>?' => decoded.split(',').map((e) => e == 'true').toList(),
      'List<bool?>' || 'List<bool?>?' => decoded.split(',').map((e) => e == _null ? null : e == 'true').toList(),
      'DateTime' => DateTime.fromMillisecondsSinceEpoch(int.parse(decoded)),
      'List<DateTime>' || 'List<DateTime>?' => decoded.split(',').map((e) => DateTime.fromMillisecondsSinceEpoch(int.parse(e))).toList(),
      'List<DateTime?>' || 'List<DateTime?>?' => decoded.split(',').map((e) => e == _null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(e))).toList(),
      _ => null,
    };
  }
}
