import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';

class Principal extends StatefulWidget {
  const Principal({Key? key}) : super(key: key);

  @override
  PrincipalState createState() => PrincipalState();
}

class PrincipalState extends State<Principal> {
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  bool bluetoothState = false;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? selectedDevice;
  BluetoothConnection? connection;
  final TextEditingController messageController = TextEditingController();
  bool isConnecting = false;
  bool isConnected = false;
  String latitud = "N/A";
  String longitud = "N/A";
  String voltaje = "N/A";

  List recipes = [];

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  void dispose() {
    if (isConnected) {
      disconnect();
    }
    super.dispose();
  }

  // Solicitar permisos necesarios
  Future<void> requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();
  }

  // Verificar el estado del Bluetooth
  Future<void> checkBluetoothState() async {
    try {
      bluetoothState = await bluetooth.isEnabled ?? false;
      setState(() {});

      // Si el Bluetooth está encendido, buscar dispositivos
      if (bluetoothState) {
        getBondedDevices();
      }

      // Escuchar cambios en el estado del Bluetooth
      bluetooth.onStateChanged().listen((state) {
        setState(() {
          bluetoothState = state.isEnabled;
        });

        // Si el Bluetooth se activa, buscar dispositivos
        if (bluetoothState) {
          getBondedDevices();
        }
      });
    } catch (e) {
      print("Error al verificar el estado del Bluetooth: $e");
    }
  }

  // Obtener dispositivos emparejados
  void getBondedDevices() async {
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        devicesList = devices;
      });
    } catch (e) {
      print("Error al obtener dispositivos: $e");
    }
  }

  // Conectar al dispositivo seleccionado
  void connect(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
      selectedDevice = device;
    });

    try {
      connection = await BluetoothConnection.toAddress(device.address);

      setState(() {
        isConnecting = false;
        isConnected = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Conectado a ${device.name}')));
    } catch (e) {
      setState(() {
        isConnecting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al conectar: $e')));
    }
  }

  // Desconectar
  void disconnect() {
    setState(() {
      isConnected = false;
      connection?.dispose();
      connection = null;
    });
  }

  // Enviar comando al ESP32
  void sendCommand(String command) {
    if (connection != null && isConnected) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(command)));
      } catch (e) {
        print("Error al enviar comando: $e");
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No hay conexión activa')));
    }
  }

  Future<void> getData() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.32:4499/recipes'),
    );
    if (response.statusCode == 200) {
      setState(() {
        recipes = jsonDecode(response.body);
        debugPrint("Recipes: $recipes");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PharmaGo"),
        actions: [
          Switch(
            value: bluetoothState,
            onChanged: (bool value) async {
              if (value) {
                await bluetooth.requestEnable();
              } else {
                await bluetooth.requestDisable();
              }
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app),
          onPressed: () {
            if (Platform.isAndroid || Platform.isIOS) {
              SystemNavigator.pop();
            }
            if (Platform.isLinux || Platform.isWindows) {
              exit(0);
            }
          },
        ),
      ),
      body: isConnected ? controlPanel() : deviceList(),
    );
  }

  Widget deviceList() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: devicesList.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(Icons.bluetooth),
                title: Text(
                  devicesList[index].name ?? "Dispositivo desconocido",
                ),
                subtitle: Text(devicesList[index].address),
                trailing:
                    isConnecting && selectedDevice == devicesList[index]
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                          child: Text('Conectar'),
                          onPressed: () => connect(devicesList[index]),
                        ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: ElevatedButton(
            child: Text('Actualizar dispositivos'),
            onPressed: getBondedDevices,
          ),
        ),
      ],
    );
  }

  // Interfaz para el panel de control
  Widget controlPanel() {
    return Column(
      children: [
        AppBar(
          title: Text('Conectado a: ${selectedDevice?.name}'),
          automaticallyImplyLeading: false,
          actions: [IconButton(icon: Icon(Icons.close), onPressed: disconnect)],
        ),

        // Panel de información
        Card(
          margin: EdgeInsets.all(16.0),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información del dispositivo:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Latitud: $latitud'),
                Text('Longitud: $longitud'),
                Text('Voltaje: $voltaje V'),
              ],
            ),
          ),
        ),

        // Botones de control
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text('Iniciar'),
                onPressed: () => sendCommand('m'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text('Registrar huella'),
                onPressed: () => sendCommand('e'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
