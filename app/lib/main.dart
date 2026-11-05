import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'ui/adaptive.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Cache d'images borné (ADR 0028) : 48 Mo suffisent aux couvertures et pages de livres, sur 3,7 Go de RAM.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  final state = await AppState.load();
  // Appli quittée ou écran éteint : la voix se tait et la musique se met en pause ; elle reprend au retour.
  AppLifecycleListener(
    onHide: state.voice.pauseAll,
    onShow: state.voice.resumeMusic,
  );
  runApp(AppScope(state: state, child: const ZanakiAntsa()));
}

class ZanakiAntsa extends StatelessWidget {
  const ZanakiAntsa({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "Zanak'i Antsa",
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppScope.of(context).universe),
        // La police du système est suivie, mais plafonnée selon l'écran (ADR 0052) : les écrans d'enfants ont des boutons
        // et des cartes à taille fixe, qu'une police à 200 % ferait déborder.
        builder: (context, child) {
          final screen = MediaQuery.sizeOf(context);
          return MediaQuery.withClampedTextScaling(minScaleFactor: 1.0, maxScaleFactor: maxFontScale(screen), child: child!);
        },
        home: const HomePage(),
      );
}
