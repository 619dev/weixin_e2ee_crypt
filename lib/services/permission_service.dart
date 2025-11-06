import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    if (await Permission.systemAlertWindow.isGranted) {
      return true;
    }
    return false;
  }

  /// 请求悬浮窗权限（需要打开系统设置）
  static Future<bool> requestOverlayPermission() async {
    try {
      // 对于悬浮窗权限，需要打开系统设置
      return await Permission.systemAlertWindow.request().isGranted;
    } catch (e) {
      return false;
    }
  }

  /// 打开悬浮窗权限设置页面
  static Future<void> openOverlaySettings() async {
    await openAppSettings();
  }

  /// 检查存储权限
  static Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    
    try {
      // 对于文件选择器，实际上不需要存储权限（Android 10+使用Storage Access Framework）
      // 但为了兼容性，我们检查权限状态
      // Android 13+ (API 33+) 使用新的权限模型
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      final audioStatus = await Permission.audio.status;
      
      if (photosStatus.isGranted || videosStatus.isGranted || audioStatus.isGranted) {
        return true;
      }
      
      // Android 12及以下使用存储权限
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }
      
      // 如果都没有授予，返回false（但文件选择器可能仍然可以工作）
      return false;
    } catch (e) {
      // 如果权限检查失败，返回true（允许尝试使用文件选择器）
      return true;
    }
  }

  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    
    try {
      // Android 13+ (API 33+) 使用新的权限模型
      // 只请求photos权限通常就足够了（因为文件选择器主要需要访问图片/文档）
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted) {
        return true;
      }
      
      // 如果photos权限被拒绝，尝试请求其他权限
      final videosStatus = await Permission.videos.request();
      if (videosStatus.isGranted) {
        return true;
      }
      
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) {
        return true;
      }
      
      // Android 12及以下使用存储权限
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } catch (e) {
      // 如果权限请求失败，返回false
      return false;
    }
  }

  /// 检查所有必要权限
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'overlay': await checkOverlayPermission(),
      'storage': await checkStoragePermission(),
    };
  }

  /// 请求所有必要权限
  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};
    
    // 请求存储权限
    results['storage'] = await requestStoragePermission();
    
    // 请求悬浮窗权限
    results['overlay'] = await requestOverlayPermission();
    
    return results;
  }
}

