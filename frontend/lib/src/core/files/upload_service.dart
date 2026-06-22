import '../network/api_client.dart';
import 'picked_image.dart';

class UploadService {
  final ApiClient apiClient;

  const UploadService(this.apiClient);

  Future<String> uploadImage(PickedImage image, String purpose) async {
    final response = await apiClient.post(
      '/uploads/presign',
      body: {'purpose': purpose, 'contentType': image.contentType},
    );
    final data = response['data'] as Map<String, dynamic>;
    await apiClient.uploadToSignedUrl(
      uploadUrl: data['uploadUrl'] as String,
      bytes: image.bytes,
      contentType: image.contentType,
    );
    return data['s3Key'] as String;
  }
}
