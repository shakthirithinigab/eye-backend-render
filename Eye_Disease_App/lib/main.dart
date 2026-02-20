import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🔥 CHANGE THIS TO YOUR RAILWAY URL
const String baseUrl = "https://yourproject.up.railway.app";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class ScanHistory {
  final String disease;
  final String confidence;

  ScanHistory(this.disease, this.confidence);
}

////////////////////////////////////////////////////////////
/// LOGIN PAGE (Cloud Connected)
////////////////////////////////////////////////////////////

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> login() async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": usernameController.text,
        "password": passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Credentials")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "AI Eye Disease Detection",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text("Login"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text("Create Account"),
            )
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// REGISTER PAGE (Cloud)
////////////////////////////////////////////////////////////

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> register() async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": usernameController.text,
        "password": passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered Successfully")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User already exists")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: register,
              child: const Text("Register"),
            )
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// HOME PAGE (ONLY URL UPDATED)
////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  Uint8List? heatmapBytes;

  String? disease;
  String? diseaseConfidence;

  bool isLoading = false;

  final ImagePicker _picker = ImagePicker();
  List<ScanHistory> history = [];
  final TextEditingController nameController = TextEditingController();

  Future<void> pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        heatmapBytes = null;
        disease = null;
        diseaseConfidence = null;
      });
    }
  }

  /// 🔥 UPDATED TO CLOUD
  Future<void> predict() async {
    if (_image == null) return;

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse("$baseUrl/predict");

      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('image', _image!.path),
      );

      var response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(body);

        String predicted = data['disease'];

        if (predicted.toLowerCase() == "eyelid") {
          predicted = "Blepharitis";
        }

        setState(() {
          disease = predicted;
          diseaseConfidence =
              double.parse(data['confidence'].toString())
                  .toStringAsFixed(2);

          heatmapBytes = base64Decode(data['heatmap']);
          history.add(ScanHistory(disease!, diseaseConfidence!));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  double getSeverity() {
    if (diseaseConfidence == null) return 0;
    return double.parse(diseaseConfidence!) / 100;
  }

  String getSuggestion(String disease) {
    double severity = getSeverity();

    if (disease.toLowerCase() == "healthy") {
      return "No disease detected. Maintain regular eye checkups.";
    }

    if (severity < 0.4) {
      return "Mild condition detected. Use medication and monitor symptoms.";
    } else if (severity < 0.7) {
      return "Moderate condition detected. Consult ophthalmologist.";
    } else {
      return "Severe condition detected. Immediate medical attention required.";
    }
  }

  // 🔥 YOUR ENTIRE EXISTING UI BELOW IS UNCHANGED
  ////////////////////////////////////////////////////////////
/// HOME PAGE
////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  Uint8List? heatmapBytes;

  String? disease;
  String? diseaseConfidence;

  bool isLoading = false;

  final ImagePicker _picker = ImagePicker();
  List<ScanHistory> history = [];

  final TextEditingController nameController = TextEditingController();

  ////////////////////////////////////////////////////////////
  /// PICK IMAGE
  ////////////////////////////////////////////////////////////

  Future<void> pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        heatmapBytes = null;
        disease = null;
        diseaseConfidence = null;
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// API CALL
  ////////////////////////////////////////////////////////////

  Future<void> predict() async {
    if (_image == null) return;

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse("http://127.0.0.1:5000/predict");

      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('image', _image!.path),
      );

      var response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(body);

        String predicted = data['disease'];

        // 🔥 Change eyelid to medical name
        if (predicted.toLowerCase() == "eyelid") {
          predicted = "Blepharitis";
        }

        setState(() {
          disease = predicted;

          diseaseConfidence =
              double.parse(data['confidence'].toString())
                  .toStringAsFixed(2);

          heatmapBytes = base64Decode(data['heatmap']);

          history.add(ScanHistory(disease!, diseaseConfidence!));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  ////////////////////////////////////////////////////////////
  /// SEVERITY BASED SUGGESTION
  ////////////////////////////////////////////////////////////

  double getSeverity() {
    if (diseaseConfidence == null) return 0;
    return double.parse(diseaseConfidence!) / 100;
  }

  String getSuggestion(String disease) {
    double severity = getSeverity();

    if (disease.toLowerCase() == "healthy") {
      return "No disease detected. Maintain regular eye checkups.";
    }

    if (severity < 0.4) {
      return "Mild condition detected. Use medication as prescribed and monitor symptoms.";
    } else if (severity < 0.7) {
      return "Moderate condition detected. Schedule an ophthalmologist consultation.";
    } else {
      return "Severe condition detected. Immediate medical attention required.";
    }
  }

  ////////////////////////////////////////////////////////////
  /// PDF GENERATION (UNCHANGED LOGIC)
  ////////////////////////////////////////////////////////////

  Future<void> generatePdf() async {
  final pdf = pw.Document();

  final String reportId =
      "EDR-${DateTime.now().millisecondsSinceEpoch}";

  final String formattedDate =
      "${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}";

  final String patientName =
      nameController.text.isEmpty ? "Not Provided" : nameController.text;

  final String detectedDisease =
      disease ?? "Not Available";

  final String confidenceValue =
      diseaseConfidence ?? "0";

  final String severityValue =
      (getSeverity() * 100).toStringAsFixed(0);

  pdf.addPage(
    pw.Page(
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        return pw.Stack(
          children: [

            // ================= WATERMARK =================
            pw.Center(
              child: pw.Opacity(
                opacity: 0.07,
                child: pw.Transform.rotate(
                  angle: -0.5,
                  child: pw.Text(
                    "AI GENERATED REPORT",
                    style: pw.TextStyle(
                      fontSize: 55,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey400,
                    ),
                  ),
                ),
              ),
            ),

            // ================= MAIN CONTENT =================
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // HEADER
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "AI Based Eye Disease Detection Project",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "Report ID: $reportId",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 25),

                pw.Center(
                  child: pw.Text(
                    "EYE DISEASE DIAGNOSTIC REPORT",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.SizedBox(height: 25),

                // TABLE
                pw.Table(
                  border: pw.TableBorder.all(width: 1),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    buildPdfRow("Patient Name", patientName),
                    buildPdfRow("Disease Detected", detectedDisease),
                    buildPdfRow("Confidence Level", "$confidenceValue %"),
                    buildPdfRow("Severity Index", "$severityValue %"),
                    buildPdfRow("Report Date", formattedDate),
                  ],
                ),

                pw.SizedBox(height: 30),

                // RECOMMENDATION
                pw.Text(
                  "Doctor Recommendation",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    getSuggestion(detectedDisease),
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),

                pw.SizedBox(height: 50),

                // SIGNATURE SECTION
                pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text("________________________"),
                        pw.SizedBox(height: 5),
                        pw.Text("AI Diagnostic System"),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text("________________________"),
                        pw.SizedBox(height: 5),
                        pw.Text("Authorized Doctor"),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 40),

                pw.Divider(),

                pw.Center(
                  child: pw.Text(
                    "This report is generated using Artificial Intelligence and must be verified by a certified ophthalmologist before clinical use.",
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}

pw.TableRow buildPdfRow(String title, String value) {
  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}

  ////////////////////////////////////////////////////////////
  /// DOCTOR MAP
  ////////////////////////////////////////////////////////////

  Future<void> openDoctors() async {
    final Uri url =
        Uri.parse("https://www.google.com/maps/search/eye+hospital+near+me");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Eye Disease Detection"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Patient Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(12)),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    )
                  : const Center(child: Text("No Image Selected")),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
                onPressed: pickImage,
                child: const Text("Pick Image")),

            ElevatedButton(
                onPressed: predict,
                child: const Text("Predict")),

            const SizedBox(height: 20),

            if (isLoading) const CircularProgressIndicator(),

            if (disease != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text("Disease: $disease",
                          style: const TextStyle(fontSize: 18)),
                      Text("Confidence: $diseaseConfidence%"),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: getSeverity()),
                      const SizedBox(height: 10),
                      Text(getSuggestion(disease!),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: generatePdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text("Report"),
                          ),
                          ElevatedButton.icon(
                            onPressed: openDoctors,
                            icon: const Icon(Icons.local_hospital),
                            label: const Text("Doctors"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            if (heatmapBytes != null)
              Column(
                children: [
                  const Text("AI Heatmap Preview"),
                  const SizedBox(height: 6),
                  Image.memory(heatmapBytes!, height: 200),
                ],
              ),

            const SizedBox(height: 20),

            if (history.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scan History",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  ...history.map((h) => ListTile(
                        title: Text(h.disease),
                        trailing: Text("${h.confidence}%"),
                      ))
                ],
              )
          ],
        ),
      ),
    );
  }
}
