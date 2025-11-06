import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/key_storage_service.dart';
import '../services/floating_window_service.dart';
import '../models/pgp_key.dart';

class EncryptScreen extends StatefulWidget {
  const EncryptScreen({super.key});

  @override
  State<EncryptScreen> createState() => _EncryptScreenState();
}

class _EncryptScreenState extends State<EncryptScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _encryptedController = TextEditingController();
  final KeyStorageService _keyStorageService = KeyStorageService();
  final FloatingWindowService _floatingWindowService = FloatingWindowService();
  List<PGPKey> _publicKeys = [];
  PGPKey? _selectedKey;
  bool _isEncrypting = false;

  @override
  void initState() {
    super.initState();
    _loadPublicKeys();
  }

  Future<void> _loadPublicKeys() async {
    final keys = await _keyStorageService.getAllKeys();
    setState(() {
      _publicKeys = keys.where((key) => key.isPublic).toList();
      if (_publicKeys.isNotEmpty && _selectedKey == null) {
        _selectedKey = _publicKeys.first;
      }
    });
  }

  Future<void> _encryptMessage() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要加密的消息')),
      );
      return;
    }

    if (_selectedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择接收方的公钥')),
      );
      return;
    }

    setState(() {
      _isEncrypting = true;
    });

    try {
      final encrypted = await _floatingWindowService.encryptMessage(
        _messageController.text,
        _selectedKey!.keyContent,
      );

      setState(() {
        _encryptedController.text = encrypted;
        _isEncrypting = false;
      });
    } catch (e) {
      setState(() {
        _isEncrypting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加密失败: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_encryptedController.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _encryptedController.text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('已复制到剪贴板，可直接粘贴到微信发送'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _encryptedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('加密消息'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 选择公钥
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择接收方公钥',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_publicKeys.isEmpty)
                      const Text(
                        '没有可用的公钥，请先导入公钥',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<PGPKey>(
                        value: _selectedKey,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '公钥',
                        ),
                        items: _publicKeys.map((key) {
                          return DropdownMenuItem<PGPKey>(
                            value: key,
                            child: Text(key.name),
                          );
                        }).toList(),
                        onChanged: (key) {
                          setState(() {
                            _selectedKey = key;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 输入消息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '输入要加密的消息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '输入要加密的消息...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 加密按钮
            ElevatedButton.icon(
              onPressed: _isEncrypting ? null : _encryptMessage,
              icon: _isEncrypting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock),
              label: Text(_isEncrypting ? '加密中...' : '加密'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            // 加密结果
            if (_encryptedController.text.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '加密结果',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ElevatedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('一键复制'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _encryptedController.text,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '加密完成！',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '已复制到剪贴板，可直接粘贴到微信发送',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

