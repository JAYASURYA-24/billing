import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:billing/features/services/firebase_options.dart';
import 'package:billing/features/screens/billing_screen.dart';
import 'package:billing/features/screens/prduct_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(); // Uses default firebase_options.dart generated for Android/iOS
  } else {
    await Firebase.initializeApp(
      options: windowsFirebaseOptions,
    ); // Custom for Windows
  }

  runApp(const ProviderScope(child: BillingApp()));
}

class BillingApp extends StatelessWidget {
  const BillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing System',
      theme: ThemeData(primarySwatch: Colors.teal),
      debugShowCheckedModeBanner: false,
      home: const HomeSelector(),
    );
  }
}

class HomeSelector extends StatelessWidget {
  const HomeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing App Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Go to Billing Screen'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BillingScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Go to Admin Screen'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
