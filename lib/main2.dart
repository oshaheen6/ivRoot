// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MedicationCounterApp());
}

// Medication class to store medication details
class Medication {
  final String name;
  final double price;

  Medication({required this.name, required this.price});

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
      };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        name: json['name'],
        price: json['price'].toDouble(),
      );
}

class _MedicationCounterHomeState extends State<MedicationCounterHome> {
  DateTime selectedDate = DateTime.now();
  Map<String, Map<String, int>> medicationCounts = {};
  Map<String, Medication> medications = {
    'Paracetamol': Medication(name: 'Paracetamol', price: 200),
    'Brufen': Medication(name: 'Brufen', price: 150),
  };
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Get the local storage directory
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get the local storage file
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/medication_data.json');
  }

  // Backup data to file
  Future<void> backupData() async {
    try {
      final file = await _localFile;
      final data = {
        'medications':
            medications.map((key, value) => MapEntry(key, value.toJson())),
        'counts': medicationCounts,
      };
      await file.writeAsString(json.encode(data));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data backed up successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error backing up data: $e')),
      );
    }
  }

  // Restore data from file
  Future<void> restoreData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents);

        setState(() {
          medications = Map.from(data['medications']).map((key, value) =>
              MapEntry(
                  key, Medication.fromJson(value as Map<String, dynamic>)));

          medicationCounts = Map.from(data['counts']).map((key, value) =>
              MapEntry(
                  key as String,
                  (value as Map<String, dynamic>)
                      .map((k, v) => MapEntry(k, v as int))));
        });

        await saveData(); // Save to SharedPreferences
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring data: $e')),
      );
    }
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load medications with prices
    final medicationsJson = prefs.getString('medications_data');
    if (medicationsJson != null) {
      final Map<String, dynamic> medicationsMap = json.decode(medicationsJson);
      setState(() {
        medications = medicationsMap.map((key, value) =>
            MapEntry(key, Medication.fromJson(value as Map<String, dynamic>)));
      });
    }

    // Load counts
    Map<String, Map<String, int>> loadedCounts = {};
    final keys = prefs.getKeys().where((key) => key.startsWith('count_'));
    for (var dateKey in keys) {
      final medMapString = prefs.getString(dateKey);
      if (medMapString != null) {
        try {
          final Map<String, dynamic> jsonMap = json.decode(medMapString);
          loadedCounts[dateKey.replaceFirst('count_', '')] =
              Map<String, int>.from(jsonMap);
        } catch (e) {
          print('Error loading data for $dateKey: $e');
        }
      }
    }
    setState(() {
      medicationCounts = loadedCounts;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save medications with prices
    final medicationsMap =
        medications.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString('medications_data', json.encode(medicationsMap));

    // Save counts
    for (var entry in medicationCounts.entries) {
      try {
        await prefs.setString('count_${entry.key}', json.encode(entry.value));
      } catch (e) {
        print('Error saving data for ${entry.key}: $e');
      }
    }
  }

  void _addNewMedication() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _medicationController,
                decoration:
                    const InputDecoration(hintText: 'Enter medication name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                decoration:
                    const InputDecoration(hintText: 'Enter price in EGP'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_medicationController.text.isNotEmpty &&
                    _priceController.text.isNotEmpty) {
                  setState(() {
                    medications[_medicationController.text] = Medication(
                      name: _medicationController.text,
                      price: double.parse(_priceController.text),
                    );
                    saveData();
                  });
                  _medicationController.clear();
                  _priceController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    Map<String, Map<String, int>> monthlyData = getMonthlyData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Counter'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String choice) async {
              if (choice == 'backup') {
                await backupData();
              } else if (choice == 'restore') {
                await restoreData();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'backup',
                child: Text('Backup Data'),
              ),
              const PopupMenuItem<String>(
                value: 'restore',
                child: Text('Restore Data'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewMedication,
            tooltip: 'Add new medication',
          ),
        ],
      ),
      body: Column(
        children: [
          // ... [Previous date selector code remains the same]

          // Medication Buttons with Prices
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: medications.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: ElevatedButton(
                  onPressed: () => incrementMedication(entry.key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key),
                      Text(
                        '${entry.value.price.toStringAsFixed(0)} EGP',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Today's Counts with Prices
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8.0),
                  ...medications.entries.map((entry) {
                    int count = medicationCounts[dateKey]?[entry.key] ?? 0;
                    double total = count * entry.value.price;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text(
                            '$count x ${entry.value.price.toStringAsFixed(0)} = ${total.toStringAsFixed(0)} EGP',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${calculateDayTotal(dateKey).toStringAsFixed(0)} EGP',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Monthly Summary
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: monthlyData.length,
                itemBuilder: (context, index) {
                  String date = monthlyData.keys.elementAt(index);
                  Map<String, int> dayCounts = monthlyData[date] ?? {};
                  double dayTotal = calculateDayTotal(date);

                  return ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM dd').format(DateTime.parse(date))),
                        Text(
                          '${dayTotal.toStringAsFixed(0)} EGP',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    children: medications.entries.map((entry) {
                      int count = dayCounts[entry.key] ?? 0;
                      double total = count * entry.value.price;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text(
                              '$count x ${entry.value.price.toStringAsFixed(0)} = ${total.toStringAsFixed(0)} EGP',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  double calculateDayTotal(String dateKey) {
    Map<String, int> dayCounts = medicationCounts[dateKey] ?? {};
    double total = 0;
    dayCounts.forEach((med, count) {
      total += (medications[med]?.price ?? 0) * count;
    });
    return total;
  }

  // ... [Previous helper methods remain the same]
}
