import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/key_storage_service.dart';
import '../services/floating_window_service.dart';
import '../models/pgp_key.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({super.key});

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  final TextEditingController _encryptedController = TextEditingController();
  final TextEditingController _decryptedController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final KeyStorageService _keyStorageService = KeyStorageService();
  final FloatingWindowService _floatingWindowService = FloatingWindowService();
  List<PGPKey> _privateKeys = [];
  PGPKey? _selectedKey;
  bool _isDecrypting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadPrivateKeys();
  }

  Future<void> _loadPrivateKeys() async {
    final keys = await _keyStorageService.getAllKeys();
    setState(() {
      _privateKeys = keys.where((key) => key.isPrivate).toList();
      if (_privateKeys.isNotEmpty && _selectedKey == null) {
        _selectedKey = _privateKeys.first;
      }
    });
  }

  Future<void> _decryptMessage() async {
    if (_encryptedController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要解密的加密消息')),
      );
      return;
    }

    if (_selectedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择您的私钥')),
      );
      return;
    }

    setState(() {
      _isDecrypting = true;
    });

    try {
      // 获取密码（如果用户输入了）
      final password = _passwordController.text.trim();
      final passwordToUse = password.isEmpty ? null : password;
      
      final decrypted = await _floatingWindowService.decryptMessage(
        _encryptedController.text,
        _selectedKey!.keyContent,
        password: passwordToUse,
      );

      setState(() {
        _decryptedController.text = decrypted;
        _isDecrypting = false;
      });
    } catch (e) {
      setState(() {
        _isDecrypting = false;
      });
      if (mounted) {
        final errorMessage = e.toString();
        // 检查是否是密码错误
        if (errorMessage.contains('密码') || errorMessage.contains('password')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('私钥密码错误，请重新输入'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('解密失败: $e')),
          );
        }
      }
    }
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _encryptedController.text = clipboardData.text!;
      });
    }
  }

  void _copyDecrypted() {
    if (_decryptedController.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _decryptedController.text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  @override
  void dispose() {
    _encryptedController.dispose();
    _decryptedController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('解密消息'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 选择私钥
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择您的私钥',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_privateKeys.isEmpty)
                      const Text(
                        '没有可用的私钥，请先导入私钥',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<PGPKey>(
                        value: _selectedKey,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '私钥',
                        ),
                        items: _privateKeys.map((key) {
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
            // 输入加密消息
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
                          '输入加密的消息',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.paste, size: 18),
                          label: const Text('粘贴'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _encryptedController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '粘贴从微信复制的加密消息...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 私钥密码输入
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '私钥密码（如果私钥有密码保护）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '输入私钥密码（如果私钥未加密可留空）',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：如果您的私钥在创建时设置了密码，请输入该密码。如果私钥未加密，可以留空。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 解密按钮
            ElevatedButton.icon(
              onPressed: _isDecrypting ? null : _decryptMessage,
              icon: _isDecrypting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open),
              label: Text(_isDecrypting ? '解密中...' : '解密'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            // 解密结果
            if (_decryptedController.text.isNotEmpty) ...[
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
                            '解密结果',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: _copyDecrypted,
                            tooltip: '复制',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _decryptedController.text,
                        style: const TextStyle(fontSize: 16),
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

