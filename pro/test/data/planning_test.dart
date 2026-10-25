import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/planning.dart';

// Refus de la base traduits pour l'app (codes et messages de
// supabase/migrations/20261025153145_cloture_encaissement.sql).
void main() {
  test('refus de clôture et d\'encaissement : messages distincts', () {
    expect(
      messageErreurPlanning('PT409', 'Rendez-vous pas encore commencé'),
      'Ce rendez-vous n\'a pas encore commencé : clôture impossible.',
    );
    expect(
      messageErreurPlanning(
        'PT409',
        'Seul un rendez-vous terminé est encaissable',
      ),
      'Seul un rendez-vous terminé peut être encaissé.',
    );
    expect(
      messageErreurPlanning('23505', 'duplicate key'),
      'Ce rendez-vous est déjà encaissé.',
    );
    expect(
      messageErreurPlanning('42501', 'permission denied'),
      'Action non autorisée avec ce compte.',
    );
  });

  test('PT403 : planning ou historique selon la fonction', () {
    expect(
      messageErreurPlanning('PT403', 'Historique réservé au gérant du salon'),
      'Historique réservé au gérant du salon.',
    );
    expect(
      messageErreurPlanning('PT403', 'Un coiffeur ne voit que son planning'),
      'Planning réservé à l\'équipe du salon.',
    );
  });

  test('rendez-vous clôturable : confirmé et commencé', () {
    RendezVous rdv(StatutRendezVous statut) => RendezVous(
      id: 'r',
      coiffeurId: 'c',
      debut: DateTime(2030, 1, 7, 9),
      fin: DateTime(2030, 1, 7, 9, 30),
      statut: statut,
      prestation: 'Coupe',
      dureeMinutes: 30,
      clientNom: 'Salma',
      prix: 20,
    );
    final debut = DateTime(2030, 1, 7, 9);
    expect(rdv(StatutRendezVous.confirmee).cloturable(debut), isTrue);
    expect(
      rdv(
        StatutRendezVous.confirmee,
      ).cloturable(debut.subtract(const Duration(minutes: 1))),
      isFalse,
    );
    expect(rdv(StatutRendezVous.terminee).cloturable(debut), isFalse);
  });
}
