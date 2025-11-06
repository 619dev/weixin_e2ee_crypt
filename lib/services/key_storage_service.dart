import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pgp_key.dart';
import '../utils/constants.dart';

class KeyStorageService {
  /// 保存密钥
  Future<void> saveKey(PGPKey key) async {
    final prefs = await SharedPreferences.getInstance();
    final keyJson = jsonEncode(key.toJson());
    await prefs.setString('${key.type == KeyType.private ? AppConstants.privateKeyPrefix : AppConstants.publicKeyPrefix}${key.id}', keyJson);
    
    // 更新密钥列表
    final keyList = await _getKeyList();
    if (!keyList.contains(key.id)) {
      keyList.add(key.id);
      await prefs.setStringList(AppConstants.keyListKey, keyList);
    }
  }

  /// 获取所有密钥
  Future<List<PGPKey>> getAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keyList = await _getKeyList();
    final keys = <PGPKey>[];

    for (final keyId in keyList) {
      // 尝试获取私钥
      final privateKeyJson = prefs.getString('${AppConstants.privateKeyPrefix}$keyId');
      if (privateKeyJson != null) {
        try {
          keys.add(PGPKey.fromJson(jsonDecode(privateKeyJson)));
          continue;
        } catch (e) {
          // 解析失败，继续尝试公钥
        }
      }

      // 尝试获取公钥
      final publicKeyJson = prefs.getString('${AppConstants.publicKeyPrefix}$keyId');
      if (publicKeyJson != null) {
        try {
          keys.add(PGPKey.fromJson(jsonDecode(publicKeyJson)));
        } catch (e) {
          // 解析失败，跳过
        }
      }
    }

    return keys;
  }

  /// 获取密钥列表ID
  Future<List<String>> _getKeyList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConstants.keyListKey) ?? [];
  }

  /// 根据ID获取密钥
  Future<PGPKey?> getKeyById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 尝试获取私钥
    final privateKeyJson = prefs.getString('${AppConstants.privateKeyPrefix}$id');
    if (privateKeyJson != null) {
      try {
        return PGPKey.fromJson(jsonDecode(privateKeyJson));
      } catch (e) {
        // 解析失败
      }
    }

    // 尝试获取公钥
    final publicKeyJson = prefs.getString('${AppConstants.publicKeyPrefix}$id');
    if (publicKeyJson != null) {
      try {
        return PGPKey.fromJson(jsonDecode(publicKeyJson));
      } catch (e) {
        // 解析失败
      }
    }

    return null;
  }

  /// 删除密钥
  Future<void> deleteKey(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${AppConstants.privateKeyPrefix}$id');
    await prefs.remove('${AppConstants.publicKeyPrefix}$id');
    
    // 从列表中移除
    final keyList = await _getKeyList();
    keyList.remove(id);
    await prefs.setStringList(AppConstants.keyListKey, keyList);
  }
}

