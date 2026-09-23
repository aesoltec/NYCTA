# Configuration native requise (Android / iOS)

Le projet livré contient le code Dart. Avant le premier build, generez les
dossiers natifs une fois :

```bash
flutter create . --org com.votreentreprise --project-name pme_gestion
```

## Android — android/app/src/main/AndroidManifest.xml

Ajouter DANS <manifest> :
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

Ajouter AUSSI dans <manifest> (visibilite des apps de partage, Android 11+) :
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.SEND" />
    <data android:mimeType="*/*" />
  </intent>
</queries>
```

## iOS — ios/Runner/Info.plist

Ajouter (sinon plantage a la photo/signature) :
```xml
<key>NSCameraUsageDescription</key>
<string>Photographier les produits et les documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choisir les photos de produits et le logo</string>
```
