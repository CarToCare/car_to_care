import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class Principal extends StatefulWidget {
  const Principal({Key? key}) : super(key: key);

  @override
  _PrincipalState createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {

  List recipes=[];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getData();
  }

  Future<void> getData() async{
    final response = await http.get(Uri.parse('http://192.168.1.32:4499/recipes'));
    if(response.statusCode==200){
      setState(() {
        recipes=jsonDecode(response.body);
        debugPrint("Nigge: $recipes");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {},
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Tarjetas con información de recetas
            for (int i = 0; i < recipes.length; i++)
              Card(
                color: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Receta 1",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text("• ${recipes[i]['idPaciente']}"),
                      Text("• Hora de entrega: 7:15"),
                      Text("• 2 unidades de paracetamol"),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            // Botón con bordes redondeados
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              onPressed: () {},
              child: const Text("Run"),
            ),
          ],
        ),
      ),
    );
  }
}
