import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/data/session.dart';

import '../doublures/fausse_api.dart';

// Adaptateurs Supabase (#47) avec une fausse API : lecture des lignes (dates à
// l'heure du salon, numeric en double), paramètres envoyés, traduction des
// erreurs, refus silencieux de la RLS (0 ligne modifiée). Les règles
// elles-mêmes (RLS, contraintes) sont testées en SQL (supabase/tests/).

const salonId = 's1';
late FausseApi api;

Map<String, Object?> corps(String chemin, {int rang = 0}) =>
    jsonDecode(api.vers(chemin)[rang].body) as Map<String, Object?>;

Future<void> connecter({String id = 'u1'}) async {
  api.repondreAuth('POST', 'token', FausseApi.session(id: id));
  await api.client.auth.signInWithPassword(
    email: 'amira@salon.test',
    password: 'motdepasse',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    api = FausseApi();
    api.salon();
  });

  group('PlanningSupabase', () {
    late PlanningSupabase planning;
    setUp(() => planning = PlanningSupabase(api.client, salonId));

    test(
      'période : rendez-vous, absences et plages à l\'heure du salon',
      () async {
        api.repondre('POST', 'rpc/planning', [
          {
            'id': 'r1',
            'coiffeur_id': 'c1',
            'debut': '2030-01-07T08:00:00+00:00',
            'fin': '2030-01-07T08:30:00+00:00',
            'statut': 'terminee',
            'prestation': 'Coupe',
            'duree_minutes': 30,
            'client_nom': 'Salma',
            'client_telephone': null,
            'prix': 20,
            'montant_encaisse': 22.5,
          },
        ]);
        api.repondre('GET', 'absences', [
          {
            'coiffeur_id': 'c1',
            'debut': '2030-01-07T12:00:00+00:00',
            'fin': '2030-01-07T13:00:00+00:00',
            'motif': 'Médecin',
          },
        ]);
        api.repondre('GET', 'horaires', [
          {
            'id': 'h1',
            'coiffeur_id': 'c1',
            'jour_semaine': 1,
            'heure_debut': '09:00:00',
            'heure_fin': '18:30:00',
          },
        ]);

        final donnees = await planning.periode(
          DateTime(2030, 1, 7),
          DateTime(2030, 1, 7),
          coiffeurId: 'c1',
        );

        final r = donnees.rendezVous.single;
        // 08:00 UTC = 09:00 à Tunis (UTC+1).
        expect(r.debut, DateTime(2030, 1, 7, 9));
        expect(r.fin, DateTime(2030, 1, 7, 9, 30));
        expect(r.statut, StatutRendezVous.terminee);
        expect(r.prix, 20.0);
        expect(r.montantEncaisse, 22.5);
        expect(donnees.absences.single.debut, DateTime(2030, 1, 7, 13));
        expect(donnees.absences.single.motif, 'Médecin');
        final plage = donnees.plages.single.plage;
        expect(
          (plage.debut, plage.fin),
          (
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 18, minute: 30),
          ),
        );

        expect(corps('rpc/planning'), {
          'p_salon': salonId,
          'p_du': '2030-01-07',
          'p_au': '2030-01-07',
          'p_coiffeur': 'c1',
        });
        // Absences du jour à l'heure du salon : 7 janvier 00:00 → 8 janvier 00:00.
        final absences = api.vers('absences').single.url.queryParameters;
        expect(absences['debut'], 'lt.2030-01-07T23:00:00.000Z');
        expect(absences['fin'], 'gt.2030-01-06T23:00:00.000Z');
        expect(absences['coiffeur_id'], 'eq.c1');
        expect(
          api.vers('horaires').single.url.queryParameters['coiffeur_id'],
          'eq.c1',
        );
        // Fuseau lu une seule fois.
        await planning.maintenantAuSalon();
        expect(api.vers('salons'), hasLength(1));
      },
    );

    test('coiffeurs : coiffeurs_du_salon(), triés par nom', () async {
      api.repondre('POST', 'rpc/coiffeurs_du_salon', [
        {'id': 'c2', 'nom': 'Youssef'},
        {'id': 'c1', 'nom': 'Amira'},
      ]);
      final equipe = await planning.coiffeurs();
      expect([for (final c in equipe) c.nom], ['Amira', 'Youssef']);
      expect(corps('rpc/coiffeurs_du_salon'), {'p_salon': salonId});
    });

    test('monNom : null sans connexion, sinon le nom du compte', () async {
      expect(planning.moi, isNull);
      expect(await planning.monNom(), isNull);

      await connecter();
      api.repondre('GET', 'utilisateurs', {'nom': 'Amira Ben Salah'});
      expect(planning.moi, 'u1');
      expect(await planning.monNom(), 'Amira Ben Salah');
      expect(
        api.vers('utilisateurs').single.url.queryParameters['id'],
        'eq.u1',
      );
    });

    test('clôture : une ligne modifiée, sinon refus de la RLS', () async {
      api.repondre('PATCH', 'reservations', [
        {'id': 'r1'},
      ]);
      await planning.cloturer('r1', StatutRendezVous.absent);
      expect(corps('reservations'), {'statut': 'absent'});

      // 0 ligne : la RLS a refusé sans erreur.
      api.repondre('PATCH', 'reservations', <Object>[]);
      await expectLater(
        planning.cloturer('r1', StatutRendezVous.terminee),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            'Action non autorisée avec ce compte.',
          ),
        ),
      );
    });

    test(
      'encaissement : montant et encaisse_par ; correction vérifiée',
      () async {
        await connecter(id: 'g1');
        api.repondre('POST', 'encaissements', null, statut: 201);
        await planning.encaisser('r1', 25.5);
        expect(corps('encaissements'), {
          'reservation_id': 'r1',
          'montant': 25.5,
          'encaisse_par': 'g1',
        });

        api.repondre('PATCH', 'encaissements', <Object>[]);
        await expectLater(
          planning.corrigerEncaissement('r1', 30),
          throwsA(isA<ErreurSalon>()),
        );
      },
    );

    test('erreurs de la base traduites en messages', () async {
      Future<String> message(String code, {String texte = 'refus'}) async {
        api.refuser('PATCH', 'reservations', code, message: texte);
        try {
          await planning.cloturer('r1', StatutRendezVous.terminee);
        } on ErreurSalon catch (e) {
          return e.message;
        }
        fail('aucune erreur pour $code');
      }

      expect(
        await message('PT409'),
        'Ce rendez-vous n\'a pas encore commencé : clôture impossible.',
      );
      expect(
        await message('PT409', texte: 'Seul un rendez-vous terminé...'),
        'Seul un rendez-vous terminé peut être encaissé.',
      );
      expect(await message('PT403'), 'Planning réservé à l\'équipe du salon.');
      expect(
        await message('PT403', texte: 'Historique réservé...'),
        'Historique réservé au gérant du salon.',
      );
      expect(await message('PT400'), 'Période de 1 à 31 jours.');
      expect(await message('23505'), 'Ce rendez-vous est déjà encaissé.');
      expect(
        await message('23514'),
        'Ce rendez-vous est déjà clôturé, ou le montant est négatif.',
      );
      expect(await message('42501'), 'Action non autorisée avec ce compte.');
      expect(
        await message('XX000'),
        'L\'enregistrement a échoué. Vérifiez le réseau, puis réessayez.',
      );
    });

    test(
      'historique : lignes à l\'heure du salon, montant facultatif',
      () async {
        api.repondre('POST', 'rpc/historique', [
          {
            'id': 'r1',
            'coiffeur_id': 'c1',
            'coiffeur': 'Amira',
            'debut': '2030-01-07T08:00:00+00:00',
            'statut': 'absent',
            'prestation': 'Coupe',
            'prix': 20,
            'client_nom': 'Salma',
            'montant': null,
          },
        ]);
        final lignes = await planning.historique(
          DateTime(2030, 1, 1),
          DateTime(2030, 1, 31),
        );
        expect(lignes.single.debut, DateTime(2030, 1, 7, 9));
        expect(lignes.single.statut, StatutRendezVous.absent);
        expect(lignes.single.prix, 20.0);
        expect(lignes.single.montant, isNull);
        expect(corps('rpc/historique')['p_coiffeur'], isNull);
      },
    );
  });

  group('SalonSupabase', () {
    late SalonSupabase salon;
    setUp(() => salon = SalonSupabase(api.client, salonId));

    test('identité : nom et adresse du salon', () async {
      api.repondre('GET', 'salons', {'nom': 'Salon de démo', 'adresse': null});
      final identite = await salon.identite();
      expect(identite.nom, 'Salon de démo');
      expect(identite.adresse, isNull);
      expect(
        api.vers('salons').single.url.queryParameters['id'],
        'eq.$salonId',
      );
    });

    test('prestations : numeric en double, filtre et tri', () async {
      api.repondre('GET', 'prestations', [
        {
          'id': 'p1',
          'nom': 'Coupe',
          'prix': 10.5,
          'duree_minutes': 30,
          'active': true,
        },
      ]);
      final p = (await salon.prestations()).single;
      expect(p.prix, 10.5);
      expect(p.dureeMinutes, 30);
      final params = api.vers('prestations').single.url.queryParameters;
      expect(params['salon_id'], 'eq.$salonId');
      expect(params['order'], startsWith('nom.asc'));
    });

    test('écritures : prestation, plage, compétence', () async {
      api.repondre('POST', 'prestations', null, statut: 201);
      api.repondre('PATCH', 'prestations', null, statut: 204);
      api.repondre('POST', 'horaires', null, statut: 201);
      api.repondre('DELETE', 'horaires', null, statut: 204);
      api.repondre('POST', 'competences', null, statut: 201);
      api.repondre('DELETE', 'competences', null, statut: 204);

      await salon.creerPrestation(nom: 'Coupe', prix: 35, dureeMinutes: 45);
      expect(corps('prestations'), {
        'salon_id': salonId,
        'nom': 'Coupe',
        'prix': 35.0,
        'duree_minutes': 45,
      });
      await salon.modifierPrestation(
        'p1',
        nom: 'Couleur',
        prix: 80,
        dureeMinutes: 90,
      );
      await salon.changerActivation('p1', active: false);
      expect(corps('prestations', rang: 2), {'active': false});

      await salon.ajouterPlage(
        'c1',
        jour: 2,
        debut: const TimeOfDay(hour: 9, minute: 0),
        fin: const TimeOfDay(hour: 12, minute: 30),
      );
      expect(corps('horaires'), {
        'salon_id': salonId,
        'coiffeur_id': 'c1',
        'jour_semaine': 2,
        'heure_debut': '09:00',
        'heure_fin': '12:30',
      });
      await salon.supprimerPlage('h1');
      expect(api.vers('horaires')[1].url.queryParameters['id'], 'eq.h1');

      await salon.ajouterCompetence('c1', 'p1');
      await salon.retirerCompetence('c1', 'p1');
      final retrait = api.vers('competences')[1].url.queryParameters;
      expect(
        (retrait['coiffeur_id'], retrait['prestation_id']),
        ('eq.c1', 'eq.p1'),
      );
    });

    test('plages, compétences et équipe : lecture', () async {
      api.repondre('GET', 'horaires', [
        {
          'id': 'h1',
          'jour_semaine': 1,
          'heure_debut': '08:30:00',
          'heure_fin': '12:00:00',
        },
      ]);
      api.repondre('GET', 'competences', [
        {'prestation_id': 'p1'},
        {'prestation_id': 'p2'},
      ]);
      api.repondre('POST', 'rpc/coiffeurs_du_salon', [
        {'id': 'c2', 'nom': 'Youssef'},
        {'id': 'c1', 'nom': 'Amira'},
      ]);
      final plage = (await salon.plages('c1')).single;
      expect(plage.debut, const TimeOfDay(hour: 8, minute: 30));
      expect(await salon.competences('c1'), {'p1', 'p2'});
      expect(
        [for (final c in await salon.coiffeurs()) c.nom],
        ['Amira', 'Youssef'],
      );
    });

    test('absences : heure du salon dans les deux sens', () async {
      api.repondre('GET', 'absences', [
        {
          'id': 'a1',
          'debut': '2030-01-07T08:00:00+00:00',
          'fin': '2030-01-07T17:00:00+00:00',
          'motif': null,
        },
      ]);
      api.repondre('POST', 'absences', null, statut: 201);
      api.repondre('DELETE', 'absences', null, statut: 204);

      final a = (await salon.absences('c1')).single;
      expect(
        (a.debut, a.fin),
        (DateTime(2030, 1, 7, 9), DateTime(2030, 1, 7, 18)),
      );
      expect(a.motif, isNull);

      await salon.ajouterAbsence(
        'c1',
        debut: DateTime(2030, 1, 8, 9),
        fin: DateTime(2030, 1, 8, 12),
        motif: 'Formation',
      );
      final envoi = corps('absences', rang: 1);
      expect(envoi['debut'], '2030-01-08T08:00:00.000Z');
      expect(envoi['fin'], '2030-01-08T11:00:00.000Z');
      expect(envoi['motif'], 'Formation');
      await salon.supprimerAbsence('a1');
      expect(api.vers('absences')[2].method, 'DELETE');
    });

    test(
      'rendez-vous pendant une absence : bornes en UTC, nombre de lignes',
      () async {
        api.repondre('GET', 'reservations', [
          {'id': 'r1'},
          {'id': 'r2'},
        ]);
        final n = await salon.rendezVousPendant(
          'c1',
          debut: DateTime(2030, 1, 7, 9),
          fin: DateTime(2030, 1, 7, 12),
        );
        expect(n, 2);
        final params = api.vers('reservations').single.url.queryParameters;
        expect(params['statut'], 'eq.confirmee');
        expect(params['debut'], 'lt.2030-01-07T11:00:00.000Z');
        expect(params['fin'], 'gt.2030-01-07T08:00:00.000Z');
        expect(await salon.maintenantAuSalon(), isA<DateTime>());
      },
    );

    test('erreurs de la base traduites en messages', () async {
      Future<String> message(String code) async {
        api.refuser('POST', 'horaires', code);
        try {
          await salon.ajouterPlage(
            'c1',
            jour: 1,
            debut: const TimeOfDay(hour: 9, minute: 0),
            fin: const TimeOfDay(hour: 10, minute: 0),
          );
        } on ErreurSalon catch (e) {
          return e.message;
        }
        fail('aucune erreur pour $code');
      }

      expect(
        await message('23P01'),
        'Cette plage chevauche une autre plage de ce coiffeur.',
      );
      expect(await message('23505'), 'Cet élément existe déjà.');
      expect(await message('42501'), 'Action réservée au gérant du salon.');
      expect(await message('23514'), startsWith('Saisie refusée'));
    });

    test('réponse illisible : message neutre', () async {
      api.repondre('GET', 'prestations', {'inattendu': true});
      await expectLater(
        salon.prestations(),
        throwsA(
          isA<ErreurSalon>().having(
            (e) => e.message,
            'message',
            'L\'enregistrement a échoué. Vérifiez le réseau, puis réessayez.',
          ),
        ),
      );
    });
  });

  group('Session', () {
    test('connexion : identifiants refusés, message neutre', () async {
      api.repondreAuth('POST', 'token', {
        'code': 400,
        'error_code': 'invalid_credentials',
        'msg': 'Invalid login credentials',
      }, statut: 400);
      final auth = AuthSupabase(api.client);
      expect(
        await auth.seConnecter('amira@salon.test', 'faux'),
        'E-mail ou mot de passe incorrect.',
      );
      expect(auth.compte, isNull);
    });

    test('connexion réussie, rôles du compte, puis déconnexion', () async {
      api.repondreAuth('POST', 'token', FausseApi.session());
      api.repondreAuth('POST', 'logout', null, statut: 204);
      api.repondre('GET', 'roles_utilisateur', [
        {'role': 'gerant'},
        {'role': 'coiffeur'},
      ]);
      final auth = AuthSupabase(api.client);
      final roles = RolesSupabase(api.client, salonId);
      expect(await roles.rolesDansLeSalon(), isEmpty);

      expect(await auth.seConnecter('amira@salon.test', 'motdepasse'), isNull);
      expect(auth.compte, 'amira@salon.test');
      expect(await roles.rolesDansLeSalon(), ['gerant', 'coiffeur']);
      final params = api.vers('roles_utilisateur').single.url.queryParameters;
      expect(params['utilisateur_id'], 'eq.u1');
      expect(params['salon_id'], 'eq.$salonId');

      await auth.seDeconnecter();
      expect(auth.compte, isNull);
    });

    test('messages de connexion par code d\'Auth', () {
      expect(
        messageErreurConnexion('over_request_rate_limit'),
        'Trop de tentatives. Réessayez dans une minute.',
      );
      expect(
        messageErreurConnexion('reseau'),
        'Connexion impossible. Vérifiez le réseau, puis réessayez.',
      );
      expect(
        messageErreurConnexion('inconnu'),
        'Une erreur est survenue. Réessayez.',
      );
    });
  });
}
