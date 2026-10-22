import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LocationQuestApp());
}

class LocationQuestApp extends StatelessWidget {
  const LocationQuestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Location Quest',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('Authentication initialization failed.')),
        );
      }
      if (snapshot.data == null) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signInAnonymously();
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign-in failed: $e')),
                    );
                }
              },
              child: const Text('Start as guest'),
            ),
          ),
        );
      }
      return const HomeScreen();
    },
  );
}
