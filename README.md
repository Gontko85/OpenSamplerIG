# Open Sampler IG

Sampler / sound board pour Android — version modernisée et enrichie de
[Open Sampler](https://github.com/trvekvltgames/opensampler) (Cherry Tree Studio, 2021),
par Ivan Gontcharenko — IG Littoral Labs.

## Nouveautés de la v2.5.0

- **Conducteur de match** (Menu > Conducteurs de match) : la liste des sons d'un match dans l'ordre,
  chaque étape = une touche + une note facultative (« au coup de sifflet »). L'icône ☰▶ affiche au-dessus
  de la grille un gros bouton **▶ À suivre** (à la couleur de la touche) qui joue l'étape et passe à la
  suivante ; ◀ revenir, ⏭ passer, liste des étapes pour sauter. Plusieurs conducteurs par projet, utilisable
  en mode scène ; les étapes suivent leurs touches même déplacées ou changées de page.
- **Pad « playlist »** : plusieurs morceaux sur une touche (Réglages du pad > Ajouter des morceaux…),
  joués dans l'ordre ou au hasard sans répétition ; le morceau suivant est préparé d'avance.
  La touche affiche le numéro et le nom du morceau. Export/import et nettoyage du stockage en tiennent compte.

## Nouveautés de la v2.4.0

- **Bandeau « En cours »** en bas : tous les sons qui jouent (toutes pages), temps restant, arrêt d'un
  son précis, et un appui sur son nom montre la touche.
- **Sons récents** : rangée des 8 derniers sons lancés, relance en un geste.
- **Texte des touches ajusté automatiquement** à la taille de chaque touche (réglage « Taille du texte »
  sur « Automatique »), sans couper « Panier ! » avant le point d'exclamation.
- **Réglages > Stockage** : place prise par les sons et nettoyage de ceux qu'aucun projet n'utilise
  (bloqué par sécurité si un projet est illisible).

## Nouveautés de la v2.3.2

- **Recherche d'un son** (loupe 🔍, aussi en mode scène) : en tapant une partie du nom, l'appli va à la
  page de la première touche trouvée et l'encadre en bleu ; ▲▼ ou Entrée pour les résultats suivants.
  Majuscules et accents ignorés, le nom du fichier compte aussi.
- Changement de page net (plus de bref fondu de couleurs entre les pages).

## Nouveautés de la v2.3.1

- **Réparation automatique des « faux MP3 »** : des fichiers .mp3 qui sont en réalité des vidéos MPEG
  (.mpg, souvent produits par des logiciels de montage) étaient refusés par Android (pastille rouge).
  L'appli en extrait maintenant la musique, sans réencodage ni perte, à l'import et au chargement
  des touches existantes.
- Un son court refusé en mode « faible latence » est automatiquement réessayé en « son long ».
- **Pastille rouge expliquée** : toucher la touche affiche la raison (fichier absent, format refusé + détail).

## Nouveautés de la v2.3.0

- **Export / import des gros projets** : le .zip est écrit et relu *en flux*, son par son, sans
  jamais être chargé en mémoire (testé à 1,2 Go et 4,5 Go). Fin des « out of memory ».
  À l'export : « Enregistrer dans un dossier » ou « Envoyer / partager » (Quick Share, Drive…).
- **Importer plusieurs sons d'un coup** : remplit les touches vides de la page affichée puis des
  suivantes (ajout de pages proposé), nom = nom du fichier, « son long » réglé selon la durée.
- **Réglages d'un pad sur un seul écran** : nom modifiable directement sur l'aperçu, boucle / son
  long / groupe sur une ligne, comportement en boutons, palettes de couleurs (+ couleur libre).

## Nouveautés de la v2.2.0

- **Plusieurs pages (onglets) par projet** : ajouter, renommer, dupliquer, déplacer, supprimer
  (appui long sur un onglet). Les sons continuent de jouer quand on change de page ; un point
  vert signale une page dont un son est en cours. STOP et groupes d'exclusion valent pour tout le projet.
- Échanger / dupliquer un pad vers une autre page.
- Bouton STOP deux fois moins large, aligné à droite.
- Les projets des versions précédentes s'ouvrent comme un projet d'une seule page.

## Nouveautés de la v2.1.0

- Interface **en français ou en anglais** (choix dans Réglages > Langue ; par défaut la langue du téléphone).
- Grand **bouton STOP rouge** en haut (moitié de l'écran) ; 2e appui pendant le fondu = coupure immédiate.
- **Export / import** d'un projet complet (.zip avec tous les sons) pour passer d'un appareil à l'autre.
- **Échanger / déplacer / dupliquer** un pad depuis ses réglages.
- « Retirer » le son d'un pad retire aussi son nom.
- Nouvelle icône d'application.

## Nouveautés de la v2.0.0

- Portage Flutter 3 / Dart 3 (null safety), Android 7 → Android 16.
- Les sons choisis sont **copiés dans l'app** : plus de pads muets après un nettoyage du cache.
- Correction du bug du nom de pad (crash silencieux quand le nom n'était pas un nombre).
- **Barre de progression + temps restant** sur chaque pad, contour blanc (lecture) / ambre (pause).
- **Groupes d'exclusion** A–D : lancer un pad coupe les autres pads du même groupe.
- **Fondu à l'arrêt** réglable (0 à 5 s) ; second appui sur « couper tout » = coupure immédiate.
- **Écran toujours allumé** (désactivable).
- **Mode scène** (cadenas) : déclenchement au toucher, multi-touch, édition verrouillée.
- Palette de couleurs rapides, suppression du son d'un pad, pastille « fichier manquant ».

Les anciens projets (format JSON 2021) restent lisibles.

## Compiler

```bash
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

Les APK sont dans `build/app/outputs/flutter-apk/` (`app-arm64-v8a-release.apk` pour la plupart des appareils).

### Signature

La signature release lit `android/key.properties` (non versionné) :

```properties
storePassword=...
keyPassword=...
keyAlias=opensampler
storeFile=/chemin/vers/opensampler-ig-release.jks
```

Sans ce fichier, l'APK release est signé avec la clé de debug — il ne pourra **pas**
s'installer par-dessus une version signée avec la vraie clé. La clé et son mot de passe
ne doivent jamais être poussés sur le dépôt.

## Structure

| Fichier | Rôle |
|---|---|
| `lib/main.dart` | Démarrage, contexte audio (mixage des pads) |
| `lib/settings.dart` | Modèle projet / pad (JSON) et préférences globales |
| `lib/sample_engine.dart` | Lecture, progression, groupes, fondus |
| `lib/sample_store.dart` | Copie des sons dans le stockage de l'app |
| `lib/pad_screen.dart` | Écran principal (grille, menu, mode scène) |
| `lib/pad_tile.dart` | Rendu d'un pad |
| `lib/pad_settings_screen.dart` | Réglages d'un pad |
| `lib/playlist_screen.dart` | Morceaux d'un pad playlist |
| `lib/rundown_screen.dart` | Conducteurs de match (liste, étapes) |
| `lib/pad_picker.dart` | Choix d'une touche sur n'importe quelle page |
| `lib/settings_screen.dart` | Réglages du projet et globaux |
| `lib/project_archive.dart` | Export / import d'un projet (.zip) |
| `lib/l10n.dart` | Textes de l'interface FR / EN |
| `lib/storage_cleaner.dart` | Analyse et nettoyage des sons inutilisés |
| `lib/audio_repair.dart` | Réparation sans perte des « faux MP3 » (MPEG-PS) |
| `lib/native_files.dart` + `MainActivity.kt` | Enregistrer / partager un gros fichier sans le charger en mémoire |

## Licence

European Union Public Licence (EUPL) v1.2 — voir l'œuvre originale.
Copyright Cherry Tree Studio 2021 ; modifications Copyright IG Littoral Labs 2026.
