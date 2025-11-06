import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'encrypt_screen.dart';
import 'decrypt_screen.dart';
import '../services/key_storage_service.dart';
import '../models/pgp_key.dart';
import '../services/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final KeyStorageService _keyStorageService = KeyStorageService();
  List<PGPKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final keys = await _keyStorageService.getAllKeys();
    setState(() {
      _keys = keys;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('微信PGP加密助手'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 使用说明
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '使用方法',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionItem(
                      '1. 导入密钥',
                      '点击下方"导入密钥"按钮，导入您的私钥和对方的公钥',
                      Icons.vpn_key,
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionItem(
                      '2. 加密消息',
                      '点击"加密消息"按钮，选择对方公钥，输入消息并加密',
                      Icons.lock,
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionItem(
                      '3. 复制发送',
                      '加密完成后，点击"复制"按钮，然后粘贴到微信发送',
                      Icons.copy,
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionItem(
                      '4. 解密消息',
                      '收到加密消息后，点击"解密消息"，选择您的私钥并解密',
                      Icons.lock_open,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 功能按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const EncryptScreen()),
                      );
                    },
                    icon: const Icon(Icons.lock),
                    label: const Text('加密消息'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DecryptScreen()),
                      );
                    },
                    icon: const Icon(Icons.lock_open),
                    label: const Text('解密消息'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 导入密钥按钮
            OutlinedButton.icon(
              onPressed: _showImportKeyDialog,
              icon: const Icon(Icons.upload_file),
              label: const Text('导入密钥'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            // 密钥列表
            Text(
              '已导入的密钥 (${_keys.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_keys.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        '还没有导入密钥',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '请先导入您的私钥和对方的公钥',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._keys.map((key) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    key.isPrivate ? Icons.vpn_key : Icons.public,
                    color: key.isPrivate ? Colors.orange : Colors.blue,
                  ),
                  title: Text(key.name),
                  subtitle: Text(
                    key.isPrivate ? '私钥' : '公钥',
                    style: TextStyle(
                      color: key.isPrivate ? Colors.orange : Colors.blue,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteKey(key),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showImportKeyDialog() async {
    // 对于文件选择器，Android 10+通常不需要存储权限（使用Storage Access Framework）
    // 但为了更好的用户体验，我们仍然尝试请求权限
    
    // 检查存储权限（可选，不影响文件选择器的使用）
    final hasPermission = await PermissionService.checkStoragePermission();
    if (!hasPermission) {
      // 尝试请求权限（但不强制）
      await PermissionService.requestStoragePermission();
    }

    // 直接使用文件选择器（Android 10+不需要存储权限）
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['asc', 'pem', 'pgp', 'key', 'gpg'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final fileName = file.name;
      
      try {
        // 读取文件内容
        // 优先使用path，如果没有则使用bytes
        String keyContent;
        if (file.path != null && file.path!.isNotEmpty) {
          final fileObj = File(file.path!);
          keyContent = await fileObj.readAsString();
        } else if (file.bytes != null) {
          keyContent = String.fromCharCodes(file.bytes!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法读取文件内容')),
            );
          }
          return;
        }
        
        // 检测密钥类型
        final isPrivate = keyContent.contains('BEGIN PGP PRIVATE KEY BLOCK') ||
                         keyContent.contains('BEGIN RSA PRIVATE KEY') ||
                         keyContent.contains('BEGIN PRIVATE KEY');
        final isPublic = keyContent.contains('BEGIN PGP PUBLIC KEY BLOCK') ||
                        keyContent.contains('BEGIN RSA PUBLIC KEY') ||
                        keyContent.contains('BEGIN PUBLIC KEY');
        
        if (!isPrivate && !isPublic) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法识别密钥格式')),
            );
          }
          return;
        }

        // 提取用户ID（如果存在）
        String? userId;
        final userIdMatch = RegExp(r'User ID: (.+)').firstMatch(keyContent);
        if (userIdMatch != null) {
          userId = userIdMatch.group(1);
        }

        // 创建密钥对象
        final key = PGPKey(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: fileName,
          keyContent: keyContent,
          type: isPrivate ? KeyType.private : KeyType.public,
          createdAt: DateTime.now(),
          userId: userId,
        );

        // 保存密钥
        await _keyStorageService.saveKey(key);
        await _loadKeys();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入${isPrivate ? "私钥" : "公钥"}: $fileName')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入密钥失败: $error')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $error')),
        );
      }
    }
  }

  Future<void> _deleteKey(PGPKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除密钥'),
        content: Text('确定要删除密钥 "${key.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _keyStorageService.deleteKey(key.id);
      await _loadKeys();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密钥已删除')),
        );
      }
    }
  }
}
