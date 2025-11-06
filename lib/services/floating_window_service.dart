import 'package:flutter/services.dart';
import '../utils/constants.dart';

class FloatingWindowService {
  static const MethodChannel _channel = MethodChannel(AppConstants.floatingWindowChannel);
  static const MethodChannel _pgpChannel = MethodChannel(AppConstants.pgpChannel);

  /// 启动悬浮窗
  Future<void> startFloatingWindow() async {
    try {
      await _channel.invokeMethod(AppConstants.startFloatingWindow);
    } on PlatformException catch (e) {
      throw Exception('启动悬浮窗失败: ${e.message}');
    }
  }

  /// 停止悬浮窗
  Future<void> stopFloatingWindow() async {
    try {
      await _channel.invokeMethod(AppConstants.stopFloatingWindow);
    } on PlatformException catch (e) {
      throw Exception('停止悬浮窗失败: ${e.message}');
    }
  }

  /// 加密消息
  /// [message] 要加密的消息
  /// [publicKey] 接收方的公钥内容
  /// 返回加密后的ASCII-armored字符串
  Future<String> encryptMessage(String message, String publicKey) async {
    try {
      final result = await _pgpChannel.invokeMethod<String>(
        AppConstants.encryptMessage,
        {
          'message': message,
          'publicKey': publicKey,
        },
      );
      if (result == null) {
        throw Exception('加密失败: 返回结果为空');
      }
      return result;
    } on PlatformException catch (e) {
      throw Exception('加密失败: ${e.message}');
    }
  }

  /// 解密消息
  /// [encryptedMessage] 加密的消息（ASCII-armored格式）
  /// [privateKey] 自己的私钥内容
  /// [password] 私钥密码（可选，如果私钥有密码保护则必须提供）
  /// 返回解密后的明文
  Future<String> decryptMessage(String encryptedMessage, String privateKey, {String? password}) async {
    try {
      final result = await _pgpChannel.invokeMethod<String>(
        AppConstants.decryptMessage,
        {
          'encryptedMessage': encryptedMessage,
          'privateKey': privateKey,
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      if (result == null) {
        throw Exception('解密失败: 返回结果为空');
      }
      return result;
    } on PlatformException catch (e) {
      throw Exception('解密失败: ${e.message}');
    }
  }
}

