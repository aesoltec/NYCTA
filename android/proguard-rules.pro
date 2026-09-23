# ============================================================
# PME Gestion — Règles ProGuard/R8 (obfuscation release Android)
# Les classes Dart sont déjà obfusquées par --obfuscate ;
# ces règles protègent la couche native des plugins.
# ============================================================

# ---- Flutter ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ---- Supabase / postgrest / realtime (sérialisation réflexive) ----
-keep class com.pme_gestion.** { *; }
-keep class **$$serializer { *; }
-keepclasseswithmembernames class * { native <methods>; }
-dontwarn com.pme_gestion.**
-keepattributes Signature, *Annotation*, EnclosingMethod
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ---- flutter_secure_storage ----
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ---- flutter_local_notifications ----
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ---- image_picker / file_picker / share_plus / printing ----
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class net.nfet.flutter.printing.** { *; }

# ---- notifications / connectivity / path_provider ----
-keep class com.dexterous.** { *; }
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# ---- signature (dessin) / fl_chart / sync ----
-keep class com.hand_signature.** { *; }
-dontwarn com.hand_signature.**

# ---- Génériques sérialisation JSON ----
-keepclassmembers class * {
    *** get*();
    void set*(***);
}
