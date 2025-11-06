# 构建说明

本文档提供详细的构建步骤和故障排除指南。

## 前置要求

### 必需软件

1. **Flutter SDK 3.0+**
   ```bash
   flutter --version  # 检查版本
   ```

2. **Android Studio** 或 **Android SDK**
   - Android SDK Platform 23+
   - Android SDK Build-Tools 36.0.0
   - Android SDK Command-line Tools

3. **Java Development Kit (JDK) 11+**
   ```bash
   java -version  # 检查版本
   ```

4. **Gradle 8.11.1+**
   - 项目已包含Gradle Wrapper，会自动下载

## 构建步骤

### 1. 克隆项目

```bash
git clone <repository-url>
cd wx-crypt
```

### 2. 安装Flutter依赖

```bash
flutter pub get
```

### 3. 检查环境

```bash
flutter doctor
```

确保所有检查项都通过（或至少Android相关项通过）。

### 4. 构建APK

#### 调试版

```bash
flutter build apk
```

#### 发布版（推荐）

```bash
flutter clean
flutter pub get
flutter build apk --release
```

构建完成后，APK文件位于：
```
build/app/outputs/flutter-apk/app-release.apk
```

### 5. 安装APK

```bash
# 使用adb安装
adb install build/app/outputs/flutter-apk/app-release.apk

# 或直接传输到设备手动安装
```

## 常见构建问题

### 1. Gradle版本不兼容

**错误信息：**
```
Your project's Gradle version is incompatible with the Java version
```

**解决方案：**
- 确保使用Java 11或更高版本
- 检查 `android/gradle/wrapper/gradle-wrapper.properties` 中的Gradle版本
- 当前项目使用Gradle 8.11.1

### 2. Android Gradle Plugin版本问题

**错误信息：**
```
Plugin [id: 'com.android.application'] was not found
```

**解决方案：**
- 检查 `android/build.gradle` 中的AGP版本
- 当前项目使用AGP 8.9.1
- 确保网络连接正常，可以访问Maven仓库

### 3. Build Tools版本缺失

**错误信息：**
```
Failed to find Build Tools revision 35.0.0
```

**解决方案：**
- 使用Android SDK Manager安装Build Tools 36.0.0
- 或让Gradle自动选择可用版本（当前配置已支持）

### 4. 网络下载失败

**错误信息：**
```
Could not GET 'https://dl.google.com/...' Remote host terminated the handshake
```

**解决方案：**
- 配置代理或VPN
- 使用国内镜像（项目已配置Aliyun Maven镜像）
- 检查网络连接

### 5. Kotlin编译错误

**错误信息：**
```
Unresolved reference: xxx
```

**解决方案：**
- 检查Kotlin版本兼容性
- 当前项目使用Kotlin 2.1.0
- 运行 `flutter clean` 后重新构建

### 6. BouncyCastle依赖问题

**错误信息：**
```
Could not resolve: org.bouncycastle:bcpg-jdk15on
```

**解决方案：**
- 检查网络连接
- 确保 `android/app/build.gradle` 中正确配置了BouncyCastle依赖
- 当前版本：`bcpg-jdk15on` 和 `bcprov-jdk15on`

## 调试技巧

### 查看详细日志

```bash
# Flutter日志
flutter run --verbose

# Android日志
adb logcat | grep PGPEncryptionHelper
adb logcat | grep Flutter
```

### 清理构建缓存

```bash
# 清理Flutter构建
flutter clean

# 清理Gradle缓存
cd android
./gradlew clean
cd ..

# 清理所有
rm -rf build/
rm -rf android/.gradle/
rm -rf android/app/build/
```

### 检查依赖

```bash
# 检查Flutter依赖
flutter pub outdated

# 检查Android依赖
cd android
./gradlew dependencies
```

## 性能优化

### 减小APK大小

1. **启用代码混淆**（已配置）
2. **启用资源压缩**（已配置）
3. **使用Split APKs**（可选）

```bash
# 构建Split APKs（按ABI）
flutter build apk --split-per-abi
```

### 构建时间优化

1. **启用Gradle缓存**
2. **使用Gradle Daemon**
3. **配置代理加速下载**

## 签名配置（可选）

如果需要发布到应用商店，需要配置签名：

1. 创建密钥库：
```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

2. 配置签名（编辑 `android/app/build.gradle`）：
```gradle
android {
    ...
    signingConfigs {
        release {
            storeFile file('path/to/key.jks')
            storePassword 'your-store-password'
            keyAlias 'key'
            keyPassword 'your-key-password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 验证构建

构建完成后，验证APK：

```bash
# 检查APK信息
aapt dump badging build/app/outputs/flutter-apk/app-release.apk

# 安装并测试
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 环境变量（可选）

可以设置以下环境变量加速构建：

```bash
# Gradle JVM参数
export GRADLE_OPTS="-Xmx2048m -XX:MaxPermSize=512m"

# Android SDK路径
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

## 故障排除检查清单

- [ ] Flutter SDK版本正确（3.0+）
- [ ] Java版本正确（11+）
- [ ] Android SDK已安装并配置
- [ ] 网络连接正常（可以访问Maven仓库）
- [ ] 已运行 `flutter pub get`
- [ ] 已运行 `flutter clean`（如果遇到奇怪错误）
- [ ] Gradle版本兼容（8.11.1+）
- [ ] Android Gradle Plugin版本正确（8.9.1）
- [ ] Kotlin版本正确（2.1.0）
- [ ] 所有依赖都已下载

## 获取帮助

如果遇到问题：

1. 查看完整错误日志
2. 运行 `flutter doctor -v` 检查环境
3. 查看本文档的故障排除部分
4. 提交Issue并附上错误日志
