import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

class PermissionDialog extends StatelessWidget {
  final String permissionName;
  final String description;
  final String? icon;
  final bool isRequired;

  const PermissionDialog({
    super.key,
    required this.permissionName,
    required this.description,
    this.icon,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              _getIcon(icon!),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(permissionName),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 16),
          if (isRequired)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此权限为必需权限，应用核心功能需要此权限才能正常工作。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        if (!isRequired)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('去设置'),
        ),
      ],
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'overlay':
        return Icons.layers;
      case 'storage':
        return Icons.folder;
      default:
        return Icons.security;
    }
  }
}

/// 显示权限请求对话框
Future<bool> showPermissionRequestDialog(
  BuildContext context, {
  required String permissionName,
  required String description,
  String? icon,
  bool isRequired = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PermissionDialog(
      permissionName: permissionName,
      description: description,
      icon: icon,
      isRequired: isRequired,
    ),
  );

  if (result == true) {
    // 用户点击了"去设置"
    if (permissionName.contains('悬浮窗') || permissionName.contains('显示在其他应用上层')) {
      await PermissionService.openOverlaySettings();
    } else {
      await openAppSettings();
    }
    return true;
  }

  return false;
}

