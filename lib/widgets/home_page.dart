import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List items = [];

  Future<void> fetchItems() async {
    final response = await http.get(Uri.parse('http://192.168.1.32:4499/recipes'));
    if (response.statusCode == 200) {
      setState(() {
        items = json.decode(response.body);
        debugPrint("Nigge: $items");
      });
    }
  }

  Future<void> addItem() async {
    final response = await http.post(
      Uri.parse('http://10.1.125.229:4499/recipes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': 'Nuevo Item',
        'description': 'Descripción del nuevo item',
      }),
    );
    if (response.statusCode == 200) {
      fetchItems(); // Actualizar la lista después de agregar un item
    }
  }

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Items desde MongoDB')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(items[index]['name']),
            subtitle: Text(items[index]['description']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: fetchItems,
        child: Icon(Icons.add),
      ),
    );
  }
}