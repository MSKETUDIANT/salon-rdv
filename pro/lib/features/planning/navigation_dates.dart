import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/planning.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';

// Barre de navigation entre les jours (ou les semaines) : précédent, libellé,
// suivant, et « Aujourd'hui ».
class NavigationDates extends StatelessWidget {
  const NavigationDates({
    super.key,
    required this.libelle,
    required this.surPrecedent,
    required this.surSuivant,
    required this.surAujourdhui,
    required this.unite,
  });

  final String libelle;
  final VoidCallback surPrecedent;
  final VoidCallback surSuivant;
  final VoidCallback? surAujourdhui;
  // « jour » ou « semaine », pour les libellés lus par TalkBack.
  final String unite;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: surPrecedent,
              tooltip: unite == 'jour'
                  ? 'Jour précédent'
                  : 'Semaine précédente',
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  libelle,
                  style: textes.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            IconButton(
              onPressed: surSuivant,
              tooltip: unite == 'jour' ? 'Jour suivant' : 'Semaine suivante',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (surAujourdhui != null)
          Center(
            child: TextButton(
              onPressed: surAujourdhui,
              child: const Text('Revenir à aujourd\'hui'),
            ),
          ),
      ],
    );
  }
}

// Bande des jours (#80) : la semaine du jour affiché, du lundi au dimanche ;
// un toucher change de jour. Jour choisi en pastille grise, chiffre en vert ;
// aujourd'hui marqué d'un point vert. Toute la largeur : 7 cases d'au moins
// 44 px sur un écran de 360 px.
class BandeJours extends StatelessWidget {
  const BandeJours({
    super.key,
    required this.jour,
    required this.aujourdhui,
    required this.surChoix,
  });

  final DateTime jour;
  final DateTime aujourdhui;
  final ValueChanged<DateTime> surChoix;

  static const _lettres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final lundi = jour.subtract(Duration(days: jour.weekday - 1));
    final dimanche = DateTime(lundi.year, lundi.month, lundi.day + 6);
    // Semaine à cheval sur deux mois : « octobre – novembre » au-dessus.
    final mois = DateFormat.MMMM('fr');
    final rangee = Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final d = DateTime(lundi.year, lundi.month, lundi.day + i);
                final choisi = memeJour(d, jour);
                final auj = memeJour(d, aujourdhui);
                return Semantics(
                  button: true,
                  selected: choisi,
                  label: auj ? '${formatDate(d)}, aujourd\'hui' : formatDate(d),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => surChoix(d),
                    borderRadius: BorderRadius.circular(rayon),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 64),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: choisi ? Couleurs.separateur : null,
                        borderRadius: BorderRadius.circular(rayon),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_lettres[i], style: textes.bodySmall),
                          Text(
                            '${d.day}',
                            style: textes.labelLarge!.copyWith(
                              color: choisi ? Couleurs.accent : Couleurs.texte,
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: auj ? Couleurs.accent : null,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
    if (lundi.month == dimanche.month) return rangee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${mois.format(lundi)} – ${mois.format(dimanche)}',
          textAlign: TextAlign.center,
          style: textes.bodySmall,
        ),
        rangee,
      ],
    );
  }
}
