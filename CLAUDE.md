# Open Sampler IG — notes de reprise

App Flutter (Dart 3) Android, fork d'Open Sampler (EUPL 1.2). Utilisateur : Ivan (français).
Méthode : plans phase par phase. Interface FR/EN (lib/l10n.dart).

## Phases
- Phase 1 (v2.0.0, livrée) : portage Flutter 3, copie des sons dans l'app, fix nom de pad,
  progression/temps restant, état visible, groupes d'exclusion, fondu, écran allumé, mode scène.
- Phase 2 (v2.1.0, livrée) : gros bouton STOP, « Retirer » efface aussi le nom, export/import
  projet (.zip), échanger/déplacer/dupliquer un pad, interface FR/EN, nouvelle icône
  (source : assets/icon/logo_circle.png). Volume général écarté par Ivan.
- v2.2.0 (livrée) : pages/onglets par projet, STOP réduit (25 % de largeur, à droite).
- Prochaines évolutions validées par Ivan (à coder après ses essais en match réel) :
  - v2.3 proposée : point de départ/fin d'un son + fondu d'entrée par pad, clignotement du pad
    dans les dernières secondes, vibration au déclenchement, code PIN pour quitter le mode scène,
    verrouillage de l'orientation.
  - v2.4 proposée : import de plusieurs sons d'un coup (remplit les pads vides), pad « playlist »
    (morceau suivant / aléatoire à chaque appui), baisse auto de la musique (ducking) pour pads prioritaires.
  - Déconseillé pour l'instant : fusion de pads, normalisation du volume, enregistrement micro,
    télécommande/pédale Bluetooth.

## Compiler dans une session cloud
- Installer Flutter stable (storage.googleapis.com) + Android cmdline-tools (dl.google.com),
  `sdkmanager "platform-tools" "platforms;android-36" "build-tools;35.0.0"`.
- Maven Central renvoie souvent 429 via le proxy : ajouter un init script Gradle
  (~/.gradle/init.d) qui place `https://maven-central.storage-download.googleapis.com/maven2/`
  en premier dépôt (pluginManagement + projets racine uniquement).
- `flutter build apk --release --split-per-abi` (l'APK universel ~50 Mo dépasse la limite d'envoi de 30 Mo).
- Signature : `android/key.properties` + keystore `opensampler-ig-release.jks` (alias `opensampler`),
  JAMAIS versionnés. Ivan les détient ; les lui demander avant toute release, sinon
  l'APK ne s'installera pas par-dessus la version existante.
- Incrémenter `version:` dans pubspec.yaml (versionCode) à chaque release.

## Points techniques
- Pages : `Settings.padSettings` est une liste plate (page après page, x*y pads chacune),
  `pageNames` donne les pages. Les index de pads sont globaux ; `SampleEngine.applyLayout`
  déplace les lecteurs avec leurs pads (ajout/suppression/déplacement de page sans couper le son).
  JSON : clé `pages` + `padSettings` de la page 1 (lisible par les anciennes versions).
- Textes : tout passe par `S` (lib/l10n.dart) — ne pas écrire de texte en dur dans les écrans.
- Versions split-per-abi : versionCode = 1000 × ABI + build (arm64 = 2xxx).
- Contexte audio global avec `AndroidAudioFocus.none`, sinon les pads se coupent entre eux.
- Pads « courts » = PlayerMode.lowLatency (SoundPool) : aucune position ni fin de lecture,
  d'où l'horloge interne dans `PadVoice` et la durée sondée/mise en cache (`durationMs`).
- Compatibilité : les JSON de projet 2021 doivent rester lisibles (test/settings_test.dart).
