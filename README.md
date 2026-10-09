# Open Sampler IG

Sampler / sound board pour Android — version modernisée et enrichie de
[Open Sampler](https://github.com/trvekvltgames/opensampler) (Cherry Tree Studio, 2021),
par Ivan Gontcharenko — IG Littoral Labs.

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
| `lib/settings_screen.dart` | Réglages du projet et globaux |
| `lib/project_archive.dart` | Export / import d'un projet (.zip) |
| `lib/l10n.dart` | Textes de l'interface FR / EN |

## Licence

European Union Public Licence (EUPL) v1.2 — voir l'œuvre originale.
Copyright Cherry Tree Studio 2021 ; modifications Copyright IG Littoral Labs 2026.
