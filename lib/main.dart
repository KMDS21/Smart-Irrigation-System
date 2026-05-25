import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'question_screen.dart';
import 'confirmation_screen.dart';
import 'home_screen.dart';
import 'admin_control_screen.dart';
import 'splash_screen.dart'; // Ensure splash screen is included

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(const Ecoh2oApp());
}

class Ecoh2oApp extends StatelessWidget {
  const Ecoh2oApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECO H2O',
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // Set splash screen as initial route
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 177, 182, 184),
            textStyle: const TextStyle(fontSize: 20),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/question': (context) => const QuestionScreen(),
        '/confirmation':
            (context) => ConfirmationScreen(
              formData:
                  (ModalRoute.of(context)?.settings.arguments
                      as Map<String, String>?) ??
                  {},
            ),
        '/home': (context) => const HomeScreen(),
        '/admin': (context) => const AdminControlScreen(),
      },
      onUnknownRoute:
          (settings) => MaterialPageRoute(
            builder:
                (context) => const Scaffold(
                  body: Center(child: Text('Route not found')),
                ),
          ),
    );
  }
}
