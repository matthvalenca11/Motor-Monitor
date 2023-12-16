import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motor Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  bool isConnected = false;
  List<int> dataList = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    await flutterBlue.startScan(timeout: const Duration(seconds: 4));

    flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        print('Found device: ${result.device.name}');
        if (result.device.name == 'MotorMonitor') {
          _connectToDevice(result.device);
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      isConnected = true;
    });
    _startDataStreaming(device);
  }

  void _startDataStreaming(BluetoothDevice device) {
    device.discoverServices().then((services) {
      services.forEach((service) {
        if (service.uuid.toString() == '8fafc201-1fb5-459e-8fcc-c5c9c331914b') {
          service.characteristics.forEach((characteristic) {
            if (characteristic.uuid.toString() == '4eb5483e-36e1-4688-b7f5-ea07361b26a8') {
              characteristic.setNotifyValue(true);
              characteristic.value.listen((value) {
                setState(() {
                  if (dataList.length >= 100) {
                    dataList.removeAt(0); // Remove the oldest data point
                  }
                  // Adjust the scale here if needed
                  // The input signal should be scaled to fit within 0 to 3300mV
                  int scaledValue = (value[0] * 3300 / 255).round().clamp(0, 3300);
                  dataList.add(scaledValue);
                });
              });
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('MotorMonitor'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              isConnected ? 'Bluetooth Connected' : 'Bluetooth Disconnected',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            if (isConnected)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            dataList.length,
                                (index) => FlSpot(index.toDouble(), dataList[index].toDouble()),
                          ),
                          isCurved: true,
                          isStrokeCapRound: true, // Line instead of points
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      minY: 0,
                      maxY: 3300, // Fixed max Y-axis value
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          flutterBlue.stopScan();
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Select ESP32 device'),
                content: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      StreamBuilder<List<ScanResult>>(
                        stream: flutterBlue.scanResults,
                        initialData: const [],
                        builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
                          return Column(
                            children: snapshot.data!.map<Widget>((scanResult) {
                              return ListTile(
                                title: Text(scanResult.device.name),
                                onTap: () {
                                  _connectToDevice(scanResult.device);
                                  Navigator.of(context).pop();
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: const Icon(Icons.bluetooth),
      ),
    );
  }
}
