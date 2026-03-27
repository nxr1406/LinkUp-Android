import 'dart:io';
import 'package:http/http.dart' as http;

class CatboxService {
  static Future<String?> uploadImage(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        if (body.trim().startsWith('https://')) {
          return body.trim();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
