import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Instancia de Bluetooth
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;

  // Estado del Bluetooth
  bool _bluetoothState = false;

  // Lista de dispositivos disponibles
  List<BluetoothDevice> _devicesList = [];

  // Dispositivo conectado
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;

  // Controlador para los mensajes recibidos
  final TextEditingController _messageController = TextEditingController();

  // Estado de conexión
  bool _isConnecting = false;
  bool _isConnected = false;

  // Datos del GPS
  String _latitud = "N/A";
  String _longitud = "N/A";
  String _voltaje = "N/A";

  // Mensajes recibidos
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    // Verificar el estado del Bluetooth al iniciar
    _checkBluetoothState();
    // Solicitar permisos
    _requestPermissions();
  }

  @override
  void dispose() {
    // Cerrar la conexión al salir
    if (_isConnected) {
      _disconnect();
    }
    super.dispose();
  }

  // Solicitar permisos necesarios
  Future<void> _requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();
  }

  // Verificar el estado del Bluetooth
  Future<void> _checkBluetoothState() async {
    try {
      _bluetoothState = await bluetooth.isEnabled ?? false;
      setState(() {});

      // Si el Bluetooth está encendido, buscar dispositivos
      if (_bluetoothState) {
        _getBondedDevices();
      }

      // Escuchar cambios en el estado del Bluetooth
      bluetooth.onStateChanged().listen((state) {
        setState(() {
          _bluetoothState = state.isEnabled;
        });

        // Si el Bluetooth se activa, buscar dispositivos
        if (_bluetoothState) {
          _getBondedDevices();
        }
      });
    } catch (e) {
      print("Error al verificar el estado del Bluetooth: $e");
    }
  }

  // Obtener dispositivos emparejados
  void _getBondedDevices() async {
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        _devicesList = devices;
      });
    } catch (e) {
      print("Error al obtener dispositivos: $e");
    }
  }

  // Conectar al dispositivo seleccionado
  void _connect(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _selectedDevice = device;
    });

    try {
      _connection = await BluetoothConnection.toAddress(device.address);

      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conectado a ${device.name}')),
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar: $e')),
      );
    }
  }

  // Desconectar
  void _disconnect() {
    setState(() {
      _isConnected = false;
      _connection?.dispose();
      _connection = null;
    });
  }

  // Enviar comando al ESP32
  void _sendCommand(String command) {
    if (_connection != null && _isConnected) {
      try {
        _connection!.output.add(Uint8List.fromList(utf8.encode(command)));
        setState(() {
          _messages.add("Enviado: $command");
        });
      } catch (e) {
        print("Error al enviar comando: $e");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay conexión activa')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PharmaGo'),
        actions: [
          Switch(
            value: _bluetoothState,
            onChanged: (bool value) async {
              if (value) {
                await bluetooth.requestEnable();
              } else {
                await bluetooth.requestDisable();
              }
            },
          ),
        ],
      ),
      body: _isConnected ? controlPanel() : deviceList(),
    );
  }

  // Interfaz para la lista de dispositivos
  Widget deviceList() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _devicesList.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(Icons.bluetooth),
                title: Text(_devicesList[index].name ?? "Dispositivo desconocido"),
                subtitle: Text(_devicesList[index].address),
                trailing: _isConnecting && _selectedDevice == _devicesList[index]
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  child: Text('Conectar'),
                  onPressed: () => _connect(_devicesList[index]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: ElevatedButton(
            child: Text('Actualizar dispositivos'),
            onPressed: _getBondedDevices,
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
          title: Text('Conectado a: ${_selectedDevice?.name}'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _disconnect,
            ),
          ],
        ),

        // Panel de información
        Card(
          margin: EdgeInsets.all(16.0),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Información del dispositivo:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Latitud: $_latitud'),
                Text('Longitud: $_longitud'),
                Text('Voltaje: $_voltaje V'),
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
                child: Text('Iniciar (m)'),
                onPressed: () => _sendCommand('m'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text('Detener (s)'),
                onPressed: () => _sendCommand('s'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text('Registrar huella (e)'),
                onPressed: () => _sendCommand('e'),
              ),
            ],
          ),
        ),

        // Mensajes recibidos
        Expanded(
          child: Card(
            margin: EdgeInsets.all(16.0),
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mensajes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(_messages[_messages.length - 1 - index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Enviar mensaje personalizado
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Escribe un comando...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                child: Text('Enviar'),
                onPressed: () {
                  if (_messageController.text.isNotEmpty) {
                    _sendCommand(_messageController.text);
                    _messageController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}