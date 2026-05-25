import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController divisionController = TextEditingController();
  final TextEditingController deviceIdController = TextEditingController();
  final TextEditingController waterSourceTypeController =
      TextEditingController();
  final TextEditingController waterSourceNameController =
      TextEditingController();
  final TextEditingController waterSourceDivisionController =
      TextEditingController();
  final TextEditingController cultivationTypeController =
      TextEditingController();
  final TextEditingController cropController = TextEditingController();
  final TextEditingController landSizeController = TextEditingController();
  final TextEditingController waterTimesPerDayController =
      TextEditingController();
  final TextEditingController durationPerTimeController =
      TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    divisionController.dispose();
    deviceIdController.dispose();
    waterSourceTypeController.dispose();
    waterSourceNameController.dispose();
    waterSourceDivisionController.dispose();
    cultivationTypeController.dispose();
    cropController.dispose();
    landSizeController.dispose();
    waterTimesPerDayController.dispose();
    durationPerTimeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Validation: check all fields are non-empty
    if (nameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        divisionController.text.trim().isEmpty ||
        deviceIdController.text.trim().isEmpty ||
        waterSourceTypeController.text.trim().isEmpty ||
        waterSourceNameController.text.trim().isEmpty ||
        waterSourceDivisionController.text.trim().isEmpty ||
        cultivationTypeController.text.trim().isEmpty ||
        cropController.text.trim().isEmpty ||
        landSizeController.text.trim().isEmpty ||
        waterTimesPerDayController.text.trim().isEmpty ||
        durationPerTimeController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'සියලු ක්ෂේත‍්ර පුරවන්න';
      });
      return;
    }

    // Device ID format check
    if (!RegExp(r'^wak_sys_\w+$').hasMatch(deviceIdController.text.trim())) {
      setState(() {
        errorMessage = 'උපාංග ID ආකෘතිය වැරදියි (උදා: wak_sys_1)';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final deviceId = deviceIdController.text.trim();

      // Check user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = 'පරිශීලකයා ලොග් වී නොමැත';
        });
        return;
      }

      // Check device ID uniqueness in Firestore
      final usersSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('deviceID', isEqualTo: deviceId)
              .get();

      if (usersSnapshot.docs.isNotEmpty &&
          usersSnapshot.docs.first.id != user.uid) {
        setState(() {
          errorMessage = 'මෙම උපාංග ID දැනටමත් වෙනත් පරිශීලකයෙකුට පවරා ඇත';
        });
        return;
      }

      // Save question data directly in users/{uid} document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'deviceID': deviceId,
        'registeredAt': Timestamp.now(),
        'name': nameController.text.trim(),
        'address': addressController.text.trim(),
        'phone': phoneController.text.trim(),
        'division': divisionController.text.trim(),
        'waterSourceType': waterSourceTypeController.text.trim(),
        'waterSourceName': waterSourceNameController.text.trim(),
        'waterSourceDivision': waterSourceDivisionController.text.trim(),
        'cultivationType': cultivationTypeController.text.trim(),
        'crop': cropController.text.trim(),
        'landSize': landSizeController.text.trim(),
        'waterTimesPerDay': waterTimesPerDayController.text.trim(),
        'durationPerTime': durationPerTimeController.text.trim(),
      }, SetOptions(merge: true));

      // Prepare form data to pass to confirmation screen
      final formData = {
        'deviceID': deviceId,
        'name': nameController.text.trim(),
        'address': addressController.text.trim(),
        'phone': phoneController.text.trim(),
        'division': divisionController.text.trim(),
        'waterSourceType': waterSourceTypeController.text.trim(),
        'waterSourceName': waterSourceNameController.text.trim(),
        'waterSourceDivision': waterSourceDivisionController.text.trim(),
        'cultivationType': cultivationTypeController.text.trim(),
        'crop': cropController.text.trim(),
        'landSize': landSizeController.text.trim(),
        'waterTimesPerDay': waterTimesPerDayController.text.trim(),
        'durationPerTime': durationPerTimeController.text.trim(),
      };

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data submission successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate to confirmation screen with form data
      Navigator.pushNamed(context, '/confirmation', arguments: formData);
    } catch (e) {
      setState(() {
        errorMessage = 'Form submission error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
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
                    const SizedBox(height: 40),
                    const Text(
                      '🧍 පරිශීලක විස්තර',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(nameController, 'නම'),
                    const SizedBox(height: 20),
                    _buildTextField(addressController, 'ලිපිනය'),
                    const SizedBox(height: 20),
                    _buildTextField(
                      phoneController,
                      'දුරකථන අංකය',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(divisionController, 'ප්‍රාදේශීය කොට්ඨාසය'),
                    const SizedBox(height: 20),
                    _buildTextField(deviceIdController, 'උපාංග ID'),
                    const SizedBox(height: 40),
                    const Text(
                      '💧 ජල මූලාශ්‍රය',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      waterSourceTypeController,
                      'ප්‍රධාන ජල මූලාශ්‍රය',
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(waterSourceNameController, 'නම'),
                    const SizedBox(height: 20),
                    _buildTextField(waterSourceDivisionController, 'ප්‍රදේශය'),
                    const SizedBox(height: 40),
                    const Text(
                      '🌾 වගා විස්තර',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(cultivationTypeController, 'වගා වර්ගය'),
                    const SizedBox(height: 20),
                    _buildTextField(cropController, 'බෝගය'),
                    const SizedBox(height: 20),
                    _buildTextField(
                      landSizeController,
                      'ඉඩමේ ප්‍රමාණය (අක්කර)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      waterTimesPerDayController,
                      'දිනකට වාර ගණන',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      durationPerTimeController,
                      'එක් වරක් සඳහා කාලය (මිනිත්තු)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () => setState(() => errorMessage = null),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    errorMessage!,
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
                      ),
                    isLoading
                        ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        )
                        : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              255,
                              255,
                              255,
                            ),
                            minimumSize: const Size.fromHeight(45),
                          ),
                          onPressed: _submitForm,
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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

  Widget _buildTextField(
    TextEditingController controller,
    String labelText, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
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
