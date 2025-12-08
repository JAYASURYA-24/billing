import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { none, user, admin }

final roleProvider = StateNotifierProvider<RoleNotifier, UserRole>((ref) {
  return RoleNotifier();
});

class RoleNotifier extends StateNotifier<UserRole> {
  RoleNotifier() : super(UserRole.none) {
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = prefs.getString('userRole') ?? 'none';
    if (roleString == 'admin') {
      state = UserRole.admin;
    } else if (roleString == 'user') {
      state = UserRole.user;
    } else {
      state = UserRole.none;
    }
  }

  Future<void> loginAsUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'user');
    state = UserRole.user;
  }

  Future<void> loginAsAdmin(String password) async {
    const staticPassword = 'Rajpreetha@1234';
    if (password == staticPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'admin');
      state = UserRole.admin;
    } else {
      throw Exception("Invalid password");
    }
  }

  Future<void> logout() async {
    state = UserRole.none;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
  }
}
