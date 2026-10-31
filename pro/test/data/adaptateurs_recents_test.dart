import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/data/session.dart';

import '../doublures/fausse_api.dart';

// Adaptateurs Supabase ajoutés après #47 (vérification BNF-6, #12) : client
// de passage (#103), client arrivé (#102), photo du salon (#105), nom (#106),
// mot de passe (#107), mot de passe oublié (#39). Même méthode que
// adaptateurs_test.dart : fausse API, paramètres envoyés, erreurs traduites.

const salonId = 's1';
late FausseApi api;

Map<String, Object?> corps(String chemin, {int rang = 0}) =>
    jsonDecode(api.vers(chemin)[rang].body) as Map<String, Object?>;

Future<void> connecter() async {
  api.repondreAuth('POST', 'token', FausseApi.session());
  await api.client.auth.signInWithPassword(
    email: 'amira@salon.test',
    password: 'motdepasse',
  );
}

// Erreur d'Auth au format de Supabase.
Map<String, Object?> refusAuth(String code, int statut) => {
  'code': statut,
  'error_code': code,
  'msg': 'refus',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    api = FausseApi();
    api.salon();
  });

  group('PlanningSupabase', () {
    late PlanningSupabase planning;
    setUp(() => planning = PlanningSupabase(api.client, salonId));

    test('photo du salon : adresse publique, null sans photo', () async {
      api.repondre('GET', 'salons', {'photo': 's1/p.jpg'});
      expect(
        await planning.photoDuSalon(),
        'http://api.test/storage/v1/object/public/salons/s1/p.jpg',
      );
      api.repondre('GET', 'salons', {'photo': null});
      expect(await planning.photoDuSalon(), isNull);
    });

    test('nom : une ligne modifiée, sinon refus de la RLS', () async {
      api.repondre('PATCH', 'utilisateurs', [
        {'id': 'u1'},
      ]);
      await planning.modifierMonNom('Amira Ben Salah');
      expect(corps('utilisateurs'), {'nom': 'Amira Ben Salah'});

      api.repondre('PATCH', 'utilisateurs', <Object>[]);
      expect(
        () => planning.modifierMonNom('Autre'),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            'Action non autorisée avec ce compte.',
          ),
        ),
      );
    });

    test('arrivée : marquer_arrivee(), refus traduits', () async {
      api.repondre('POST', 'rpc/marquer_arrivee', [
        {'id': 'r1', 'arrive_le': null},
      ]);
      await planning.marquerArrivee('r1', arrive: false);
      expect(corps('rpc/marquer_arrivee'), {
        'p_reservation': 'r1',
        'p_arrive': false,
      });

      api.refuser(
        'POST',
        'rpc/marquer_arrivee',
        'PT409',
        message: 'Arrivée possible seulement le jour du rendez-vous',
      );
      await expectLater(
        planning.marquerArrivee('r1'),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            'Arrivée possible seulement le jour du rendez-vous.',
          ),
        ),
      );
    });

    test('client arrivé : « absent » refusé, message clair', () async {
      api.refuser(
        'PATCH',
        'reservations',
        'PT409',
        message: "Client arrivé : annulez d'abord son arrivée",
      );
      await expectLater(
        planning.cloturer('r1', StatutRendezVous.absent),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            "Client arrivé : annulez d'abord son arrivée.",
          ),
        ),
      );
    });

    test('prestations actives : filtre, tri, numeric en double', () async {
      api.repondre('GET', 'prestations', [
        {
          'id': 'p1',
          'nom': 'Coupe',
          'prix': 20,
          'duree_minutes': 30,
          'active': true,
        },
      ]);
      final prestations = await planning.prestationsActives();
      expect(prestations.single.prix, 20.0);
      final url = api.vers('prestations').single.url.queryParameters;
      expect(url['salon_id'], 'eq.$salonId');
      expect(url['active'], 'eq.true');
      expect(url['order'], startsWith('nom.asc'));
    });

    test('créneaux libres : une heure par créneau, heure du salon', () async {
      api.repondre('POST', 'rpc/creneaux_disponibles', [
        {
          'coiffeur_id': 'c1',
          'debut': '2030-01-07T09:00:00+00:00',
          'fin': '2030-01-07T09:30:00+00:00',
        },
        {
          'coiffeur_id': 'c2',
          'debut': '2030-01-07T09:00:00+00:00',
          'fin': '2030-01-07T09:30:00+00:00',
        },
      ]);
      final creneaux = await planning.creneauxLibres(
        'p1',
        DateTime(2030, 1, 7),
        coiffeurId: 'c1',
      );
      expect(creneaux, hasLength(1));
      expect(creneaux.single.debut, DateTime(2030, 1, 7, 10));
      expect(corps('rpc/creneaux_disponibles'), {
        'p_prestation': 'p1',
        'p_du': '2030-01-07',
        'p_au': '2030-01-07',
        'p_coiffeur': 'c1',
      });
    });
  });

  group('SalonSupabase', () {
    late SalonSupabase salon;
    setUp(() => salon = SalonSupabase(api.client, salonId));

    test('identité : adresse publique de la photo', () async {
      api.repondre('GET', 'salons', {
        'nom': 'Salon de démo',
        'adresse': null,
        'photo': 's1/p.jpg',
      });
      expect(
        (await salon.identite()).photo,
        'http://api.test/storage/v1/object/public/salons/s1/p.jpg',
      );
    });

    test(
      "délai d'annulation : lu avec l'identité, réglé par la fonction",
      () async {
        api.repondre('GET', 'salons', {
          'nom': 'Salon de démo',
          'adresse': null,
          'photo': null,
          'delai_annulation_minutes': 120,
        });
        expect((await salon.identite()).delaiAnnulationMinutes, 120);

        api.repondre('POST', 'rpc/definir_delai_annulation', [
          {'delai_annulation_minutes': 1440},
        ]);
        await salon.definirDelaiAnnulation(1440);
        expect(corps('rpc/definir_delai_annulation'), {
          'p_salon': salonId,
          'p_minutes': 1440,
        });
      },
    );

    test("invitations (#145) : en attente seulement, du salon", () async {
      api.repondre('GET', 'invitations', [
        {'id': 'i1', 'nom': 'Nour Ben', 'email': 'nour@salon.test'},
      ]);
      final invitations = await salon.invitations();
      expect(invitations.single.nom, 'Nour Ben');
      expect(invitations.single.email, 'nour@salon.test');
      final url = api.requetes.last.url.queryParameters;
      expect(url['salon_id'], 'eq.$salonId');
      expect(url['acceptee_le'], 'is.null');
    });

    test("inviter (#145) : invité ou ajouté selon la base", () async {
      api.repondre('POST', 'rpc/inviter_coiffeur', [
        {'resultat': 'invite'},
      ]);
      expect(
        await salon.inviterCoiffeur(nom: 'Nour', email: 'nour@salon.test'),
        isFalse,
      );
      expect(corps('rpc/inviter_coiffeur'), {
        'p_salon': salonId,
        'p_email': 'nour@salon.test',
        'p_nom': 'Nour',
      });

      api.repondre('POST', 'rpc/inviter_coiffeur', [
        {'resultat': 'ajoute'},
      ]);
      expect(
        await salon.inviterCoiffeur(nom: 'Salma', email: 'salma@salon.test'),
        isTrue,
      );
    });

    test("inviter (#145) : refus de la base, message affichable", () async {
      api.refuser(
        'POST',
        'rpc/inviter_coiffeur',
        'PT400',
        message: 'Adresse e-mail invalide',
      );
      await expectLater(
        salon.inviterCoiffeur(nom: 'X', email: 'x'),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            'Adresse e-mail invalide.',
          ),
        ),
      );

      api.refuser('POST', 'rpc/inviter_coiffeur', 'PT409');
      await expectLater(
        salon.inviterCoiffeur(nom: 'Amira', email: 'amira@salon.test'),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            "Déjà dans l'équipe.",
          ),
        ),
      );
    });

    test("annuler une invitation (#145) : par la fonction", () async {
      api.repondre('POST', 'rpc/annuler_invitation', null);
      await salon.annulerInvitation('i1');
      expect(corps('rpc/annuler_invitation'), {'p_invitation': 'i1'});
    });

    test(
      "téléphone (#129) : lu avec l'identité, réglé par la fonction",
      () async {
        api.repondre('GET', 'salons', {
          'nom': 'Salon de démo',
          'adresse': null,
          'telephone': '71 234 567',
          'photo': null,
          'delai_annulation_minutes': 0,
        });
        expect((await salon.identite()).telephone, '71 234 567');

        api.repondre('POST', 'rpc/definir_telephone_salon', [
          {'telephone': '+216 71 234 567'},
        ]);
        await salon.definirTelephone('+216 71 234 567');
        expect(corps('rpc/definir_telephone_salon'), {
          'p_salon': salonId,
          'p_telephone': '+216 71 234 567',
        });
      },
    );

    test('téléphone refusé par la base (PT400) : message du champ', () async {
      api.refuser('POST', 'rpc/definir_telephone_salon', 'PT400');
      await expectLater(
        salon.definirTelephone('12'),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            messageTelephoneInvalide,
          ),
        ),
      );
    });

    test("horaires d'ouverture (#129) : lus par horaires_du_salon", () async {
      api.repondre('POST', 'rpc/horaires_du_salon', [
        {'jour_semaine': 1, 'ouverture': '09:00:00', 'fermeture': '19:00:00'},
        {'jour_semaine': 6, 'ouverture': '10:00:00', 'fermeture': '18:30:00'},
      ]);
      final ouverture = await salon.horairesOuverture();
      expect(corps('rpc/horaires_du_salon'), {'p_salon': salonId});
      expect(ouverture.keys, [1, 6]);
      expect(ouverture[6], (
        const TimeOfDay(hour: 10, minute: 0),
        const TimeOfDay(hour: 18, minute: 30),
      ));
    });

    test(
      'changer la photo : envoi, enregistrement, ancien fichier supprimé',
      () async {
        api.repondreStockage('POST', 'object/salons/s1/*', {'Key': 'ok'});
        api.repondre('POST', 'rpc/definir_photo_salon', [
          {'ancienne_photo': 's1/ancienne.jpg'},
        ]);
        api.repondreStockage('DELETE', 'object/salons', <Object>[]);

        await salon.changerPhoto(Uint8List.fromList([1, 2, 3]), 'image/png');

        final envoi = api.versStockage('object/salons/s1/').single;
        expect(envoi.method, 'POST');
        expect(envoi.url.path, endsWith('.png'));
        // Envoi en multipart : le type du fichier est dans le corps.
        expect(latin1.decode(envoi.bodyBytes), contains('image/png'));
        final chemin = envoi.url.path.split('/object/salons/').last;
        expect(corps('rpc/definir_photo_salon'), {
          'p_salon': salonId,
          'p_chemin': chemin,
        });
        final suppression = api
            .versStockage('object/salons')
            .where((r) => r.method == 'DELETE')
            .single;
        expect(jsonDecode(suppression.body), {
          'prefixes': ['s1/ancienne.jpg'],
        });
      },
    );

    test("photo trop lourde : refus de l'API Storage traduit", () async {
      api.repondreStockage('POST', 'object/salons/s1/*', {
        'statusCode': '413',
        'error': 'Payload too large',
        'message': 'trop lourde',
      }, statut: 413);
      await expectLater(
        salon.changerPhoto(Uint8List.fromList([1]), 'image/jpeg'),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            'Photo trop lourde : 5 Mo au plus.',
          ),
        ),
      );
      expect(api.vers('rpc/definir_photo_salon'), isEmpty);
    });

    test('enregistrement refusé : le fichier envoyé est retiré', () async {
      api.repondreStockage('POST', 'object/salons/s1/*', {'Key': 'ok'});
      api.refuser('POST', 'rpc/definir_photo_salon', 'PT403', statut: 403);
      api.repondreStockage('DELETE', 'object/salons', <Object>[]);

      await expectLater(
        salon.changerPhoto(Uint8List.fromList([1]), 'image/jpeg'),
        throwsA(isA<ErreurSalon>()),
      );
      final envoye = api
          .versStockage('object/salons/s1/')
          .single
          .url
          .path
          .split('/object/salons/')
          .last;
      final suppression = api
          .versStockage('object/salons')
          .where((r) => r.method == 'DELETE')
          .single;
      expect(jsonDecode(suppression.body), {
        'prefixes': [envoye],
      });
    });

    test('retirer la photo : chemin null, ancien fichier supprimé', () async {
      api.repondre('POST', 'rpc/definir_photo_salon', [
        {'ancienne_photo': 's1/p.jpg'},
      ]);
      api.repondreStockage('DELETE', 'object/salons', <Object>[]);
      await salon.retirerPhoto();
      expect(corps('rpc/definir_photo_salon'), {
        'p_salon': salonId,
        'p_chemin': null,
      });
      expect(api.versStockage('object/salons'), hasLength(1));
    });

    test("messages des refus de l'API Storage", () {
      expect(messageErreurPhoto('413'), 'Photo trop lourde : 5 Mo au plus.');
      expect(
        messageErreurPhoto('415'),
        'Format non accepté : JPEG, PNG ou WebP.',
      );
      expect(messageErreurPhoto('403'), 'Photo réservée au gérant du salon.');
      expect(messageErreurPhoto(null), messageErreurInconnue);
    });
  });

  group('AuthSupabase', () {
    late AuthSupabase auth;
    setUp(() => auth = AuthSupabase(api.client));

    test('changer de mot de passe : actuel vérifié, puis remplacé', () async {
      await connecter();
      api.repondreAuth('PUT', 'user', FausseApi.session()['user']);
      expect(await auth.changerMotDePasse('motdepasse', 'nouveau-mdp'), isNull);
      final remplacement = api.requetes.last;
      expect(remplacement.url.path, '/auth/v1/user');
      expect(jsonDecode(remplacement.body)['password'], 'nouveau-mdp');
    });

    test('changer de mot de passe : actuel faux, trop faible', () async {
      await connecter();
      api.repondreAuth(
        'POST',
        'token',
        refusAuth('invalid_credentials', 400),
        statut: 400,
      );
      expect(
        await auth.changerMotDePasse('faux', 'nouveau-mdp'),
        ErreurMotDePasse.actuelIncorrect,
      );

      api.repondreAuth('POST', 'token', FausseApi.session());
      api.repondreAuth(
        'PUT',
        'user',
        refusAuth('same_password', 422),
        statut: 422,
      );
      expect(
        await auth.changerMotDePasse('motdepasse', 'motdepasse2'),
        ErreurMotDePasse.identique,
      );
    });

    test("sans compte connecté : pas d'appel, refus neutre", () async {
      expect(await auth.changerMotDePasse('a', 'b'), ErreurMotDePasse.autre);
      expect(api.requetes, isEmpty);
    });

    test(
      'mot de passe oublié : envoi neutre, seule la limite est dite',
      () async {
        api.repondreAuth('POST', 'recover', <String, Object?>{});
        expect(await auth.envoyerCodeOubli('amira@salon.test'), isNull);
        expect(jsonDecode(api.requetes.last.body)['email'], 'amira@salon.test');

        api.repondreAuth(
          'POST',
          'recover',
          refusAuth('over_email_send_rate_limit', 429),
          statut: 429,
        );
        expect(
          await auth.envoyerCodeOubli('amira@salon.test'),
          ErreurOubli.tropDeDemandes,
        );

        // Toute autre erreur reste neutre : rien ne dit si le compte existe.
        api.repondreAuth(
          'POST',
          'recover',
          refusAuth('user_not_found', 400),
          statut: 400,
        );
        expect(await auth.envoyerCodeOubli('inconnu@salon.test'), isNull);
      },
    );

    test(
      'mot de passe oublié : code vérifié (recovery), puis remplacé',
      () async {
        api.repondreAuth('POST', 'verify', FausseApi.session());
        api.repondreAuth('PUT', 'user', FausseApi.session()['user']);
        expect(
          await auth.reinitialiserMotDePasse(
            'amira@salon.test',
            '123456',
            'nouveau-mdp',
          ),
          isNull,
        );
        final verification = api.requetes.firstWhere(
          (r) => r.url.path == '/auth/v1/verify',
        );
        expect(jsonDecode(verification.body), containsPair('type', 'recovery'));
        expect(jsonDecode(verification.body), containsPair('token', '123456'));
        expect(api.requetes.last.url.path, '/auth/v1/user');
      },
    );

    test('mot de passe oublié : code incorrect ou expiré', () async {
      api.repondreAuth(
        'POST',
        'verify',
        refusAuth('otp_expired', 403),
        statut: 403,
      );
      expect(
        await auth.reinitialiserMotDePasse(
          'amira@salon.test',
          '000000',
          'nouveau-mdp',
        ),
        ErreurOubli.codeInvalide,
      );
      expect(api.requetes.where((r) => r.url.path == '/auth/v1/user'), isEmpty);
    });

    test(
      "première connexion (#145) : code demandé, compte créé si besoin",
      () async {
        api.repondreAuth('POST', 'otp', <String, Object?>{});
        expect(
          await auth.envoyerCodePremiereConnexion('nour@salon.test'),
          isNull,
        );
        final envoi = jsonDecode(api.requetes.last.body);
        expect(envoi['email'], 'nour@salon.test');
        expect(envoi['create_user'], isTrue);

        // Neutre, sauf la limite d'envoi.
        api.repondreAuth(
          'POST',
          'otp',
          refusAuth('over_email_send_rate_limit', 429),
          statut: 429,
        );
        expect(
          await auth.envoyerCodePremiereConnexion('nour@salon.test'),
          ErreurOubli.tropDeDemandes,
        );
      },
    );

    test(
      "première connexion (#145) : code vérifié (email), mot de passe choisi",
      () async {
        api.repondreAuth('POST', 'verify', FausseApi.session());
        api.repondreAuth('PUT', 'user', FausseApi.session()['user']);
        expect(
          await auth.creerAcces('nour@salon.test', '123456', 'mon-mdp-nour'),
          isNull,
        );
        final verification = api.requetes.firstWhere(
          (r) => r.url.path == '/auth/v1/verify',
        );
        expect(jsonDecode(verification.body), containsPair('type', 'email'));
        expect(jsonDecode(verification.body), containsPair('token', '123456'));
        expect(jsonDecode(api.requetes.last.body)['password'], 'mon-mdp-nour');

        api.repondreAuth(
          'POST',
          'verify',
          refusAuth('otp_expired', 403),
          statut: 403,
        );
        expect(
          await auth.creerAcces('nour@salon.test', '000000', 'mon-mdp-nour'),
          ErreurOubli.codeInvalide,
        );
      },
    );
  });
}
