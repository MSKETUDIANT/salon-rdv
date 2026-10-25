// Espaces de l'app pro, selon les rôles de l'utilisateur dans le salon
// (table roles_utilisateur, issue #2). Le rôle « client » seul n'ouvre aucun
// espace : l'app pro est réservée à l'équipe.
enum Espace {
  gerant('Espace gérant'),
  coiffeur('Espace coiffeur');

  const Espace(this.titre);
  final String titre;
}

// Gérant d'abord : c'est l'espace qui donne accès à tout le salon.
List<Espace> espacesPro(Iterable<String> roles) => [
  if (roles.contains('gerant')) Espace.gerant,
  if (roles.contains('coiffeur')) Espace.coiffeur,
];
