import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/config.dart';
import 'data/session.dart';
import 'ui/charte.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final manquantes = Config.manquantes();
  if (manquantes.isNotEmpty) {
    runApp(ConfigManquante(variables: manquantes));
    return;
  }

  const config = Config.depuisLancement;
  // La clé anon (legacy) sert de clé publishable, comme sur le site.
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );
  final client = Supabase.instance.client;
  runApp(
    AppPro(
      auth: AuthSupabase(client),
      roles: RolesSupabase(client, config.salonId),
    ),
  );
}

// Lancement sans --dart-define : on le dit plutôt que d'échouer plus loin.
class ConfigManquante extends StatelessWidget {
  const ConfigManquante({super.key, required this.variables});

  final List<String> variables;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeCharte(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(Espaces.s4),
          child: Center(
            child: Text(
              'Configuration manquante : ${variables.join(', ')}.\n'
              'Lancer avec --dart-define-from-file=config/local.json (modèle : config/exemple.json).',
            ),
          ),
        ),
      ),
    );
  }
}
