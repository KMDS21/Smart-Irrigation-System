import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  final database = FirebaseDatabase.instance.ref('dam_sys');
  final controlDatabase = FirebaseDatabase.instance.ref('dam_sys_control');
  final lakesCollection = FirebaseFirestore.instance.collection('lakes');

  String? lakeID;
  String lakeName = 'Kalu Lake';
  double lakeSize = 1000.0;
  String lakeSizeAcres = '0.247 acres';

  double humidity = 0.0;
  double temperature = 0.0;
  double waterLevel = 0.0;
  bool isWaterSupplyOn = false;
  double outWaterQuantity = 0.0;
  double flowRate = 0.0;

  bool isLoading = true;

  List<Map<String, dynamic>> humidityHistory = [];
  List<Map<String, dynamic>> waterLevelHistory = [];
  List<Map<String, dynamic>> outWaterQuantityHistory = [];
  List<Map<String, dynamic>> temperatureHistory = [];

  Timer? dataFetchTimer;

  String humidityTimeRange = '5min';
  String waterLevelTimeRange = '5min';
  String temperatureTimeRange = '5min';
  String waterQuantityTimeRange = '5min';

  bool showHumidityGraph = false;
  bool showWaterLevelGraph = false;
  bool showTemperatureGraph = false;
  bool showWaterQuantityGraph = false;

  final TextEditingController lakeIDController = TextEditingController();
  final TextEditingController lakeNameController = TextEditingController();
  final TextEditingController lakeSizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFirebaseData();
    _fetchValveState();
    _startRealtimeUpdates();
    _fetchLakeData();
  }

  @override
  void dispose() {
    dataFetchTimer?.cancel();
    lakeIDController.dispose();
    lakeNameController.dispose();
    lakeSizeController.dispose();
    super.dispose();
  }

  void _startRealtimeUpdates() {
    dataFetchTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchFirebaseData();
      _fetchValveState();
    });
  }

  Future<void> _fetchLakeData() async {
    final snapshot = await lakesCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty && mounted) {
      final lakeData = snapshot.docs.first.data();
      final sizeInM2 =
          (lakeData['lakeSize'] is String
              ? double.tryParse(lakeData['lakeSize'].replaceAll(' m²', '')) ??
                  1000.0
              : (lakeData['lakeSize'] as num?)?.toDouble() ?? 1000.0);
      final sizeInAcres = sizeInM2 * 0.000247105;
      setState(() {
        lakeID = lakeData['lakeID'];
        lakeName = lakeData['lakeName'];
        lakeSize = sizeInM2;
        lakeSizeAcres = '${sizeInAcres.toStringAsFixed(3)} acres';
      });
    }
  }

  Future<void> _addLake() async {
    final newLakeID = lakeIDController.text.trim();
    final newLakeName = lakeNameController.text.trim();
    final newLakeSize = lakeSizeController.text.trim();

    if (newLakeID.isEmpty || newLakeName.isEmpty || newLakeSize.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please fill in all fields'),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    try {
      final sizeInM2 = double.tryParse(newLakeSize) ?? 1000.0;
      final sizeInAcres = sizeInM2 * 0.000247105;
      await lakesCollection.doc(newLakeID).set({
        'lakeID': newLakeID,
        'lakeName': newLakeName,
        'lakeSize': sizeInM2,
      });
      if (mounted) {
        setState(() {
          lakeID = newLakeID;
          lakeName = newLakeName;
          lakeSize = sizeInM2;
          lakeSizeAcres = '${sizeInAcres.toStringAsFixed(3)} acres';
        });
        lakeIDController.clear();
        lakeNameController.clear();
        lakeSizeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lake added successfully'),
            backgroundColor: const Color.fromARGB(255, 14, 52, 43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding lake: $e'),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchFirebaseData() async {
    try {
      final snapshot = await database.get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final dateStr = data['date'] as String;
        final timeStr = data['time'] as String;
        final dateTime = DateTime.parse('$dateStr $timeStr');

        setState(() {
          humidity = (data['humidity'] ?? 0).toDouble();
          temperature = (data['temp'] ?? 0).toDouble();
          waterLevel = (data['waterLevel'] ?? 0).toDouble();
          outWaterQuantity = (data['totalLitres'] ?? 0).toDouble();
          flowRate = (data['flowRate'] ?? 0).toDouble();

          humidityHistory.add({'time': dateTime, 'value': humidity});
          waterLevelHistory.add({'time': dateTime, 'value': waterLevel});
          outWaterQuantityHistory.add({
            'time': dateTime,
            'value': outWaterQuantity,
          });
          temperatureHistory.add({'time': dateTime, 'value': temperature});

          humidityHistory = _filterHistory(humidityHistory, humidityTimeRange);
          waterLevelHistory = _filterHistory(
            waterLevelHistory,
            waterLevelTimeRange,
          );
          outWaterQuantityHistory = _filterHistory(
            outWaterQuantityHistory,
            waterQuantityTimeRange,
          );
          temperatureHistory = _filterHistory(
            temperatureHistory,
            temperatureTimeRange,
          );

          isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No data available for dam_sys'),
              backgroundColor: const Color(0xFFEF5350),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission-denied')
                  ? 'Permission denied to access dam_sys'
                  : 'Error fetching data: $e',
            ),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchValveState() async {
    try {
      final snapshot = await controlDatabase.child('valveState').get();
      if (snapshot.exists && mounted) {
        setState(() {
          isWaterSupplyOn = snapshot.value as bool;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission-denied')
                  ? 'Permission denied to access dam_sys_control'
                  : 'Error fetching valve state: $e',
            ),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterHistory(
    List<Map<String, dynamic>> history,
    String range,
  ) {
    final now = DateTime.now();
    var filtered = switch (range) {
      '5min' =>
        history
            .where((point) => now.difference(point['time']).inMinutes <= 5)
            .toList(),
      '10min' =>
        history
            .where((point) => now.difference(point['time']).inMinutes <= 10)
            .toList(),
      '20min' =>
        history
            .where((point) => now.difference(point['time']).inMinutes <= 20)
            .toList(),
      _ => history,
    };
    filtered.sort(
      (a, b) => a['time'].compareTo(b['time']),
    ); // Sort oldest to newest
    return filtered;
  }

  Future<void> _saveValveState(bool value) async {
    try {
      await controlDatabase.update({'valveState': value});
      if (mounted) {
        setState(() {
          isWaterSupplyOn = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Valve state updated successfully'),
            backgroundColor: const Color.fromARGB(255, 6, 44, 127),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isWaterSupplyOn = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission-denied')
                  ? 'Permission denied to update valve state'
                  : 'Error updating valve state: $e',
            ),
            backgroundColor: const Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  List<FlSpot> getHumiditySpots() {
    final now = DateTime.now();
    final history = _filterHistory(humidityHistory, humidityTimeRange);
    return history.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final minutesAgo = now.difference(point['time']).inSeconds / 60.0;
      return FlSpot(_getMaxX(humidityTimeRange) - minutesAgo, point['value']);
    }).toList();
  }

  List<FlSpot> getWaterLevelSpots() {
    final now = DateTime.now();
    final history = _filterHistory(waterLevelHistory, waterLevelTimeRange);
    return history.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final minutesAgo = now.difference(point['time']).inSeconds / 60.0;
      return FlSpot(_getMaxX(waterLevelTimeRange) - minutesAgo, point['value']);
    }).toList();
  }

  List<FlSpot> getOutWaterQuantitySpots() {
    final now = DateTime.now();
    final history = _filterHistory(
      outWaterQuantityHistory,
      waterQuantityTimeRange,
    );
    return history.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final minutesAgo = now.difference(point['time']).inSeconds / 60.0;
      return FlSpot(
        _getMaxX(waterQuantityTimeRange) - minutesAgo,
        point['value'],
      );
    }).toList();
  }

  List<FlSpot> getTemperatureSpots() {
    final now = DateTime.now();
    final history = _filterHistory(temperatureHistory, temperatureTimeRange);
    return history.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final minutesAgo = now.difference(point['time']).inSeconds / 60.0;
      return FlSpot(
        _getMaxX(temperatureTimeRange) - minutesAgo,
        point['value'],
      );
    }).toList();
  }

  double _getMaxX(String range) {
    return switch (range) {
      '5min' => 5.0,
      '10min' => 10.0,
      '20min' => 20.0,
      _ => 5.0,
    };
  }

  double _getInterval(String range) {
    return switch (range) {
      '5min' => 1.0,
      '10min' => 2.0,
      '20min' => 4.0,
      _ => 1.0,
    };
  }

  Future<void> _showAddLakeDialog() async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white.withOpacity(0.95),
            contentPadding: const EdgeInsets.all(24),
            title: const Center(
              child: Text(
                'Add New Lake',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 4, 32, 94),
                ),
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: lakeIDController,
                    decoration: InputDecoration(
                      labelText: 'Lake ID',
                      labelStyle: const TextStyle(
                        color: Color.fromARGB(255, 4, 32, 94),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 4, 32, 94),
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: lakeNameController,
                    decoration: InputDecoration(
                      labelText: 'Lake Name',
                      labelStyle: const TextStyle(
                        color: Color.fromARGB(255, 4, 32, 94),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 4, 32, 94),
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lakeSizeController,
                    decoration: InputDecoration(
                      labelText: 'Lake Size (m²)',
                      labelStyle: const TextStyle(
                        color: Color.fromARGB(255, 4, 32, 94),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color.fromARGB(255, 4, 32, 94),
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.black87),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color.fromARGB(255, 4, 32, 94),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _addLake,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 4, 32, 94),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add Lake',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 14, 52, 43),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Control Panel',
          style: TextStyle(
            color: Color.fromARGB(255, 14, 52, 43),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color.fromARGB(255, 14, 52, 43),
          ),
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, color: Color.fromARGB(255, 14, 52, 43)),
            onSelected: (value) {
              if (value == 'add_lake') {
                _showAddLakeDialog();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'add_lake',
                    child: Text(
                      'Add New Lake',
                      style: TextStyle(color: Color.fromARGB(255, 5, 56, 168)),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/confirmation.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.39)),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: ListView(
              children: [
                buildReadOnlyCard('Lake Name', lakeName),
                buildReadOnlyCard(
                  'Lake Size',
                  '${lakeSize.toStringAsFixed(0)} m² ($lakeSizeAcres)',
                ),
                Card(
                  color: Colors.white.withOpacity(0.9),
                  elevation: 8,
                  margin: const EdgeInsets.only(bottom: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Water Level',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 3, 1, 65),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${waterLevel.toStringAsFixed(2)} %',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 12, 53, 177),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                IconButton(
                                  icon: Icon(
                                    showWaterLevelGraph
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color: const Color.fromARGB(255, 4, 1, 82),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      showWaterLevelGraph =
                                          !showWaterLevelGraph;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: waterLevel / 100,
                          color: const Color.fromARGB(255, 16, 4, 128),
                          backgroundColor: const Color.fromARGB(
                            179,
                            193,
                            246,
                            255,
                          ),
                          minHeight: 28,
                        ),
                        if (showWaterLevelGraph) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<String>(
                                value: waterLevelTimeRange,
                                dropdownColor: Colors.white.withOpacity(1),
                                items: const [
                                  DropdownMenuItem(
                                    value: '5min',
                                    child: Text(
                                      '5 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 4, 1, 82),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '10min',
                                    child: Text(
                                      '10 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 4, 1, 82),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '20min',
                                    child: Text(
                                      '20 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 4, 1, 82),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      waterLevelTimeRange = value;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 300,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: _getMaxX(waterLevelTimeRange),
                                minY: 0,
                                maxY: 100,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: _getInterval(
                                        waterLevelTimeRange,
                                      ),
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()} m',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color.fromARGB(
                                                255,
                                                4,
                                                1,
                                                82,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 20,
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color.fromARGB(
                                                255,
                                                4,
                                                1,
                                                82,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 4, 1, 82),
                                  ),
                                ),
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  drawHorizontalLine: true,
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    spots: getWaterLevelSpots(),
                                    barWidth: 4,
                                    color: const Color.fromARGB(
                                      255,
                                      3,
                                      17,
                                      107,
                                    ),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Card(
                  color: Colors.white.withOpacity(0.9),
                  elevation: 8,
                  margin: const EdgeInsets.only(bottom: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 1,
                          ),
                          title: const Text(
                            'Water Supply (ON/OFF)',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 14, 52, 43),
                            ),
                          ),
                          value: isWaterSupplyOn,
                          onChanged: (value) {
                            _saveValveState(value);
                          },
                          activeColor: const Color.fromARGB(255, 2, 122, 4),
                          inactiveThumbColor: const Color(0xFFEF5350),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  color: Colors.white.withOpacity(0.9),
                  elevation: 8,
                  margin: const EdgeInsets.only(bottom: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Humidity',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 14, 52, 43),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${humidity.toStringAsFixed(2)} %',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 5, 56, 168),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                IconButton(
                                  icon: Icon(
                                    showHumidityGraph
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color: const Color.fromARGB(
                                      255,
                                      14,
                                      52,
                                      43,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      showHumidityGraph = !showHumidityGraph;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (showHumidityGraph) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<String>(
                                value: humidityTimeRange,
                                dropdownColor: Colors.white.withOpacity(1),
                                items: const [
                                  DropdownMenuItem(
                                    value: '5min',
                                    child: Text(
                                      '5 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '10min',
                                    child: Text(
                                      '10 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '20min',
                                    child: Text(
                                      '20 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      humidityTimeRange = value;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 300,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: _getMaxX(humidityTimeRange),
                                minY: 0,
                                maxY: 100,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: _getInterval(humidityTimeRange),
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()} m',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1A3C34),
                                            ),
                                          ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 20,
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1A3C34),
                                            ),
                                          ),
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: const Color(0xFF1A3C34),
                                  ),
                                ),
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  drawHorizontalLine: true,
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    spots: getHumiditySpots(),
                                    barWidth: 4,
                                    color: const Color(0xFFD0E44E),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Card(
                  color: Colors.white.withOpacity(0.9),
                  elevation: 8,
                  margin: const EdgeInsets.only(bottom: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Temperature',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 14, 52, 43),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${temperature.toStringAsFixed(2)} °C',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 5, 56, 168),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                IconButton(
                                  icon: Icon(
                                    showTemperatureGraph
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color: const Color.fromARGB(
                                      255,
                                      14,
                                      52,
                                      43,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      showTemperatureGraph =
                                          !showTemperatureGraph;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (showTemperatureGraph) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<String>(
                                value: temperatureTimeRange,
                                dropdownColor: Colors.white.withOpacity(1),
                                items: const [
                                  DropdownMenuItem(
                                    value: '5min',
                                    child: Text(
                                      '5 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '10min',
                                    child: Text(
                                      '10 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '20min',
                                    child: Text(
                                      '20 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      temperatureTimeRange = value;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 300,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: _getMaxX(temperatureTimeRange),
                                minY: 0,
                                maxY:
                                    temperatureHistory.isNotEmpty
                                        ? temperatureHistory
                                                .map(
                                                  (p) => p['value'] as double,
                                                )
                                                .reduce(
                                                  (a, b) => a > b ? a : b,
                                                ) *
                                            1.1
                                        : 100,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: _getInterval(
                                        temperatureTimeRange,
                                      ),
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()} m',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1A3C34),
                                            ),
                                          ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval:
                                          temperatureHistory.isNotEmpty
                                              ? (temperatureHistory
                                                          .map(
                                                            (p) =>
                                                                p['value']
                                                                    as double,
                                                          )
                                                          .reduce(
                                                            (a, b) =>
                                                                a > b ? a : b,
                                                          ) *
                                                      1.1 /
                                                      5)
                                                  .roundToDouble()
                                                  .clamp(1, double.infinity)
                                              : 20,
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()}°C',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1A3C34),
                                            ),
                                          ),
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: const Color(0xFF1A3C34),
                                  ),
                                ),
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  drawHorizontalLine: true,
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    spots: getTemperatureSpots(),
                                    barWidth: 4,
                                    color: const Color(0xFFFF6347),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Card(
                  color: Colors.white.withOpacity(0.9),
                  elevation: 8,
                  margin: const EdgeInsets.only(bottom: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Out Water Quantity',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 14, 52, 43),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${outWaterQuantity.toStringAsFixed(2)} L',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 5, 56, 168),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: Icon(
                                    showWaterQuantityGraph
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color: const Color.fromARGB(
                                      255,
                                      14,
                                      52,
                                      43,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      showWaterQuantityGraph =
                                          !showWaterQuantityGraph;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (showWaterQuantityGraph) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<String>(
                                value: waterQuantityTimeRange,
                                dropdownColor: Colors.white.withOpacity(1),
                                items: const [
                                  DropdownMenuItem(
                                    value: '5min',
                                    child: Text(
                                      '5 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '10min',
                                    child: Text(
                                      '10 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '20min',
                                    child: Text(
                                      '20 min',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 14, 52, 43),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      waterQuantityTimeRange = value;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 300,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: _getMaxX(waterQuantityTimeRange),
                                minY: 0,
                                maxY:
                                    outWaterQuantityHistory.isNotEmpty
                                        ? outWaterQuantityHistory
                                                .map(
                                                  (p) => p['value'] as double,
                                                )
                                                .reduce(
                                                  (a, b) => a > b ? a : b,
                                                ) *
                                            1.1
                                        : 100,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: _getInterval(
                                        waterQuantityTimeRange,
                                      ),
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()} m',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1A3C34),
                                            ),
                                          ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval:
                                          outWaterQuantityHistory.isNotEmpty
                                              ? (outWaterQuantityHistory
                                                          .map(
                                                            (p) =>
                                                                p['value']
                                                                    as double,
                                                          )
                                                          .reduce(
                                                            (a, b) =>
                                                                a > b ? a : b,
                                                          ) *
                                                      1.1 /
                                                      5)
                                                  .roundToDouble()
                                                  .clamp(1, double.infinity)
                                              : 20,
                                      getTitlesWidget:
                                          (value, _) => Text(
                                            '${value.toInt()}L',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF1A3C34),
                                            ),
                                          ),
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: const Color(0xFF1A3C34),
                                  ),
                                ),
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  drawHorizontalLine: true,
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    spots: getOutWaterQuantitySpots(),
                                    barWidth: 4,
                                    color: const Color(0xFFFFA500),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                buildReadOnlyCard(
                  'Water Supply Speed',
                  '${flowRate.toStringAsFixed(2)} L/min',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReadOnlyCard(String label, String value) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(255, 14, 52, 43),
          ),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(255, 5, 56, 168),
          ),
        ),
      ),
    );
  }
}
