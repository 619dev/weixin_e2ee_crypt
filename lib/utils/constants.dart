class AppConstants {
  // 悬浮窗服务相关
  static const String floatingWindowChannel = 'com.wxcrypt.floating_window';
  static const String showEncryptScreen = 'showEncryptScreen';
  static const String startFloatingWindow = 'startFloatingWindow';
  static const String stopFloatingWindow = 'stopFloatingWindow';
  
  // PGP加密相关
  static const String pgpChannel = 'com.wxcrypt.pgp';
  static const String encryptMessage = 'encryptMessage';
  static const String decryptMessage = 'decryptMessage';
  
  // 密钥存储相关
  static const String privateKeyPrefix = 'private_key_';
  static const String publicKeyPrefix = 'public_key_';
  static const String keyListKey = 'key_list';
  
  // 文件扩展名
  static const List<String> keyFileExtensions = ['.asc', '.pem', '.pgp', '.key'];
}

