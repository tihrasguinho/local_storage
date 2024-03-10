import 'package:flutter/material.dart';

import 'main.dart';
import 'user_entity.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final UserEntity user;

  @override
  void initState() {
    super.initState();

    user = storage.get<UserEntity>('user')!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(user.id),
          Text(user.name),
          Text(user.email),
          Text(user.age.toString()),
          Text(user.weight.toString()),
          Text(user.height.toString()),
          Text(user.birthDate.toIso8601String()),
          Text(user.admin.toString()),
          Text('${storage.get<List<String>?>('strings')}'),
        ],
      ),
    );
  }
}
