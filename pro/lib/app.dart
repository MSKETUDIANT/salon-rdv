import 'package:flutter/material.dart';

import 'data/session.dart';
import 'features/espaces/porte.dart';
import 'ui/charte.dart';

class AppPro extends StatelessWidget {
  const AppPro({super.key, required this.auth, required this.roles});

  final ServiceAuth auth;
  final DepotRoles roles;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salon RDV Pro',
      debugShowCheckedModeBanner: false,
      theme: themeCharte(),
      locale: const Locale('fr'),
      home: Porte(auth: auth, roles: roles),
    );
  }
}
