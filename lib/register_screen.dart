import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController(),
      pwdCtrl = TextEditingController(),
      repwdCtrl = TextEditingController(),
      areaCtrl = TextEditingController(),
      phoneCtrl = TextEditingController();
  bool isLoading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    repwdCtrl.dispose();
    areaCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = emailCtrl.text.trim(),
        pwd = pwdCtrl.text,
        repwd = repwdCtrl.text,
        area = areaCtrl.text.trim(),
        phone = phoneCtrl.text.trim();

    if ([email, pwd, repwd, area, phone].contains('')) {
      return setState(() => error = 'Fill in all fields');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return setState(() => error = 'Enter a valid email address');
    }
    if (pwd != repwd) {
      return setState(() => error = 'Passwords do not match');
    }
    if (pwd.length < 6) {
      return setState(
        () => error = 'Password must be at least 6 characters long',
      );
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return setState(
        () => error = 'Invalid phone number (requires 10 digits)',
      );
    }

    setState(() => isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pwd);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
            'email': email,
            'area': area,
            'telephone': phone,
            'createdAt': Timestamp.now(),
          }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration is successful!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/question');
    } on FirebaseAuthException catch (e) {
      setState(
        () =>
            error =
                {
                  'email-already-in-use':
                      'This email address is already in use',
                  'invalid-email': 'Invalid email address',
                  'weak-password': 'Password too weak',
                }[e.code] ??
                'Registration error: ${e.message}',
      );
    } catch (e) {
      setState(() => error = 'An error occurred');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/login_screen.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ECO H20',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _textField(emailCtrl, 'E-mail', TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _textField(
                      pwdCtrl,
                      'Password',
                      TextInputType.text,
                      obscure: true,
                    ),
                    const SizedBox(height: 20),
                    _textField(
                      repwdCtrl,
                      'Re-enter password',
                      TextInputType.text,
                      obscure: true,
                    ),
                    const SizedBox(height: 20),
                    _textField(areaCtrl, 'Area', TextInputType.text),
                    const SizedBox(height: 20),
                    _textField(phoneCtrl, 'Telephone NO', TextInputType.phone),
                    const SizedBox(height: 24),
                    if (error != null)
                      GestureDetector(
                        onTap: () => setState(() => error = null),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    isLoading
                        ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.blue),
                        )
                        : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color.fromARGB(
                              255,
                              246,
                              244,
                              244,
                            ),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _register,
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap:
                          () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Already have an account? Log in',
                        style: TextStyle(
                          color: Color.fromARGB(255, 138, 182, 218),
                          decoration: TextDecoration.underline,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label,
    TextInputType type, {
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : 'Field',
        labelStyle: const TextStyle(color: Colors.white),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
