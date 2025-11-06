import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permission_service.dart';
import 'permission_dialog.dart';

class PermissionChecker {
  /// 检查并请求所有必要权限
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    if (!context.mounted) return false;
    
    final permissions = await PermissionService.checkAllPermissions();
    
    // 检查悬浮窗权限
    if (!permissions['overlay']!) {
      if (!context.mounted) return false;
      final granted = await showPermissionRequestDialog(
        context,
        permissionName: '悬浮窗权限',
        description: '应用需要悬浮窗权限以在微信等应用上层显示加密按钮，方便您快速加密消息。\n\n请在设置中开启"显示在其他应用上层"权限。',
        icon: 'overlay',
        isRequired: true,
      );
      
      if (!granted) {
        // 再次检查权限状态
        final recheck = await PermissionService.checkOverlayPermission();
        if (!recheck) {
          return false;
        }
      }
    }

    // 检查存储权限
    if (!permissions['storage']!) {
      if (!context.mounted) return false;
      final granted = await showPermissionRequestDialog(
        context,
        permissionName: '存储权限',
        description: '应用需要存储权限以导入PGP密钥文件。\n\n请允许应用访问存储空间。',
        icon: 'storage',
        isRequired: false,
      );
      
      if (granted) {
        // 用户点击了去设置，等待返回后再次检查
        await Future.delayed(const Duration(seconds: 1));
        await PermissionService.requestStoragePermission();
      } else {
        // 直接请求权限
        await PermissionService.requestStoragePermission();
      }
    }

    // 最终检查所有权限
    final finalCheck = await PermissionService.checkAllPermissions();
    return finalCheck['overlay']!;
  }

  /// 显示权限说明对话框（首次启动）
  static Future<void> showInitialPermissionDialog(BuildContext context) async {
    if (!context.mounted) return;
    
    try {
      final shouldShow = await _shouldShowInitialDialog();
      if (!shouldShow) return;

      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue),
            SizedBox(width: 8),
            Text('需要您的授权'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为了正常使用应用功能，需要以下权限：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _PermissionItem(
              icon: Icons.layers,
              title: '悬浮窗权限',
              description: '在微信等应用上层显示加密按钮',
              isRequired: true,
            ),
            SizedBox(height: 12),
            _PermissionItem(
              icon: Icons.folder,
              title: '存储权限',
              description: '导入PGP密钥文件',
              isRequired: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setInitialDialogShown();
            },
            child: const Text('我知道了'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!context.mounted) return;
              Navigator.of(context).pop();
              _setInitialDialogShown();
              // 开始检查权限
              if (context.mounted) {
                checkAndRequestPermissions(context);
              }
            },
            child: const Text('立即授权'),
          ),
        ],
        ),
      );
    } catch (e) {
      // 忽略对话框显示错误，避免应用崩溃
      debugPrint('显示权限对话框错误: $e');
    }
  }

  static Future<bool> _shouldShowInitialDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('permission_dialog_shown') ?? false);
  }

  static Future<void> _setInitialDialogShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permission_dialog_shown', true);
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isRequired;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (isRequired) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '必需',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

