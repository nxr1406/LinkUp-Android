import 'dart:io';
import 'package:dio/dio.dart';

class CatboxService {
  final Dio _dio = Dio();
  final String _uploadUrl = 'https://catbox.moe/user/api.php';

  Future<String> uploadImage(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      String fileName = imageFile.path.split('/').last;

      FormData formData = FormData.fromMap({
        'reqtype': 'fileupload',
        'fileToUpload': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
      });

      Response response = await _dio.post(
        _uploadUrl,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is String) {
        return response.data.trim();
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      print('Error uploading to Catbox: \$e');
      rethrow;
    }
  }
}
