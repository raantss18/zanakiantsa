import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = await AppState.load();
  runApp(AppScope(state: state, child: const ZanakiAntsa()));
}

class ZanakiAntsa extends StatelessWidget {
  const ZanakiAntsa({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "Zanak'i Antsa",
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppScope.of(context).universe),
        home: const HomePage(),
      );
}
