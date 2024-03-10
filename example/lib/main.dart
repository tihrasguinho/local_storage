import 'package:example/home_page.dart';
import 'package:flutter/material.dart';
import 'package:local_storage/local_storage.dart';

import 'user_entity.dart';

late final LocalStorage storage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  storage = await LocalStorage.instance();

  storage.registrar<UserEntity>(UserEntity.new);

  storage.set<String>('string', 'Hello World!');

  storage.set<List<String>?>('strings', ['test', 'null']);

  storage.set<List<int>?>('ints', [1, 2, 3]);

  storage.set<List<double>?>('doubles', [1.1, 2.2, 3.3]);

  storage.set<List<bool>?>('booleans', [true, false, true]);

  storage.set<List<DateTime>?>('dates', [
    DateTime.now(),
    DateTime.now(),
    DateTime.now(),
  ]);

  final user = UserEntity(
    id: '1',
    name: 'John',
    email: 'john@gmail.com',
    age: 25,
    weight: 70,
    height: 180,
    birthDate: DateTime.now(),
    admin: false,
  );

  storage.set<UserEntity>('user', user);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}
