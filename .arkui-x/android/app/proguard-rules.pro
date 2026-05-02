# ==========================================
# ArkUI-X 跨平台 Android 壳工程混淆规则
# ==========================================

# 1. 保护 ohos 包下的所有类和成员不被混淆
# 这是 ArkUI-X 引擎在 Android 侧的基础框架，C++ 层会通过 JNI 强依赖这些名字
-keep class ohos.** { *; }
-keep interface ohos.** { *; }
-dontwarn ohos.**

# 2. 保护所有的 native 方法不被混淆
# 确保 Java 层声明的 native 方法名字保持原样，否则 .so 库绑定不上
-keepclasseswithmembernames class * {
    native <methods>;
}

# 3. 保护 Android 原生组件生命周期和反射调用的基础类库
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# 4. 保护包含特定注解的类（如有被底层用到）
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# 5. 如果你引入了其他的第三方 jar/aar 包并且通过 JNI 调用了它们，也需要在这里加 -keep