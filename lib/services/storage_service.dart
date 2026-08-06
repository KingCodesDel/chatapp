import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Uploads media to Cloudinary's free tier instead of Firebase Storage
/// (Firebase Storage now requires the paid Blaze plan to enable at all).
///
/// Replace the two values below with your own from cloudinary.com:
/// - cloudName: shown on your Cloudinary dashboard
/// - uploadPreset: the "unsigned" preset you created in Settings > Upload
class StorageService {
  static const String _cloudName = 'YOUR_CLOUD_NAME';
  static const String _uploadPreset = 'YOUR_UPLOAD_PRESET';

  /// [resourceType] is Cloudinary's own bucket for the upload:
  /// 'image' for photos, 'video' for audio/video (yes, audio goes under
  /// "video" on Cloudinary), 'raw' for anything else (PDFs, docs, zips...).
  Future<String> _upload(File file, String folder, {String resourceType = 'image'}) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Upload failed: $body');
    }

    final data = jsonDecode(body);
    return data['secure_url'] as String;
  }

  Future<String> uploadProfilePhoto(String uid, File file) => _upload(file, 'profile_photos');

  Future<String> uploadChatImage(String chatId, File file) => _upload(file, 'chat_images/$chatId');

  Future<String> uploadGroupPhoto(String chatId, File file) => _upload(file, 'group_photos');

  Future<String> uploadStatusImage(String uid, File file) => _upload(file, 'status_updates/$uid');

  Future<String> uploadVoiceMessage(String chatId, File file) => _upload(file, 'voice_messages/$chatId', resourceType: 'video');

  Future<String> uploadChatFile(String chatId, File file) => _upload(file, 'chat_files/$chatId', resourceType: 'raw');
}
