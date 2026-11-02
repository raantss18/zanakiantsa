# ML Kit découvre ses composants par réflexion : garder ses registrars (plantage au démarrage sinon).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
# WorkManager (utilisé par ML Kit pour télécharger les modèles) instancie sa base Room par réflexion.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
