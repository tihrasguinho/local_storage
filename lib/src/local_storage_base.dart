import 'entity.dart';

abstract interface class LocalStorageBase {
  T? get<T>(String key);
  void set<T>(String key, T value);
  void remove(String key);
  void clear();
  void registrar<T extends Entity>(Function entity);
}
