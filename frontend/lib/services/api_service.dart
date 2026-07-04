import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;

  /// Resolves a media path from the API into a loadable URL.
  /// Server-relative paths ('/uploads/...') get the API base prepended;
  /// absolute URLs (e.g. Google avatars) are returned untouched.
  static String mediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }

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

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders();

    final response = await http.delete(url, headers: headers);
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
      try {
        return jsonDecode(response.body);
      } on FormatException {
        throw Exception('Server returned invalid data format');
      }
    } else {
      // Simple error handling
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Unknown error');
      } on FormatException {
        throw Exception('Server error (${response.statusCode})');
      }
    }
  }
}
