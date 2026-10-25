// Configuration passée au lancement par --dart-define (aucune clé dans le
// code) : flutter run --dart-define-from-file=config/local.json
// Modèle : config/exemple.json. Clé anon uniquement, comme le site.
class Config {
  const Config({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.salonId,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String salonId;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _cle = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _salon = String.fromEnvironment('SALON_ID');

  // Noms des variables manquantes (vide : configuration complète).
  static List<String> manquantes({
    String url = _url,
    String cle = _cle,
    String salon = _salon,
  }) => [
    if (url.isEmpty) 'SUPABASE_URL',
    if (cle.isEmpty) 'SUPABASE_ANON_KEY',
    if (salon.isEmpty) 'SALON_ID',
  ];

  static const depuisLancement = Config(
    supabaseUrl: _url,
    supabaseAnonKey: _cle,
    salonId: _salon,
  );
}
