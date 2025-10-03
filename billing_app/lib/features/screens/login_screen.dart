import 'package:billing/features/screens/billing_screen.dart';
import 'package:billing/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/role_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _obscurePassword = true; // 🔑 state for password visibility

  @override
  Widget build(BuildContext context) {
    final roleNotifier = ref.read(roleProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Login as User"),
              onPressed: () async {
                await roleNotifier.loginAsUser();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainNavigationScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Login as Admin"),
              onPressed: () {
                showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (context) {
                    final controller = TextEditingController();
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          title: const Text("Enter Admin Password"),
                          content: TextField(
                            controller: controller,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await roleNotifier.loginAsAdmin(
                                    controller.text,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context); // close dialog
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const MainNavigationScreen(),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Wrong password!"),
                                    ),
                                  );
                                }
                              },
                              child: const Text("Login"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
