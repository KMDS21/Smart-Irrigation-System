import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfirmationScreen extends StatefulWidget {
  final Map<String, String> formData;

  const ConfirmationScreen({super.key, required this.formData});

  @override
  _ConfirmationScreenState createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'තහවුරු කිරීම',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

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
          Container(color: Colors.black.withOpacity(0.7)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  const SizedBox(height: 0),
                  Expanded(
                    child: ListView(
                      children: [
                        sectionTitle("🧍 පරිශීලක විස්තර"),
                        infoText("නම", widget.formData['name']),
                        infoText("ලිපිනය", widget.formData['address']),
                        infoText("දුරකථන අංකය", widget.formData['phone']),
                        infoText(
                          "ප්‍රාදේශීය කොට්ඨාසය",
                          widget.formData['division'],
                        ),
                        infoText("උපාංග ID", widget.formData['deviceID']),

                        const SizedBox(height: 16),
                        sectionTitle("💧 ජල මූලාශ්‍රය"),
                        infoText(
                          "ප්‍රධාන ජල මූලාශ්‍රය",
                          widget.formData['waterSourceType'],
                        ),
                        infoText("නම", widget.formData['waterSourceName']),
                        infoText(
                          "ප්‍රදේශය",
                          widget.formData['waterSourceDivision'],
                        ),

                        const SizedBox(height: 16),
                        sectionTitle("🌾 වගා විස්තර"),
                        infoText(
                          "වගා වර්ගය",
                          widget.formData['cultivationType'],
                        ),
                        infoText("බෝගය", widget.formData['crop']),
                        infoText("ඉඩමේ ප්‍රමාණය", widget.formData['landSize']),
                        infoText(
                          "දිනකට වාර ගණන",
                          widget.formData['waterTimesPerDay'],
                        ),
                        infoText(
                          "එක් වරක් සඳහා කාලය",
                          "${widget.formData['durationPerTime'] ?? '-'} මිනිත්තු",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => confirmAndGoHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 2, 54, 4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'තහවුරු කරන්න',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 17.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget infoText(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Text(
        '$label: ${value ?? '-'}',
        style: const TextStyle(color: Colors.white, fontSize: 17),
      ),
    );
  }

  void confirmAndGoHome(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('පරිශීලකයා ලොග් වී නොමැත'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: {'deviceID': widget.formData['deviceId']},
    );
  }
}
