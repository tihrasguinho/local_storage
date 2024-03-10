import 'package:local_storage/local_storage.dart';

class UserEntity extends Entity {
  final String id;
  final String name;
  final String email;
  final int age;
  final double weight;
  final double height;
  final DateTime birthDate;
  final bool admin;

  UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.weight,
    required this.height,
    required this.birthDate,
    required this.admin,
  });

  @override
  List get props => [id, name, email, age, weight, height, birthDate, admin];
}
