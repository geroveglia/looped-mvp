import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // For Android Emulator use 'http://10.0.2.2:3000'
  // For Physical Device use your PC's local IP
  // For Web or Windows Desktop use 'http://localhost:3000'
  static const String baseUrl = 'http://localhost:3000';

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(data),
    );

    return _processResponse(response);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders();

    final response = await http.patch(
      url,
      headers: headers,
      body: jsonEncode(data),
    );

    return _processResponse(response);
  }

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders();

    final response = await http.get(url, headers: headers);
    return _processResponse(response);
  }

  Future<dynamic> postMultipart(
      String endpoint, Map<String, String> fields, Uint8List? imageBytes,
      {String? fileName, String fileFieldName = 'image'}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);

    // Headers
    final headers = await getHeaders();
    request.headers.addAll(headers);
    request.headers.remove('Content-Type');

    // Fields
    request.fields.addAll(fields);

    // File from bytes (cross-platform robust)
    if (imageBytes != null && imageBytes.isNotEmpty) {
      request.files.add(http.MultipartFile.fromBytes(
        fileFieldName,
        imageBytes,
        filename: fileName ?? 'upload.jpg',
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      // Simple error handling
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Unknown error');
    }
  }
}
