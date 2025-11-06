package com.wxcrypt.app

import org.bouncycastle.bcpg.ArmoredOutputStream
import org.bouncycastle.bcpg.CompressionAlgorithmTags
import org.bouncycastle.bcpg.SymmetricKeyAlgorithmTags
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.openpgp.*
import org.bouncycastle.openpgp.operator.jcajce.JcaKeyFingerprintCalculator
import org.bouncycastle.openpgp.operator.jcajce.JcaPGPKeyConverter
import org.bouncycastle.openpgp.operator.jcajce.JcePGPDataEncryptorBuilder
import org.bouncycastle.openpgp.operator.jcajce.JcePublicKeyKeyEncryptionMethodGenerator
import java.io.*
import java.security.Security
import java.security.SecureRandom
import java.util.Date

object PGPEncryptionHelper {
    init {
        // 添加BouncyCastle提供者
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    /**
     * 使用公钥加密消息
     */
    fun encrypt(message: String, publicKeyArmored: String): String {
        try {
            // 清理公钥内容，提取ASCII-armored部分
            val cleanedKey = cleanArmoredKey(publicKeyArmored)
            android.util.Log.d("PGPEncryptionHelper", "Cleaned key length: ${cleanedKey.length}")
            android.util.Log.d("PGPEncryptionHelper", "Key preview: ${cleanedKey.take(100)}...")
            
            // 读取公钥 - 尝试多种方式
            val publicKeyRingCollection: PGPPublicKeyRingCollection = try {
                // 首先尝试直接使用ByteArrayInputStream，让PGPUtil处理ASCII-armored格式
                val byteArray = cleanedKey.toByteArray(Charsets.UTF_8)
                android.util.Log.d("PGPEncryptionHelper", "Attempting to parse key, size: ${byteArray.size} bytes")
                
                val inputStream = PGPUtil.getDecoderStream(ByteArrayInputStream(byteArray))
                try {
                    val collection = PGPPublicKeyRingCollection(inputStream, JcaKeyFingerprintCalculator())
                    android.util.Log.d("PGPEncryptionHelper", "Successfully parsed as keyring collection")
                    collection
                } catch (e: Exception) {
                    android.util.Log.e("PGPEncryptionHelper", "Error creating collection: ${e.message}", e)
                    throw e
                } finally {
                    try {
                        inputStream.close()
                    } catch (e: Exception) {
                        android.util.Log.w("PGPEncryptionHelper", "Error closing stream: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("PGPEncryptionHelper", "Failed to parse as keyring collection: ${e.message}", e)
                android.util.Log.e("PGPEncryptionHelper", "Exception type: ${e.javaClass.name}")
                e.printStackTrace()
                
                // 尝试作为单个公钥解析
                try {
                    android.util.Log.d("PGPEncryptionHelper", "Trying to parse as single keyring")
                    val byteArray = cleanedKey.toByteArray(Charsets.UTF_8)
                    val inputStream = PGPUtil.getDecoderStream(ByteArrayInputStream(byteArray))
                    try {
                        val objectFactory = PGPObjectFactory(inputStream, JcaKeyFingerprintCalculator())
                        var obj: Any? = objectFactory.nextObject()
                        var foundKeyRing: PGPPublicKeyRing? = null
                        var objCount = 0
                        while (obj != null) {
                            objCount++
                            android.util.Log.d("PGPEncryptionHelper", "Object $objCount: ${obj.javaClass.simpleName}")
                            if (obj is PGPPublicKeyRing) {
                                foundKeyRing = obj
                                android.util.Log.d("PGPEncryptionHelper", "Found PGPPublicKeyRing")
                                break
                            }
                            obj = objectFactory.nextObject()
                        }
                        if (foundKeyRing != null) {
                            PGPPublicKeyRingCollection(listOf(foundKeyRing))
                        } else {
                            throw Exception("无法解析公钥：未找到有效的公钥环（已检查 $objCount 个对象）")
                        }
                    } finally {
                        try {
                            inputStream.close()
                        } catch (e: Exception) {
                            android.util.Log.w("PGPEncryptionHelper", "Error closing stream: ${e.message}")
                        }
                    }
                } catch (e2: Exception) {
                    android.util.Log.e("PGPEncryptionHelper", "Failed to parse as single keyring: ${e2.message}", e2)
                    android.util.Log.e("PGPEncryptionHelper", "Exception type: ${e2.javaClass.name}")
                    e2.printStackTrace()
                    throw Exception("无法解析公钥：${e.message ?: e2.message}")
                }
            }

            // 获取第一个可用于加密的公钥
            var publicKey: PGPPublicKey? = null
            val keyRings = publicKeyRingCollection.keyRings
            var keyRingCount = 0
            var keyCount = 0
            
            while (keyRings.hasNext()) {
                keyRingCount++
                try {
                    val keyRing = keyRings.next() as PGPPublicKeyRing
                    val publicKeys = keyRing.publicKeys
                    while (publicKeys.hasNext()) {
                        keyCount++
                        try {
                            val key = publicKeys.next() as PGPPublicKey
                            android.util.Log.d("PGPEncryptionHelper", "Found key: algorithm=${key.algorithm}, isEncryptionKey=${key.isEncryptionKey}, keyID=${key.keyID}")
                            if (key.isEncryptionKey) {
                                publicKey = key
                                android.util.Log.d("PGPEncryptionHelper", "Selected encryption key: keyID=${key.keyID}")
                                break
                            }
                        } catch (e: Exception) {
                            android.util.Log.w("PGPEncryptionHelper", "Error processing key: ${e.message}")
                        }
                    }
                    if (publicKey != null) break
                } catch (e: Exception) {
                    android.util.Log.w("PGPEncryptionHelper", "Error processing keyring: ${e.message}")
                }
            }
            
            android.util.Log.d("PGPEncryptionHelper", "Processed $keyRingCount keyrings, $keyCount keys")
            publicKey ?: throw Exception("未找到可用于加密的公钥（已检查 $keyCount 个密钥）")

            android.util.Log.d("PGPEncryptionHelper", "Starting encryption, message length: ${message.length}")
            
            // 创建输出流
            val byteArrayOutputStream = ByteArrayOutputStream()
            val armoredOutputStream = ArmoredOutputStream(byteArrayOutputStream)
            android.util.Log.d("PGPEncryptionHelper", "Created output streams")

            // 创建加密数据生成器
            val encryptedDataGenerator = PGPEncryptedDataGenerator(
                JcePGPDataEncryptorBuilder(SymmetricKeyAlgorithmTags.AES_256)
                    .setWithIntegrityPacket(true)
                    .setSecureRandom(SecureRandom())
                    .setProvider("BC")
            )
            android.util.Log.d("PGPEncryptionHelper", "Created encrypted data generator")

            // 在Android P+上，BC提供者的RSA KeyFactory被禁用
            // JcePublicKeyKeyEncryptionMethodGenerator内部使用JcaPGPKeyConverter，需要设置正确的提供者
            // 解决方案：先使用JcaPGPKeyConverter转换密钥（使用AndroidOpenSSL），然后创建加密方法生成器
            try {
                // 使用AndroidOpenSSL提供者转换密钥（避免BC提供者的KeyFactory限制）
                val keyConverter = JcaPGPKeyConverter().setProvider("AndroidOpenSSL")
                // 先转换一次以验证密钥可用
                val jcaPublicKey = keyConverter.getPublicKey(publicKey)
                android.util.Log.d("PGPEncryptionHelper", "Converted PGP key to JCA key using AndroidOpenSSL: ${jcaPublicKey.algorithm}")
                
                // 创建加密方法生成器，使用AndroidOpenSSL提供者
                // JcePublicKeyKeyEncryptionMethodGenerator内部会使用JcaPGPKeyConverter，我们需要确保它使用正确的提供者
                val encryptionMethodGenerator = JcePublicKeyKeyEncryptionMethodGenerator(publicKey)
                // 设置提供者为AndroidOpenSSL，这样内部转换也会使用AndroidOpenSSL
                encryptionMethodGenerator.setProvider("AndroidOpenSSL")
                encryptedDataGenerator.addMethod(encryptionMethodGenerator)
                android.util.Log.d("PGPEncryptionHelper", "Added encryption method with AndroidOpenSSL provider")
            } catch (e: Exception) {
                android.util.Log.w("PGPEncryptionHelper", "Failed to use AndroidOpenSSL: ${e.message}", e)
                // 如果AndroidOpenSSL失败，尝试不指定提供者（使用系统默认）
                try {
                    val encryptionMethodGenerator = JcePublicKeyKeyEncryptionMethodGenerator(publicKey)
                    // 不设置提供者，让系统自动选择
                    encryptedDataGenerator.addMethod(encryptionMethodGenerator)
                    android.util.Log.d("PGPEncryptionHelper", "Added encryption method without explicit provider")
                } catch (e2: Exception) {
                    android.util.Log.e("PGPEncryptionHelper", "Failed to add encryption method: ${e2.message}", e2)
                    throw Exception("无法创建加密方法生成器: ${e.message ?: e2.message}")
                }
            }

            // 创建压缩数据生成器
            val compressedDataGenerator = PGPCompressedDataGenerator(CompressionAlgorithmTags.ZIP)
            android.util.Log.d("PGPEncryptionHelper", "Created compressed data generator")

            // 加密消息
            try {
                val outputStream = encryptedDataGenerator.open(armoredOutputStream, ByteArray(4096))
                android.util.Log.d("PGPEncryptionHelper", "Opened encrypted output stream")
                
                val compressedStream = compressedDataGenerator.open(outputStream)
                android.util.Log.d("PGPEncryptionHelper", "Opened compressed stream")
                
                val literalDataGenerator = PGPLiteralDataGenerator()
                val messageBytes = message.toByteArray(Charsets.UTF_8)
                android.util.Log.d("PGPEncryptionHelper", "Message bytes length: ${messageBytes.size}")

                val literalStream = literalDataGenerator.open(
                    compressedStream,
                    PGPLiteralData.BINARY,
                    "",
                    messageBytes.size.toLong(),
                    Date()
                )
                android.util.Log.d("PGPEncryptionHelper", "Opened literal data stream")

                literalStream.write(messageBytes)
                android.util.Log.d("PGPEncryptionHelper", "Wrote message to stream")
                
                literalStream.close()
                android.util.Log.d("PGPEncryptionHelper", "Closed literal stream")
                
                compressedDataGenerator.close()
                android.util.Log.d("PGPEncryptionHelper", "Closed compressed data generator")
                
                encryptedDataGenerator.close()
                android.util.Log.d("PGPEncryptionHelper", "Closed encrypted data generator")
                
                armoredOutputStream.close()
                android.util.Log.d("PGPEncryptionHelper", "Closed armored output stream")

                val result = byteArrayOutputStream.toString(Charsets.UTF_8.name())
                android.util.Log.d("PGPEncryptionHelper", "Encryption completed, result length: ${result.length}")
                return result
            } catch (e: Exception) {
                android.util.Log.e("PGPEncryptionHelper", "Error during encryption: ${e.message}", e)
                e.printStackTrace()
                throw e
            }
        } catch (e: Exception) {
            throw Exception("加密失败: ${e.message}", e)
        }
    }

    /**
     * 清理ASCII-armored密钥，提取有效的PGP密钥块
     */
    private fun cleanArmoredKey(keyContent: String): String {
        // 移除所有可能的BOM标记
        var content = keyContent.trim()
        if (content.startsWith("\uFEFF")) {
            content = content.substring(1)
        }
        
        val lines = content.lines()
        val result = StringBuilder()
        var inKeyBlock = false
        var foundBegin = false
        var foundEnd = false
        var addedBeginNewline = false
        
        for (line in lines) {
            val originalLine = line
            val trimmed = line.trim()
            
            // 检测密钥块开始
            if (trimmed.startsWith("-----BEGIN PGP") && trimmed.endsWith("-----")) {
                inKeyBlock = true
                foundBegin = true
                result.append(trimmed).append("\n")
                addedBeginNewline = false
            }
            // 检测密钥块结束
            else if (trimmed.startsWith("-----END PGP") && trimmed.endsWith("-----")) {
                result.append(trimmed).append("\n")
                inKeyBlock = false
                foundEnd = true
                break
            }
            // 在密钥块内的内容
            else if (inKeyBlock) {
                // 如果是空行，在BEGIN后添加一个空行（如果还没有添加）
                if (trimmed.isEmpty()) {
                    if (!addedBeginNewline) {
                        result.append("\n")
                        addedBeginNewline = true
                    }
                    continue
                }
                
                // 跳过元数据行（Version:, Comment:, Charset: 等）
                // 元数据行的格式通常是 "Key: Value" 或 "Key:"
                val isMetadata = trimmed.contains(":") && (
                    trimmed.startsWith("Version:") || 
                    trimmed.startsWith("Comment:") || 
                    trimmed.startsWith("Charset:") ||
                    trimmed.startsWith("Hash:") ||
                    trimmed.matches(Regex("^[A-Za-z][A-Za-z0-9\\s]*:\\s*.*$"))
                )
                
                if (isMetadata) {
                    // 确保BEGIN后有一个空行
                    if (!addedBeginNewline) {
                        result.append("\n")
                        addedBeginNewline = true
                    }
                    continue
                }
                
                // 确保BEGIN后有一个空行（在第一个Base64行之前）
                if (!addedBeginNewline) {
                    result.append("\n")
                    addedBeginNewline = true
                }
                
                // 保留Base64编码的内容
                // Base64字符：A-Z, a-z, 0-9, +, /, = (填充)
                // Base64行可能包含空格，需要移除
                val base64Pattern = Regex("^[A-Za-z0-9+/=]+$")
                val lineWithoutSpaces = trimmed.replace(" ", "").replace("\t", "")
                
                if (lineWithoutSpaces.matches(base64Pattern)) {
                    result.append(lineWithoutSpaces).append("\n")
                } else {
                    // 如果包含其他字符，尝试清理
                    val cleanedLine = lineWithoutSpaces.replace(Regex("[^A-Za-z0-9+/=]"), "")
                    if (cleanedLine.isNotEmpty() && cleanedLine.matches(base64Pattern)) {
                        result.append(cleanedLine).append("\n")
                    } else {
                        // 如果清理后仍然不匹配，记录警告但尝试保留
                        android.util.Log.w("PGPEncryptionHelper", "Suspicious line in key: ${trimmed.take(50)}")
                        if (cleanedLine.isNotEmpty()) {
                            result.append(cleanedLine).append("\n")
                        }
                    }
                }
            }
        }
        
        val cleaned = result.toString()
        
        if (cleaned.isEmpty() || !foundBegin) {
            android.util.Log.e("PGPEncryptionHelper", "Key content preview: ${keyContent.take(300)}")
            throw Exception("无效的公钥格式：未找到有效的PGP密钥块开始标记（-----BEGIN PGP）")
        }
        
        if (!foundEnd) {
            android.util.Log.e("PGPEncryptionHelper", "Key content preview: ${keyContent.take(300)}")
            throw Exception("无效的公钥格式：未找到有效的PGP密钥块结束标记（-----END PGP）")
        }
        
        // 验证格式：必须包含BEGIN和END标记
        if (!cleaned.contains("-----BEGIN PGP") || !cleaned.contains("-----END PGP")) {
            throw Exception("无效的公钥格式：密钥块不完整")
        }
        
        // 确保以换行符结尾
        val finalKey = if (!cleaned.endsWith("\n")) {
            cleaned + "\n"
        } else {
            cleaned
        }
        
        android.util.Log.d("PGPEncryptionHelper", "Cleaned key length: ${finalKey.length}")
        android.util.Log.d("PGPEncryptionHelper", "First 300 chars:\n${finalKey.take(300)}")
        android.util.Log.d("PGPEncryptionHelper", "Last 100 chars:\n${finalKey.takeLast(100)}")
        
        return finalKey
    }

    /**
     * 使用私钥解密消息
     * @param encryptedMessageArmored 加密的消息（ASCII-armored格式）
     * @param privateKeyArmored 自己的私钥内容
     * @param password 私钥密码（如果私钥有密码保护，传入密码；如果无密码，传入null或空字符串）
     * @return 解密后的明文
     */
    fun decrypt(encryptedMessageArmored: String, privateKeyArmored: String, password: String? = null): String {
        try {
            // 清理私钥内容
            val cleanedKey = cleanArmoredKey(privateKeyArmored)
            
            // 读取私钥
            val secretKeyRingCollection = PGPSecretKeyRingCollection(
                PGPUtil.getDecoderStream(ByteArrayInputStream(cleanedKey.toByteArray(Charsets.UTF_8))),
                JcaKeyFingerprintCalculator()
            )

            // 清理加密消息
            val cleanedMessage = cleanArmoredKey(encryptedMessageArmored)
            
            // 读取加密消息
            val objectFactory = PGPObjectFactory(
                PGPUtil.getDecoderStream(ByteArrayInputStream(cleanedMessage.toByteArray(Charsets.UTF_8))),
                JcaKeyFingerprintCalculator()
            )

            var encryptedDataList: PGPEncryptedDataList? = null
            var obj = objectFactory.nextObject()
            while (obj != null) {
                if (obj is PGPEncryptedDataList) {
                    encryptedDataList = obj
                    break
                }
                obj = objectFactory.nextObject()
            }

            encryptedDataList ?: throw Exception("无效的加密数据格式")

            // 查找匹配的私钥 - 简化版本，尝试所有密钥
            var secretKey: PGPSecretKey? = null
            var encryptedData: PGPEncryptedData? = null

            // 获取第一个加密数据项
            val encryptedDataObjects = encryptedDataList.encryptedDataObjects
            if (encryptedDataObjects.hasNext()) {
                encryptedData = encryptedDataObjects.next() as PGPEncryptedData
            }

            encryptedData ?: throw Exception("未找到加密数据")

            // 尝试所有私钥
            val keyRings = secretKeyRingCollection.keyRings
            while (keyRings.hasNext() && secretKey == null) {
                val keyRing = keyRings.next() as PGPSecretKeyRing
                val secretKeys = keyRing.secretKeys
                while (secretKeys.hasNext() && secretKey == null) {
                    secretKey = secretKeys.next() as PGPSecretKey
                }
            }

            secretKey ?: throw Exception("未找到匹配的私钥")

            // 提取私钥（支持密码保护）
            val passwordChars = password?.toCharArray() ?: "".toCharArray()
            val privateKey = try {
                secretKey.extractPrivateKey(
                    org.bouncycastle.openpgp.operator.jcajce.JcePBESecretKeyDecryptorBuilder()
                        .setProvider("BC")
                        .build(passwordChars)
                )
            } catch (e: Exception) {
                // 如果密码错误，尝试空密码（向后兼容）
                if (password != null && password.isNotEmpty()) {
                    throw Exception("私钥密码错误或私钥未加密")
                }
                secretKey.extractPrivateKey(
                    org.bouncycastle.openpgp.operator.jcajce.JcePBESecretKeyDecryptorBuilder()
                        .setProvider("BC")
                        .build("".toCharArray())
                )
            }

            // 创建解密器
            val dataDecryptorFactory = org.bouncycastle.openpgp.operator.jcajce.JcePublicKeyDataDecryptorFactoryBuilder()
                .setProvider("BC")
                .build(privateKey)

            // 解密数据 - 使用PGPPublicKeyEncryptedData
            val publicKeyEncryptedData = encryptedData as? org.bouncycastle.openpgp.PGPPublicKeyEncryptedData
                ?: throw Exception("不支持的加密数据类型")
            
            val decryptedStream = publicKeyEncryptedData.getDataStream(dataDecryptorFactory)

            val decryptedFactory = PGPObjectFactory(decryptedStream, JcaKeyFingerprintCalculator())
            var decryptedObj: Any? = decryptedFactory.nextObject()

            // 处理压缩数据
            if (decryptedObj is PGPCompressedData) {
                val compressedFactory = PGPObjectFactory(
                    decryptedObj.dataStream,
                    JcaKeyFingerprintCalculator()
                )
                decryptedObj = compressedFactory.nextObject()
            }

            // 读取字面数据
            if (decryptedObj is PGPLiteralData) {
                val inputStream = decryptedObj.inputStream
                val buffer = ByteArrayOutputStream()
                inputStream.copyTo(buffer)
                inputStream.close()
                decryptedStream.close()

                return String(buffer.toByteArray(), Charsets.UTF_8)
            } else {
                throw Exception("无效的消息格式")
            }
        } catch (e: Exception) {
            throw Exception("解密失败: ${e.message}", e)
        }
    }
}
