import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/photo_salon.dart';

// Photo du salon (#105, options 1A et 2a de Sparta), depuis la ligne « Photo
// du salon » de l'onglet Salon du gérant : aperçu tel que dans le bandeau de
// l'accueil, « Changer la photo » (galerie ou appareil photo), « Retirer la
// photo » pour revenir à l'image par défaut. L'écran reste ouvert après un
// envoi : l'aperçu montre la nouvelle photo.
class EcranPhotoSalon extends StatefulWidget {
  const EcranPhotoSalon({
    super.key,
    required this.salon,
    this.choisir = choisirPhoto,
  });

  final DepotSalon salon;
  // Choix de l'image sur le téléphone ; remplacé dans les tests.
  final Future<PhotoChoisie?> Function(ImageSource source) choisir;

  @override
  State<EcranPhotoSalon> createState() => _EcranPhotoSalonState();
}

// Image choisie : octets et type MIME.
typedef PhotoChoisie = ({Uint8List octets, String type});

// Image réduite à 1600 px de large, JPEG de qualité 80 (environ 200 à 400 Ko).
// null : choix abandonné.
Future<PhotoChoisie?> choisirPhoto(ImageSource source) async {
  final fichier = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (fichier == null) return null;
  final nom = fichier.name.toLowerCase();
  final type =
      fichier.mimeType ??
      (nom.endsWith('.png')
          ? 'image/png'
          : nom.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg');
  return (octets: await fichier.readAsBytes(), type: type);
}

class _EcranPhotoSalonState extends State<EcranPhotoSalon> {
  int _version = 0;
  bool _enCours = false;
  String? _erreur;

  Future<void> _changer() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Couleurs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(rayon)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: Espaces.s2),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final PhotoChoisie? photo;
    try {
      photo = await widget.choisir(source);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erreur = source == ImageSource.camera
              ? 'Appareil photo indisponible.'
              : 'Galerie indisponible.',
        );
      }
      return;
    }
    if (photo == null || !mounted) return;
    await _action(
      () => widget.salon.changerPhoto(photo!.octets, photo.type),
      'Photo enregistrée.',
    );
  }

  Future<void> _retirer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer la photo ?'),
        content: const Text('L\'image par défaut la remplacera.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _action(widget.salon.retirerPhoto, 'Photo retirée.');
  }

  Future<void> _action(Future<void> Function() action, String message) async {
    setState(() {
      _erreur = null;
      _enCours = true;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _version++;
      });
      confirmer(context, message);
    } on ErreurSalon catch (erreur) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = erreur.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo du salon')),
      body: ListeCharte(
        enfants: [
          Chargement<String?>(
            key: ValueKey(_version),
            lire: () async => (await widget.salon.identite()).photo,
            afficher: (context, photo, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Même cadrage que le bandeau de l'accueil, en plus grand.
                PhotoSalon(adresse: photo, hauteur: 180),
                const SizedBox(height: Espaces.s2),
                Text(
                  photo == null
                      ? 'Image par défaut. Votre photo s\'affichera en haut de l\'accueil, pour toute l\'équipe.'
                      : 'Affichée en haut de l\'accueil de l\'app.',
                  style: textes.bodySmall,
                ),
                const SizedBox(height: Espaces.s6),
                if (_erreur != null) ...[
                  MessageErreur(_erreur!),
                  const SizedBox(height: Espaces.s3),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Bouton(
                    libelle: 'Changer la photo',
                    libelleChargement: 'Enregistrement…',
                    chargement: _enCours,
                    surAppui: _changer,
                  ),
                ),
                if (photo != null) ...[
                  const SizedBox(height: Espaces.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _enCours ? null : _retirer,
                      child: const Text('Retirer la photo'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
