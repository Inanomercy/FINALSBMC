import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../constants/app_constants.dart';

class StorageService {
  SupabaseClient get _adminClient => SupabaseService.adminClient;

  Future<Uint8List> _readBytes(XFile file) async => file.readAsBytes();

  Future<String> uploadProductImage(XFile file, String productId) async {
    final bytes = await _readBytes(file);
    final ext = file.name.split('.').last.toLowerCase();
    final fileName = '$productId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _adminClient.storage
        .from(AppConstants.productImagesBucket)
        .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
    return _adminClient.storage
        .from(AppConstants.productImagesBucket)
        .getPublicUrl(fileName);
  }

  Future<String> uploadCategoryImage(XFile file, String categoryId) async {
    final bytes = await _readBytes(file);
    final ext = file.name.split('.').last.toLowerCase();
    final fileName = '$categoryId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _adminClient.storage
        .from(AppConstants.categoryImagesBucket)
        .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
    return _adminClient.storage
        .from(AppConstants.categoryImagesBucket)
        .getPublicUrl(fileName);
  }

  Future<String> uploadAvatar(XFile file, String userId) async {
    final bytes = await _readBytes(file);
    final ext = file.name.split('.').last.toLowerCase();
    final fileName = '$userId/avatar.$ext';
    await _adminClient.storage
        .from(AppConstants.avatarsBucket)
        .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
    return _adminClient.storage
        .from(AppConstants.avatarsBucket)
        .getPublicUrl(fileName);
  }
}
