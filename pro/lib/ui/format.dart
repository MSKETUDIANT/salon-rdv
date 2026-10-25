import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Formats d'affichage, alignés sur le site (web/lib/format.ts).

// « 35 DT » quand les millimes sont nuls, sinon « 10,500 DT ».
String formatPrix(double prix) {
  final millimes = (prix * 1000).round();
  if (millimes % 1000 == 0) return '${millimes ~/ 1000} DT';
  final dinars = millimes ~/ 1000;
  final reste = (millimes % 1000).toString().padLeft(3, '0');
  return '$dinars,$reste DT';
}

// Prix saisi par le gérant : « 35 », « 10,5 » ou « 10.500 » ; au millime
// près, jamais négatif. null si la saisie est invalide.
double? lirePrix(String saisie) {
  final texte = saisie.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(texte)) return null;
  return double.parse(texte);
}

// Durée saisie en minutes : entier strictement positif, au plus 12 h.
int? lireDuree(String saisie) {
  final duree = int.tryParse(saisie.trim());
  if (duree == null || duree <= 0 || duree > 720) return null;
  return duree;
}

// « 45 min », « 1 h », « 1 h 30 ».
String formatDuree(int minutes) {
  if (minutes < 60) return '$minutes min';
  final heures = minutes ~/ 60;
  final reste = minutes % 60;
  return reste == 0
      ? '$heures h'
      : '$heures h ${reste.toString().padLeft(2, '0')}';
}

// « 09:00 ».
String formatHeure(TimeOfDay h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

int minutesDuJour(TimeOfDay h) => h.hour * 60 + h.minute;

const nomsJours = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

// « Lundi 7 janvier, 09:00 ».
String formatDateHeure(DateTime d) {
  final texte = DateFormat("EEEE d MMMM, HH:mm", 'fr').format(d);
  return texte[0].toUpperCase() + texte.substring(1);
}

// « Lundi 7 janvier ».
String formatDate(DateTime d) {
  final texte = DateFormat('EEEE d MMMM', 'fr').format(d);
  return texte[0].toUpperCase() + texte.substring(1);
}
