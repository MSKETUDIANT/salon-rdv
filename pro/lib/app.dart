import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/planning.dart';
import 'data/salon.dart';
import 'data/session.dart';
import 'features/espaces/porte.dart';
import 'ui/charte.dart';

class AppPro extends StatelessWidget {
  const AppPro({
    super.key,
    required this.auth,
    required this.roles,
    required this.salon,
    required this.planning,
  });

  final ServiceAuth auth;
  final DepotRoles roles;
  final DepotSalon salon;
  final DepotPlanning planning;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salon RDV Pro',
      debugShowCheckedModeBanner: false,
      theme: themeCharte(),
      // Sélecteurs de date et d'heure en français, sur 24 h.
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Porte(auth: auth, roles: roles, salon: salon, planning: planning),
    );
  }
}
