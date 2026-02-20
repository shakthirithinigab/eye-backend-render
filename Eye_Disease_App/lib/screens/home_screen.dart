import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? image;
  String result = "";

  final picker = ImagePicker();

  Future pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  Future detectDisease() async {
    if (image == null) return;
    final response = await ApiService.uploadImage(image!);
    setState(() {
      result =
          "Disease: ${response['disease']}\n"
          "Confidence: ${response['confidence']}\n"
          "Eye Power: ${response['eye_power']}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Eye Disease Detection")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          image != null
              ? Image.file(image!, height: 200)
              : Text("No Image Selected"),
          ElevatedButton(
              onPressed: pickImage, child: Text("Pick Eye Image")),
          ElevatedButton(
              onPressed: detectDisease, child: Text("Detect Disease")),
          SizedBox(height: 20),
          Text(result, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
