import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DetailsScreen extends StatefulWidget {
  final Map<String, String> userData;

  const DetailsScreen({super.key, required this.userData});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User details
  String userName = 'Loading...';
  String address = 'Loading...';
  String email = 'Loading...';
  String phone = 'Loading...';
  String division = 'Loading...';
  String landSize = 'Loading...';
  String cultivationType = 'Loading...';
  String durationPerTime = 'Loading...';
  String waterTimePerDay = 'Loading...'; // Updated to fetch from Firestore
  String crop = 'Loading...'; // Updated to fetch from Firestore

  // Lake details
  String lakeName = 'Loading...';
  double lakeSize = 1000.0; // Store as number (m²)
  String lakeSizeAcres = '0.247 acres'; // Computed acres

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchLakeData();
  }

  // Fetch user data from Firestore 'users' collection
  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No authenticated user found')),
          );
        }
        return;
      }
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          userName = data['name'];
          address = data['address'];
          email = data['email'];
          phone = data['phone'];
          division = data['division'];
          waterTimePerDay = data['waterTimesPerDay'];
          durationPerTime = data['durationPerTime'];
          landSize =
              data['landSize'] is num
                  ? '${data['landSize']} acres'
                  : '${data['landSize']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? 'Unknown'} acres';
          cultivationType = data['cultivationType']?.toString() ?? 'Unknown';
          crop = data['crop']?.toString() ?? 'Unknown';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User data not found')));
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching user data: $e')));
      }
    }
  }

  // Fetch lake data from Firestore 'lakes' collection, document 'Lake1'
  Future<void> _fetchLakeData() async {
    try {
      final lakeDoc = await _firestore.collection('lakes').doc('Lake1').get();
      if (lakeDoc.exists && mounted) {
        final lakeData = lakeDoc.data() as Map<String, dynamic>;
        double sizeInM2;
        if (lakeData['lakeSize'] is String) {
          sizeInM2 =
              double.tryParse(
                lakeData['lakeSize'].replaceAll(RegExp(r'[^0-9.]'), ''),
              ) ??
              1000.0;
        } else if (lakeData['lakeSize'] is num) {
          sizeInM2 = (lakeData['lakeSize'] as num).toDouble();
        } else {
          sizeInM2 = 1000.0; // Fallback for invalid types
        }
        final sizeInAcres = sizeInM2 * 0.000247105; // Convert m² to acres
        setState(() {
          lakeName = lakeData['lakeName'] ?? 'Unknown Lake';
          lakeSize = sizeInM2;
          lakeSizeAcres = '${sizeInAcres.toStringAsFixed(3)} acres';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lake data not found')));
        }
      }
    } catch (e) {
      print('Error fetching lake data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching lake data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Details',
          style: TextStyle(
            color: Color.fromARGB(255, 11, 37, 1),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 219, 239, 255),
      ),
      body: Stack(
        children: [
          buildBackground(),
          Container(color: Colors.black.withOpacity(0.6)),
          Padding(
            padding: const EdgeInsets.all(16.5),
            child: ListView(
              children: [
                buildSectionTitle('User Details'),
                buildInfoCard(Icons.person, 'නම', userName),
                buildInfoCard(Icons.location_on, 'ලිපිනය', address),
                buildInfoCard(Icons.email, 'විද්‍යුත් ලිපිනය', email),
                buildInfoCard(Icons.phone, 'දුරකථන අංකය', phone),
                buildInfoCard(Icons.map, 'ප්‍රාදේශීය ලේකම් කොට්ඨාසය', division),
                const SizedBox(height: 20),
                buildSectionTitle('Lake Details'),
                buildInfoCard(Icons.water, 'වැව් නම', lakeName),
                buildInfoCard(
                  Icons.landscape,
                  'වැව් ප්‍රමාණය',
                  '${lakeSize.toStringAsFixed(0)} m² ($lakeSizeAcres)',
                ),
                const SizedBox(height: 20),
                buildSectionTitle('Cultivation Details'),
                buildInfoCard(Icons.grass, 'වගාවේ වර්ගය', cultivationType),
                buildInfoCard(Icons.square_foot, 'වගා භූමි ප්‍රමාණය', landSize),
                buildInfoCard(Icons.spa, 'බෝග වර්ගය', crop),
                const SizedBox(height: 20),
                buildSectionTitle('Water Usage Prediction'),
                buildInfoCard(
                  Icons.access_time,
                  'දිනකට අවශ්‍ය ජල ප්‍රමාණය (විනාඩි)',
                  waterTimePerDay,
                ),
                buildInfoCard(
                  Icons.timer,
                  'එක් වරකට අවශ්‍ය ජල ප්‍රමාණය  (විනාඩි)',
                  durationPerTime,
                ),
                const SizedBox(height: 17),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 12, 70, 5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/confirmation.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black45,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInfoCard(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: 8,
          color: Colors.white.withOpacity(1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: const Color.fromARGB(255, 4, 69, 9),
              size: 25,
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Color.fromARGB(255, 4, 69, 9),
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 2, 51, 5),
                fontSize: 16.5,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
        ),
      ),
    );
  }
}
