import 'dart:io';
import 'package:http/http.dart' as http;

class CatboxService {
  static const _url = 'https://catbox.moe/user/api.php';

  static Future<String?> uploadFile(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_url));
      request.fields['reqtype'] = 'fileupload';
      request.files.add(
        await http.MultipartFile.fromPath('fileToUpload', file.path),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final url = await response.stream.bytesToString();
        if (url.startsWith('https://')) return url.trim();
      }
    } catch (e) {
      print('Catbox upload error: $e');
    }
    return null;
  }
}
