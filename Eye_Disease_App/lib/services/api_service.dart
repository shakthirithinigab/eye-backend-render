import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000/predict";

  static Future<http.Response> detectEye(File imageFile) async {
    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
}
