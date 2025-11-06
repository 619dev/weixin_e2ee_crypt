# 微信PGP加密辅助应用

一个Android Flutter应用，实现微信消息的点对点PGP加密通信，保护您的隐私安全。

## 功能特性

- 🔐 **PGP加密/解密支持**：使用BouncyCastle库实现标准PGP加密
- 🔑 **密钥管理**：导入、存储和管理PGP私钥和公钥
- 🔒 **私钥密码保护**：支持密码保护的私钥解密
- 📋 **一键复制**：加密完成后一键复制，方便粘贴到微信发送
- 📱 **友好的Material Design 3界面**：简洁美观的用户体验
- 🛡️ **点对点加密通信**：弥补微信端到端加密的不足

## 技术栈

- **Flutter 3.0+**：跨平台UI框架
- **Android原生代码（Kotlin）**：PGP加密实现
- **BouncyCastle PGP库**：bcpg-jdk15on, bcprov-jdk15on
- **AndroidOpenSSL**：Android P+兼容性支持

## 系统要求

- Android 6.0+ (API 23+)
- 支持Android P (API 28+) 及以上版本

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── screens/                       # 界面
│   ├── home_screen.dart          # 主界面（密钥管理和使用说明）
│   ├── encrypt_screen.dart       # 加密界面
│   └── decrypt_screen.dart       # 解密界面
├── services/                      # 服务层
│   ├── floating_window_service.dart  # PGP加密服务（Platform Channel）
│   ├── key_storage_service.dart     # 密钥存储服务
│   └── permission_service.dart      # 权限管理服务
├── models/                        # 数据模型
│   └── pgp_key.dart              # PGP密钥模型
├── utils/                         # 工具类
│   └── constants.dart            # 常量定义
└── widgets/                      # 组件
    ├── permission_checker.dart   # 权限检查组件
    └── permission_dialog.dart    # 权限对话框

android/app/src/main/kotlin/com/wxcrypt/app/
├── MainActivity.kt               # 主Activity（Platform Channel处理）
├── FloatingWindowService.kt      # 悬浮窗服务（已移除，保留代码）
└── PGPEncryptionHelper.kt        # PGP加密/解密核心实现
```

## 使用说明

### 1. 导入密钥

1. 打开应用，点击"导入密钥"按钮
2. 选择PGP密钥文件（支持 `.asc`, `.pem`, `.pgp`, `.key`, `.gpg` 格式）
3. 应用会自动识别密钥类型（私钥或公钥）
4. 密钥会保存在应用本地存储中

**支持的密钥格式：**
- PGP公钥：`-----BEGIN PGP PUBLIC KEY BLOCK-----`
- PGP私钥：`-----BEGIN PGP PRIVATE KEY BLOCK-----`
- RSA公钥/私钥：`-----BEGIN RSA PUBLIC KEY-----` / `-----BEGIN RSA PRIVATE KEY-----`
- 支持包含元数据的密钥（如 `Version:`, `Comment:`, `Charset:` 等）

### 2. 加密消息

1. 在主界面点击"加密消息"按钮
2. 选择接收方的公钥（从下拉列表中选择）
3. 在输入框中输入要加密的消息
4. 点击"加密"按钮
5. 加密完成后，点击"一键复制"按钮
6. 将加密后的消息粘贴到微信发送给接收方

**提示：**
- 加密后的消息是ASCII-armored格式，可以直接在微信中发送
- 加密结果会自动复制到剪贴板，方便粘贴

### 3. 解密消息

1. 收到加密消息后，复制加密内容
2. 在主界面点击"解密消息"按钮
3. 选择您的私钥（从下拉列表中选择）
4. 如果私钥有密码保护，输入私钥密码
5. 粘贴加密消息到输入框（或点击"粘贴"按钮）
6. 点击"解密"按钮查看明文

**提示：**
- 如果私钥有密码保护，必须输入正确的密码才能解密
- 密码输入框支持显示/隐藏密码功能

### 4. 管理密钥

- **查看密钥**：在主界面查看所有已导入的密钥列表
- **删除密钥**：点击密钥右侧的删除按钮可以删除密钥
- **密钥类型标识**：私钥显示橙色图标，公钥显示蓝色图标

## 权限说明

应用需要以下权限：

- **存储权限**（可选）：
  - Android 12及以下：`READ_EXTERNAL_STORAGE`
  - Android 13+：`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`
  - 注意：Android 10+ 使用Storage Access Framework，通常不需要存储权限即可选择文件

- **前台服务权限**：
  - Android 14+：`FOREGROUND_SERVICE_DATA_SYNC`

## 开发环境

- **Flutter SDK**: 3.0+
- **Android SDK**: 23+ (Android 6.0+)
- **Kotlin**: 2.1.0+
- **Gradle**: 8.11.1+
- **Android Gradle Plugin**: 8.9.1+
- **Java**: 11+

## 构建说明

### 开发构建

```bash
# 安装依赖
flutter pub get

