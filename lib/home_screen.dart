import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'Details.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isWaterOn = false;
  String selectedMode = "basic";
  int targetTime = 0;
  int targetHours = 0;
  int targetMinutes = 0;
  int targetVolume = 0;

  String userName = '';
  String cultivationType = '';
  String landSize = '';
  String crop = '';
  String waterSourceName = '';
  double waterLevel = 0.0;
  String lakeName = '';

  int liveVolume = 0;
  int liveTargetTime = 0;
  int totalWaterOutput = 0;

  String? deviceId;
  final databaseRef = FirebaseDatabase.instance.ref();
  final firestore = FirebaseFirestore.instance;

  List<String> notifications = [];
  bool showNotificationPanel = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      await fetchUserData();
      await fetchLakeName();
      if (deviceId != null) {
        fetchWaterLevel();
        linkUserToDevice();
        fetchControlPanelData();
        fetchLiveStats();
        fetchTotalWaterOutput();
      } else {
        print('Error: deviceId is null');
      }
    } catch (e) {
      print('Error initializing data: $e');
    }
  }

  Future<void> fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Error: No authenticated user');
        return;
      }
      final userDoc = firestore.collection('users').doc(user.uid);
      DocumentSnapshot snapshot = await userDoc.get();

      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          deviceId = data['deviceID'] ?? 'wak_sys_1';
          userName = data['name'] ?? 'පරිශීලකයා';
          cultivationType = data['cultivationType'] ?? '';
          final landSizeRaw = data['landSize']?.toString() ?? '0';
          landSize = '$landSizeRaw acre';
          crop = data['crop'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> fetchLakeName() async {
    try {
      final snapshot = await firestore.collection('lakes').limit(1).get();
      if (snapshot.docs.isNotEmpty && mounted) {
        final lakeData = snapshot.docs.first.data();
        setState(() {
          lakeName = lakeData['lakeName'] ?? 'Unknown Lake';
        });
      }
    } catch (e) {
      print('Error fetching lake name: $e');
    }
  }

  Future<void> linkUserToDevice() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || deviceId == null) {
        print('Error: User or deviceId is null');
        return;
      }
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userDetails = {
          'name': userData['name'] ?? '',
          'phone': userData['phone'] ?? '',
          'division': userData['division'] ?? '',
          'waterSourceName': userData['waterSourceName'] ?? '',
          'landSize': userData['landSize'] ?? '',
          'crop': userData['crop'] ?? '',
        };
        await databaseRef
            .child('deviceID/$deviceId/users/${user.uid}')
            .set(userDetails);
      }
    } catch (e) {
      print('Error linking user to device: $e');
    }
  }

  void fetchWaterLevel() {
    databaseRef
        .child('dam_sys/waterLevel')
        .onValue
        .listen(
          (event) {
            final value = event.snapshot.value;
            if (value != null && mounted) {
              setState(() {
                waterLevel = double.tryParse(value.toString()) ?? 0.0;
                if (waterLevel <= 20) {
                  notifications.add(
                    'Low water level alert: $lakeName - ${waterLevel.toStringAsFixed(2)}%',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Warning: Water level at ${waterLevel.toStringAsFixed(2)}%!',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            }
          },
          onError: (error) {
            print('Error fetching water level: $error');
          },
        );
  }

  void fetchControlPanelData() {
    if (deviceId == null) {
      print('Error: deviceId is null');
      return;
    }
    databaseRef
        .child('${deviceId}_control')
        .onValue
        .listen(
          (event) {
            final data = event.snapshot.value;
            if (data is Map && mounted) {
              setState(() {
                isWaterOn = data['valveStatus'] ?? false;
                selectedMode = data['controlMode'] ?? 'basic';
                targetTime = data['targetTime'] ?? 0;
                targetHours = targetTime ~/ 3600;
                targetMinutes = (targetTime % 3600) ~/ 60;
                targetVolume = data['targetVolume'] ?? 0;
              });
            }
          },
          onError: (error) {
            print('Error fetching control panel data: $error');
          },
        );
  }

  void fetchLiveStats() {
    if (deviceId == null) {
      print('Error: deviceId is null');
      return;
    }
    databaseRef
        .child('$deviceId/liveTargetVolume')
        .onValue
        .listen(
          (event) {
            final val = event.snapshot.value;
            if (val != null && mounted) {
              setState(() {
                liveVolume = int.tryParse(val.toString()) ?? 0;
              });
            }
          },
          onError: (error) {
            print('Error fetching liveTargetVolume: $error');
          },
        );

    databaseRef
        .child('$deviceId/liveTargetTime')
        .onValue
        .listen(
          (event) {
            final val = event.snapshot.value;
            if (val != null && mounted) {
              setState(() {
                liveTargetTime = int.tryParse(val.toString()) ?? 0;
              });
            }
          },
          onError: (error) {
            print('Error fetching liveTargetTime: $error');
          },
        );
  }

  void fetchTotalWaterOutput() {
    if (deviceId == null) {
      print('Error: deviceId is null');
      return;
    }
    databaseRef
        .child('${deviceId}_control/totalWaterOutput')
        .onValue
        .listen(
          (event) {
            final val = event.snapshot.value;
            if (val != null && mounted) {
              setState(() {
                totalWaterOutput = int.tryParse(val.toString()) ?? 0;
              });
            }
          },
          onError: (error) {
            print('Error fetching total water output: $error');
          },
        );
  }

  void updateControlPanel(String key, dynamic value) {
    if (deviceId == null) {
      print('Error: deviceId is null');
      return;
    }
    databaseRef.child('${deviceId}_control').update({key: value}).catchError((
      error,
    ) {
      print('Error updating control panel: $error');
    });
  }

  String getFormattedTime(int hours, int minutes) {
    if (hours > 0 && minutes > 0) {
      return '$hours hour${hours > 1 ? "s" : ""} $minutes minute${minutes > 1 ? "s" : ""}';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? "s" : ""}';
    } else if (minutes > 0) {
      return '$minutes minute${minutes > 1 ? "s" : ""}';
    } else {
      return '0 minutes';
    }
  }

  void _pickTime() async {
    final hoursController = TextEditingController(text: targetHours.toString());
    final minutesController = TextEditingController(
      text: targetMinutes.toString(),
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Select Time',
              style: TextStyle(
                color: Color.fromARGB(255, 2, 54, 4),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hoursController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    hintText: '0',
                    labelStyle: TextStyle(
                      color: Color.fromARGB(255, 2, 54, 4),
                      fontSize: 16,
                    ),
                  ),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 2, 54, 4),
                    fontSize: 16,
                  ),
                ),
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    hintText: '0',
                    labelStyle: TextStyle(
                      color: Color.fromARGB(255, 2, 54, 4),
                      fontSize: 16,
                    ),
                  ),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 2, 54, 4),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color.fromARGB(255, 2, 54, 4)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Color.fromARGB(255, 2, 54, 4)),
                ),
              ),
            ],
          ),
    );

    if (shouldSave != true) return;

    int hours = int.tryParse(hoursController.text) ?? 0;
    int minutes = int.tryParse(minutesController.text) ?? 0;
    if (mounted) {
      setState(() {
        targetHours = hours;
        targetMinutes = minutes;
        targetTime = hours * 3600 + minutes * 60;
      });
      updateControlPanel('targetTime', targetTime);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: Color.fromARGB(255, 2, 54, 4),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(
                color: Color.fromARGB(255, 2, 54, 4),
                fontSize: 16,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color.fromARGB(255, 2, 54, 4),
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ],
          ),
    );

    if (shouldLogout != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(),
      drawer: buildDrawer(),
      body: Stack(
        children: [
          buildBackground(),
          Container(color: Colors.black.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                buildGreeting(),
                const SizedBox(height: 20),
                buildInfoCard(Icons.water, 'වැව් නම', lakeName),
                buildInfoCard(Icons.grass, 'වගා භූමි ප්‍රමාණය', landSize),
                buildInfoCard(Icons.spa, 'බෝග වර්ගය', crop),
                buildWaterLevelCard(),
                buildControlPanelCard(),
                buildLiveStatCard(
                  'මුළු පිටවූ ජල ප්‍රමාණය (L)',
                  liveVolume.toString(),
                ),
                buildLiveStatCard(
                  'වතුර සැපයුම් කාලය',
                  getFormattedTime(
                    liveTargetTime ~/ 3600,
                    liveTargetTime % 3600 ~/ 60,
                  ),
                ),
                buildTotalWaterOutputCard(),
              ],
            ),
          ),
          if (showNotificationPanel) buildNotificationPanel(),
        ],
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      title: const Text(
        'ECO H2O',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 2, 54, 4),
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 244, 255, 249),
      elevation: 4,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications,
                color: Color.fromARGB(255, 2, 54, 4),
                size: 28,
              ),
              onPressed: () {
                setState(() {
                  showNotificationPanel = !showNotificationPanel;
                });
              },
            ),
            if (notifications.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    '${notifications.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget buildNotificationPanel() {
    return Positioned(
      top: 0,
      right: 10,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          height: 600,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 2, 54, 4),
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          notifications.clear();
                        });
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color.fromARGB(255, 2, 54, 4),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child:
                    notifications.isEmpty
                        ? const Center(
                          child: Text(
                            'No notifications',
                            style: TextStyle(
                              color: Color.fromARGB(255, 2, 54, 4),
                              fontSize: 16,
                            ),
                          ),
                        )
                        : ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                notifications[index],
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 141, 108, 1),
                                  fontSize: 15,
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Drawer buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              userName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 48,
                color: Color.fromARGB(255, 2, 54, 4),
              ),
            ),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 2, 54, 4),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.person,
              color: Color.fromARGB(255, 2, 54, 4),
              size: 28,
            ),
            title: const Text(
              'User Details',
              style: TextStyle(
                color: Color.fromARGB(255, 2, 54, 4),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            subtitle: const Text(
              'View your profile information',
              style: TextStyle(
                color: Color.fromARGB(255, 126, 126, 126),
                fontSize: 14,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DetailsScreen(userData: {}),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Color.fromARGB(255, 2, 54, 4),
              size: 28,
            ),
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: Color.fromARGB(255, 2, 54, 4),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            subtitle: const Text(
              'Sign out of your account',
              style: TextStyle(
                color: Color.fromARGB(255, 126, 126, 126),
                fontSize: 14,
              ),
            ),
            onTap: _logout,
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'ECO H2O v1.0',
              style: TextStyle(
                color: Color.fromARGB(255, 2, 2, 2),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBackground() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/confirmation.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.2),
            BlendMode.darken,
          ),
        ),
      ),
    );
  }

  Widget buildGreeting() {
    return Text(
      'ආයුබෝවන්, $userName',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget buildInfoCard(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Card(
        elevation: 8,
        color: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          leading: Icon(
            icon,
            color: const Color.fromARGB(255, 2, 54, 4),
            size: 25,
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Color.fromARGB(255, 2, 54, 4),
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 2, 54, 4),
              fontSize: 16.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildWaterLevelCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        color: const Color.fromARGB(255, 255, 255, 255).withOpacity(1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'වැව් ජල මට්ටම',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 2, 54, 4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'වත්මන් ජල මට්ටම: ${waterLevel.toStringAsFixed(2)} %',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color:
                      waterLevel <= 20
                          ? Colors.red
                          : const Color.fromARGB(255, 0, 16, 109),
                ),
              ),
              const SizedBox(height: 15),
              LinearProgressIndicator(
                value: waterLevel / 100,
                color:
                    waterLevel <= 20
                        ? Colors.red
                        : const Color.fromARGB(255, 0, 16, 109),
                backgroundColor: const Color.fromARGB(255, 189, 230, 255),
                minHeight: 30,
                borderRadius: BorderRadius.circular(15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildControlPanelCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        color: const Color.fromARGB(255, 255, 255, 255).withOpacity(1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ජල පාලන පුවරුව',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 2, 54, 4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ජල සැපයුම',
                    style: TextStyle(
                      color: Color.fromARGB(255, 2, 54, 4),
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
                    ),
                  ),
                  Switch(
                    value: isWaterOn,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          isWaterOn = value;
                        });
                        updateControlPanel('valveStatus', value);
                      }
                    },
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'පාලන ආකාරය',
                    style: TextStyle(
                      color: Color.fromARGB(255, 2, 54, 4),
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
                    ),
                  ),
                  DropdownButton<String>(
                    value: selectedMode,
                    dropdownColor: Colors.white,
                    items:
                        ['basic', 'time', 'volume'].map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(
                              mode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 2, 58, 55),
                                fontSize: 17,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null && mounted) {
                        setState(() {
                          selectedMode = value;
                        });
                        updateControlPanel('controlMode', value);
                      }
                    },
                  ),
                ],
              ),
              if (selectedMode == 'time') ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'වතුර සැපයුම් කාලය',
                      style: TextStyle(
                        color: Color.fromARGB(255, 2, 54, 4),
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    TextButton(
                      onPressed: _pickTime,
                      child: Text(
                        getFormattedTime(targetHours, targetMinutes),
                        style: const TextStyle(
                          color: Color.fromARGB(255, 192, 0, 0),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (selectedMode == 'volume') ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'වතුර ප්‍රමාණය (L)',
                      style: TextStyle(
                        color: Color.fromARGB(255, 2, 54, 4),
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    SizedBox(
                      width: 125,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onSubmitted: (value) {
                          int vol = int.tryParse(value) ?? 0;
                          if (mounted) {
                            setState(() {
                              targetVolume = vol;
                            });
                            updateControlPanel('targetVolume', vol);
                          }
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '0L',
                          hintStyle: TextStyle(
                            color: Color.fromARGB(255, 192, 0, 0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 202, 202, 202),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 0, 38, 255),
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 12,
                          ),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 38, 255),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLiveStatCard(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        color: Colors.white.withOpacity(1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 2, 54, 4),
              fontSize: 16,
            ),
          ),
          trailing: Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 38, 255),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTotalWaterOutputCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Card(
        color: Colors.white.withOpacity(1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'වගාව සඳහා මුළු ජල පිටකිරීම (L)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 2, 54, 4),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GraphScreen(deviceId: deviceId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 2, 54, 4),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'පිවිසෙන්න',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GraphScreen extends StatefulWidget {
  final String? deviceId;

  const GraphScreen({super.key, this.deviceId});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  String selectedPeriod = '5 Minutes';
  final List<String> periods = ['5 Minutes', '10 Minutes', '20 Minutes'];
  List<FlSpot> waterData = [];
  bool isLoading = true;
  DateTime? referenceDateTime;

  @override
  void initState() {
    super.initState();
    fetchReferenceTimeAndWaterData();
  }

  Future<void> fetchReferenceTimeAndWaterData() async {
    if (widget.deviceId == null) {
      print('Error: deviceId is null');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Fetch currentDate and currentTime from wak_sys_1
      final snapshot =
          await FirebaseDatabase.instance.ref().child(widget.deviceId!).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final currentDate = data['currentDate'] as String? ?? '2025-07-05';
        final currentTime = data['currentTime'] as String? ?? '08:32:56';
        try {
          referenceDateTime = DateTime.parse('$currentDate $currentTime');
        } catch (e) {
          print('Error parsing date/time: $e');
          referenceDateTime = DateTime(2025, 7, 5, 8, 32, 56); // Fallback
        }
      } else {
        print('No data found for ${widget.deviceId}');
        referenceDateTime = DateTime(2025, 7, 5, 8, 32, 56); // Fallback
      }

      await fetchWaterData();
    } catch (e) {
      print('Error fetching reference time: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchWaterData() async {
    if (widget.deviceId == null || referenceDateTime == null) {
      print('Error: deviceId or referenceDateTime is null');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final timeRangeSeconds = getTimeRangeSeconds();
      final referenceTimestamp =
          referenceDateTime!.millisecondsSinceEpoch ~/ 1000;
      final cutoffTime = referenceTimestamp - timeRangeSeconds;
      final endTime = referenceTimestamp;

      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('${widget.deviceId}/history/liveTargetVolume')
              .orderByChild('timestamp')
              .startAt(cutoffTime)
              .endAt(endTime)
              .get();

      List<FlSpot> spots = [];
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<MapEntry<dynamic, dynamic>> sortedEntries =
            data.entries.toList()..sort(
              (a, b) => (a.value['timestamp'] as int).compareTo(
                b.value['timestamp'] as int,
              ),
            );

        for (var entry in sortedEntries) {
          final timestamp = entry.value['timestamp'] as int;
          final volume =
              double.tryParse(entry.value['value'].toString()) ?? 0.0;
          // Calculate minutes since start of time range
          final secondsSinceStart = timestamp - cutoffTime;
          final minutesSinceStart = (secondsSinceStart / 60).clamp(
            0,
            timeRangeSeconds / 60,
          );
          spots.add(FlSpot(minutesSinceStart.toDouble(), volume));
        }
      } else {
        // Fallback: Generate empty data points
        final minutes = timeRangeSeconds ~/ 60;
        spots = List.generate(
          minutes + 1,
          (index) => FlSpot(index.toDouble(), 0.0),
        );
      }

      if (mounted) {
        setState(() {
          waterData = spots;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching water data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  int getTimeRangeSeconds() {
    return switch (selectedPeriod) {
      '5 Minutes' => 300,
      '10 Minutes' => 600,
      '20 Minutes' => 1200,
      _ => 300,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Water Output Graph',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 2, 54, 4),
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 220, 239, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: selectedPeriod,
              items:
                  periods
                      .map(
                        (period) => DropdownMenuItem(
                          value: period,
                          child: Text(
                            period,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 2, 54, 4),
                              fontSize: 18,
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() {
                    selectedPeriod = value;
                    isLoading = true;
                  });
                  fetchReferenceTimeAndWaterData();
                }
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : referenceDateTime == null
                      ? const Center(
                        child: Text('Error loading reference time'),
                      )
                      : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text(
                                'ජල ප්‍රමාණය (L)',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 2, 54, 4),
                                  fontSize: 14,
                                ),
                              ),
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (value, meta) => Text(
                                      '${value.toInt()}',
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 2, 54, 4),
                                        fontSize: 14,
                                      ),
                                    ),
                                reservedSize: 40,
                                interval:
                                    waterData.isNotEmpty
                                        ? (waterData
                                                    .map((spot) => spot.y)
                                                    .reduce(
                                                      (a, b) => a > b ? a : b,
                                                    ) *
                                                1.1 /
                                                5)
                                            .roundToDouble()
                                            .clamp(1, double.infinity)
                                        : 1,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text(
                                'කාලය',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 2, 54, 4),
                                  fontSize: 14,
                                ),
                              ),
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final minutes = value.toInt();
                                  final time = referenceDateTime!.subtract(
                                    Duration(
                                      minutes:
                                          (getTimeRangeSeconds() ~/ 60) -
                                          minutes,
                                    ),
                                  );
                                  return Text(
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Color.fromARGB(255, 2, 54, 4),
                                      fontSize: 14,
                                    ),
                                  );
                                },
                                interval: getTimeRangeSeconds() / 60 / 4,
                                reservedSize: 30,
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          minX: 0,
                          maxX: getTimeRangeSeconds() / 60,
                          minY: 0,
                          maxY:
                              waterData.isNotEmpty
                                  ? waterData
                                          .map((spot) => spot.y)
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.1
                                  : 1.0,
                          lineBarsData: [
                            LineChartBarData(
                              spots: waterData,
                              isCurved: true,
                              color: const Color.fromARGB(255, 0, 34, 109),
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color.fromARGB(
                                  255,
                                  0,
                                  34,
                                  109,
                                ).withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