# 运行应用（调试模式）
flutter run

# 构建APK（调试版）
flutter build apk
```

### 发布构建

```bash
# 清理构建缓存
flutter clean

# 获取依赖
flutter pub get

# 构建发布版APK
flutter build apk --release
```

构建完成后，APK文件位于：`build/app/outputs/flutter-apk/app-release.apk`

## 技术实现细节

### PGP加密实现

- 使用BouncyCastle库进行PGP加密/解密
- 支持AES-256加密算法
- 支持ZIP压缩
- 支持完整性检查（Integrity Packet）
- Android P+兼容：使用AndroidOpenSSL提供者避免BC提供者限制

### 密钥解析

- 自动清理ASCII-armored格式的密钥
- 支持包含元数据的密钥（自动过滤 `Version:`, `Comment:`, `Charset:` 等）
- 自动移除Base64行中的空格和制表符
- 支持多种密钥格式（PGP、RSA等）

### 数据存储

- 使用 `shared_preferences` 存储密钥数据
- 密钥以JSON格式存储
- 支持密钥的增删查改操作

## 已知问题和限制

1. **仅支持文本消息**：当前版本仅支持文本消息的加密/解密，不支持文件加密
2. **密钥格式**：需要标准的PGP格式密钥，某些特殊格式可能无法识别
3. **Android版本兼容性**：建议使用Android 6.0及以上版本，Android P+已完全支持

## 安全注意事项

1. **私钥安全**：
   - 私钥存储在应用本地，请妥善保管设备
   - 建议为私钥设置密码保护
   - 不要将私钥分享给他人

2. **密钥管理**：
   - 定期备份您的密钥
   - 如果设备丢失，及时撤销相关密钥

3. **加密通信**：
   - 确保接收方也使用此应用或兼容的PGP工具
   - 验证接收方的公钥指纹，防止中间人攻击

## 故障排除

### 加密失败

- **错误：无法解析公钥**
  - 检查公钥格式是否正确
  - 确保公钥包含完整的 `-----BEGIN PGP PUBLIC KEY BLOCK-----` 和 `-----END PGP PUBLIC KEY BLOCK-----`
  - 尝试重新导入公钥

- **错误：exception constructing public key**
  - 这是Android P+的已知问题，已通过使用AndroidOpenSSL提供者解决
  - 如果仍然出现，请检查日志获取详细信息

### 解密失败

- **错误：私钥密码错误**
  - 确认输入的密码正确
  - 检查私钥是否真的有密码保护
  - 尝试使用空密码（如果私钥未加密）

- **错误：未找到匹配的私钥**
  - 确保使用的私钥与加密时使用的公钥对应
  - 检查私钥格式是否正确

### 文件导入失败

- **无法选择文件**
  - Android 10+ 使用系统文件选择器，通常不需要存储权限
  - 如果无法选择，尝试在设置中授予存储权限

## 更新日志

### v1.0.0
- ✅ 实现PGP加密/解密功能
- ✅ 密钥管理（导入、存储、删除）
- ✅ 私钥密码保护支持
- ✅ 一键复制加密结果
- ✅ Android P+兼容性修复
- ✅ 改进的公钥解析逻辑
- ✅ 友好的用户界面和使用说明

## 许可证

本项目仅供学习和研究使用。

## 贡献

欢迎提交Issue和Pull Request！

## 联系方式

如有问题或建议，请通过GitHub Issues反馈。
