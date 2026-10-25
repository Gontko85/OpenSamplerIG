//==============================================================================
//    l10n.dart — French / English user interface
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:ui' show PlatformDispatcher;

import 'main.dart';

//==============================================================================

const String languageKey = "language";

/// Current interface strings. Rebuilt when the language changes.
// ignore: non_constant_identifier_names
Strings S = Strings('fr');

/// Reads the saved language (or the phone language the first time).
void loadLanguage() {
  String? code = preferences.getString(languageKey);
  code ??= PlatformDispatcher.instance.locale.languageCode == 'fr' ? 'fr' : 'en';
  S = Strings(code);
}

void setLanguage(String code) {
  preferences.setString(languageKey, code);
  S = Strings(code);
}

//==============================================================================

class Strings {
  final String code;
  Strings(this.code);

  bool get fr => code == 'fr';
  String _t(String fr, String en) => this.fr ? fr : en;

  // Common
  String get cancel => _t('Annuler', 'Cancel');
  String get ok => _t('OK', 'OK');

  // Main screen
  String get stop => _t('STOP', 'STOP');
  String get cutNow => _t('COUPER', 'CUT NOW');
  String get stopTooltip =>
      _t('Tout arrêter (2e appui : coupure immédiate)', 'Stop all (press again to cut at once)');
  String get stageOnTooltip => _t('Déverrouiller l\'édition', 'Unlock editing');
  String get stageOffTooltip => _t('Mode scène (verrouiller l\'édition)', 'Stage mode (lock editing)');
  String get stageOn => _t(
    'Mode scène ACTIVÉ : les pads se déclenchent au toucher, l\'édition est verrouillée.',
    'Stage mode ON: pads fire on touch, editing is locked.',
  );
  String get stageOff => _t(
    'Mode scène DÉSACTIVÉ : appui long sur un pad pour le régler.',
    'Stage mode OFF: long press a pad to edit it.',
  );

  // Menu
  String get newProject => _t('Nouveau projet', 'New Project');
  String get saveProject => _t('Enregistrer le projet', 'Save Project');
  String get openProject => _t('Ouvrir un projet', 'Open Project');
  String get exportProject => _t('Exporter le projet (avec les sons)', 'Export project (with sounds)');
  String get importProject => _t('Importer un projet', 'Import a project');
  String get settings => _t('Réglages', 'Settings');
  String get help => _t('Aide', 'Help');
  String get about => _t('À propos', 'About');

  String get newProjectConfirm => _t(
    'Le projet actuel va être fermé et un projet vide créé. Continuer ?',
    'This will close current project and create a blank one. Continue?',
  );
  String get projectNamePrompt => _t('Nom du projet', 'Project name');
  String cannotOpen(Object e) => _t('Impossible d\'ouvrir le projet : $e', 'Cannot open project: $e');

  // Pages
  String pageN(int n) => 'Page $n';
  String get addPage => _t('Ajouter une page', 'Add a page');
  String get renamePage => _t('Renommer la page', 'Rename page');
  String get duplicatePage => _t('Dupliquer la page', 'Duplicate page');
  String get movePageLeft => _t('Déplacer vers la gauche', 'Move left');
  String get movePageRight => _t('Déplacer vers la droite', 'Move right');
  String get deletePage => _t('Supprimer la page', 'Delete page');
  String deletePageConfirm(String n) =>
      _t('Supprimer la page « $n » et tous ses pads ?', 'Delete page "$n" and all its pads?');
  String get pageNamePrompt => _t('Nom de la page', 'Page name');
  String copyOf(String n) => _t('$n (copie)', '$n (copy)');
  String get gridAllPages => _t(
    'La grille s\'applique à toutes les pages du projet.',
    'The grid applies to every page of the project.',
  );

  // Playlists
  String get playlistNone => _t('Un seul morceau', 'Single track');
  String playlistSummary(int n, bool shuffle) => _t(
    'Playlist : $n morceaux, ${shuffle ? 'au hasard' : 'dans l\'ordre'}',
    'Playlist: $n tracks, ${shuffle ? 'random' : 'in order'}',
  );
  String get playlistCreate => _t('Ajouter des morceaux…', 'Add tracks…');
  String get playlistManage => _t('Gérer…', 'Manage…');
  String playlistTitle(String caption) => _t('Playlist « $caption »', 'Playlist "$caption"');
  String get playlistAdd => _t('Ajouter des morceaux', 'Add tracks');
  String get playlistInOrder => _t('Dans l\'ordre', 'In order');
  String get playlistShuffle => _t('Au hasard', 'Random');
  String get playlistInOrderHint => _t(
    'Chaque appui sur la touche joue le morceau suivant de la liste, puis on recommence au premier. Faites glisser ≡ pour changer l\'ordre.',
    'Each press plays the next track of the list, then it starts again from the first. Drag ≡ to reorder.',
  );
  String get playlistShuffleHint => _t(
    'Chaque appui joue un morceau au hasard, sans jamais répéter un morceau avant que tous aient été joués.',
    'Each press plays a random track, never repeating one before all were played.',
  );
  String get playlistEmpty => _t(
    'Aucun morceau.\nAjoutez-en avec le bouton ci-dessous.',
    'No track.\nAdd some with the button below.',
  );

  // Match rundowns ("conducteurs")
  String get rundowns => _t('Conducteurs de match', 'Match rundowns');
  String get rundownShort => _t('Conducteur', 'Rundown');
  String get rundownToggle => _t('Afficher / masquer le conducteur', 'Show / hide the rundown');
  String get rundownNew => _t('Nouveau conducteur', 'New rundown');
  String get rundownNamePrompt => _t('Nom du conducteur', 'Rundown name');
  String get rundownDefaultName => _t('Match', 'Match');
  String get rundownsEmpty => _t(
    'Aucun conducteur.\nUn conducteur est la liste des sons d\'un match, dans l\'ordre : un gros bouton joue le suivant.',
    'No rundown.\nA rundown is the list of the sounds of a match, in order: one big button plays the next one.',
  );
  String rundownSteps(int n) => _t('$n étape${n > 1 ? 's' : ''}', '$n step${n > 1 ? 's' : ''}');
  String get rename => _t('Renommer', 'Rename');
  String get duplicate => _t('Dupliquer', 'Duplicate');
  String get delete => _t('Supprimer', 'Delete');
  String rundownCopyName(String name) => _t('$name (copie)', '$name (copy)');
  String rundownDeleteConfirm(String name) => _t(
    'Supprimer le conducteur « $name » ? Les sons ne sont pas supprimés.',
    'Delete the rundown "$name"? The sounds are kept.',
  );
  String get rundownAddStep => _t('Ajouter une étape', 'Add a step');
  String get rundownPickPad => _t('Touche à jouer', 'Pad to play');
  String get rundownStepsEmpty => _t(
    'Aucune étape.\nAjoutez les touches dans l\'ordre du match avec le bouton ci-dessous.',
    'No step.\nAdd the pads in match order with the button below.',
  );
  String get rundownNote => _t('Note (facultative)', 'Note (optional)');
  String get rundownNoteHint => _t('ex. : au coup de sifflet', 'e.g. at the whistle');
  String get rundownEditNote => _t('Modifier la note', 'Edit note');
  String get rundownMissingPad => _t('touche supprimée', 'pad deleted');
  String get rundownNext => _t('À suivre', 'Up next');
  String get rundownPlayed => _t('Joué', 'Played');
  String get rundownFinished => _t('Conducteur terminé', 'Rundown finished');
  String get rundownRestart => _t('Recommencer', 'Restart');
  String get rundownBack => _t('Étape précédente', 'Previous step');
  String get rundownSkip => _t('Passer cette étape', 'Skip this step');
  String get rundownList => _t('Toutes les étapes', 'All steps');
  String get rundownEdit => _t('Modifier le conducteur', 'Edit the rundown');
  String get rundownNoneYet => _t('Aucun conducteur : créez-en un', 'No rundown: create one');
  String get rundownCreate => _t('Créer', 'Create');
  String rundownPage(String page) => _t('page $page', 'page $page');

  // Now playing / recent
  String get nowPlaying => _t('En cours', 'Now playing');
  String get recentSounds => _t('Sons récents', 'Recent sounds');
  String get stopThis => _t('Arrêter ce son', 'Stop this sound');
  String get paused => _t('pause', 'paused');
  String get showNowPlaying => _t('Bandeau « En cours » (sons qui jouent)', '"Now playing" strip');
  String get showRecent => _t('Rangée des sons récents', 'Recent sounds row');

  // Storage
  String get storage => _t('Stockage', 'Storage');
  String storageSounds(int n, String size) => _t(
    'Sons gardés par l\'appli : $n fichier${n > 1 ? 's' : ''}, $size',
    'Sounds kept by the app: $n file${n > 1 ? 's' : ''}, $size',
  );
  String storageUnused(int n, String size) => _t(
    '$size récupérable${n > 0 ? ' ($n son${n > 1 ? 's' : ''} utilisé${n > 1 ? 's' : ''} dans aucun projet)' : ''}',
    '$size can be freed${n > 0 ? ' ($n sound${n > 1 ? 's' : ''} used by no project)' : ''}',
  );
  String get storageNothing =>
      _t('Rien à nettoyer : tous les sons servent.', 'Nothing to clean: every sound is in use.');
  String storageUnsafe(String names) => _t(
    'Nettoyage impossible : projet illisible ($names). Aucun son ne sera supprimé.',
    'Cleaning disabled: unreadable project ($names). No sound will be deleted.',
  );
  String storageCleanButton(String size) => _t('Nettoyer ($size)', 'Clean up ($size)');
  String get storageCleanTitle => _t('Nettoyer le stockage ?', 'Clean up storage?');
  String storageCleanConfirm(int n, String size) => _t(
    '$n son${n > 1 ? 's' : ''} qui ne ${n > 1 ? 'servent' : 'sert'} dans aucun projet enregistré, et les fichiers temporaires, seront supprimés ($size). Les fichiers d\'origine sur la tablette ne sont pas touchés.',
    '$n sound${n > 1 ? 's' : ''} used by no saved project, and temporary files, will be deleted ($size). Your original files on the device are not touched.',
  );
  String storageFreed(String size) => _t('$size libérés', '$size freed');

  // Search
  String get search => _t('Rechercher un son', 'Search a sound');
  String get searchHint => _t('Nom de la touche…', 'Pad name…');
  String get searchNone => _t('Aucun', 'None');
  String get searchPrev => _t('Précédent', 'Previous');
  String get searchNext => _t('Suivant', 'Next');
  String get searchClose => _t('Fermer la recherche', 'Close search');

  // Bulk import
  String get bulkImport => _t('Importer plusieurs sons…', 'Import several sounds…');
  String get bulkImporting => _t('Import des sons…', 'Importing sounds…');
  String bulkTooMany(int n, int free) => _t(
    '$n sons pour $free touche${free > 1 ? 's' : ''} libre${free > 1 ? 's' : ''}',
    '$n sounds for $free free pad${free > 1 ? 's' : ''}',
  );
  String bulkAddPages(int p) => _t(
    'Ajouter $p page${p > 1 ? 's' : ''} à la fin du projet pour tout placer ?',
    'Add $p page${p > 1 ? 's' : ''} at the end of the project to fit them all?',
  );
  String bulkAddPagesButton(int p) =>
      _t('Ajouter $p page${p > 1 ? 's' : ''}', 'Add $p page${p > 1 ? 's' : ''}');
  String bulkOnlyFirst(int n) => _t('Seulement les $n premiers', 'Only the first $n');
  String bulkDone(int n, String pages, int failed) => _t(
    '$n son${n > 1 ? 's' : ''} importé${n > 1 ? 's' : ''} ($pages)${failed > 0 ? ' — $failed en échec' : ''}',
    '$n sound${n > 1 ? 's' : ''} imported ($pages)${failed > 0 ? ' — $failed failed' : ''}',
  );

  // Export / import
  String get exporting => _t('Préparation de l\'export…', 'Preparing export…');
  String get importing => _t('Import en cours…', 'Importing…');
  String get importCopying => _t('Lecture du fichier…', 'Reading the file…');
  String progressCount(int d, int t) => _t('$d / $t sons', '$d / $t sounds');
  String exportReady(String name, String size) =>
      _t('Export prêt : $name ($size)', 'Export ready: $name ($size)');
  String get exportSave => _t('Enregistrer dans un dossier', 'Save to a folder');
  String get exportSaveHint =>
      _t('Téléchargements, carte SD, clé USB, Drive…', 'Downloads, SD card, USB drive, Drive…');
  String get exportShare => _t('Envoyer / partager', 'Send / share');
  String get exportShareHint => _t(
    'Quick Share vers une autre tablette, Drive, Bluetooth…',
    'Quick Share to another tablet, Drive, Bluetooth…',
  );
  String exportDone(String name) => _t('Projet exporté : $name', 'Project exported: $name');
  String get exportCancelled => _t('Export annulé', 'Export cancelled');
  String exportFailed(Object e) => _t('Échec de l\'export : $e', 'Export failed: $e');
  String importDone(String name, int sounds) => _t(
    'Projet « $name » importé ($sounds son${sounds > 1 ? 's' : ''})',
    'Project "$name" imported ($sounds sound${sounds > 1 ? 's' : ''})',
  );
  String importFailed(Object e) => _t('Échec de l\'import : $e', 'Import failed: $e');
  String get notAProject => _t(
    'Ce fichier n\'est pas un projet Open Sampler exporté.',
    'This file is not an exported Open Sampler project.',
  );
  String get saveFirst => _t(
    'Enregistrez d\'abord le projet sous un nom (menu « Enregistrer le projet »).',
    'Save the project under a name first ("Save Project").',
  );

  // Open project screen
  String get noProject => _t(
    'Aucun projet enregistré.\nUtilisez d\'abord « Enregistrer le projet ».',
    'No saved project yet.\nUse "Save Project" first.',
  );
  String openConfirm(String n) => _t('Ouvrir le projet « $n » ?', 'Do you want to open project $n?');
  String deleteConfirm(String n) => _t('Supprimer le projet « $n » ?', 'Do you want to delete project $n?');

  // Pads that cannot play (red badge)
  String get padProblemMissing => _t(
    'le fichier de ce son n\'est plus dans l\'appli. Rechoisissez-le dans les réglages de la touche.',
    'this sound file is no longer in the app. Pick it again in the pad settings.',
  );
  String padProblemRefused(String detail) => _t(
    'Android refuse de lire ce fichier (format non pris en charge ou fichier abîmé). '
        'Convertissez-le en MP3 standard puis rechoisissez-le. Détail technique : $detail',
    'Android cannot play this file (unsupported format or damaged file). '
        'Convert it to a standard MP3 and pick it again. Technical detail: $detail',
  );
  String get padProblemFix => _t('Régler', 'Fix');

  // Pad settings
  String padTitle(int row, int col) => _t('Pad ligne $row, colonne $col', 'Pad row $row, column $col');
  String padTitleOnPage(String page, int row, int col) =>
      _t('$page — ligne $row, col. $col', '$page — row $row, col. $col');
  String get soundClip => _t('Son :', 'Sound Clip:');
  String get none => _t('(aucun)', '(none)');
  String get select => _t('Choisir', 'Select');
  String get remove => _t('Retirer', 'Remove');
  String get removeConfirm =>
      _t('Retirer le son et le nom de ce pad ?', 'Remove the sound and the name of this pad?');
  String cannotImport(Object e) =>
      _t('Impossible d\'importer ce fichier : $e', 'Cannot import this file: $e');
  String get caption => _t('Nom affiché :', 'Caption:');
  String get set => _t('Modifier', 'Set');
  String get padNamePrompt => _t('Nom du pad', 'Pad name');
  String get loopShort => _t('En boucle', 'Loop');
  String get longShort => _t('Son long', 'Long sound');
  String get groupShort => _t('Groupe', 'Group');
  String get looped => _t('En boucle :', 'Looped:');
  String get longSound => _t('Son long (musique, > 5 s) :', 'Long sound (music, > 5 s):');
  String get behaviour => _t('Appui pendant la lecture :', 'Press while playing:');
  String behaviourName(String key) => switch (key) {
    'Stop' => _t('Arrêter', 'Stop'),
    'Pause' => _t('Pause', 'Pause'),
    _ => _t('Redémarrer', 'Restart'),
  };
  String get group => _t(
    'Groupe d\'exclusion :\nlancer ce pad arrête les autres pads du même groupe',
    'Exclusion group:\nstarting this pad stops the others of the same group',
  );
  String groupName(int g) => g == 0 ? _t('Aucun', 'None') : String.fromCharCode(64 + g);
  String volume(int pct) => _t('Volume du pad : $pct %', 'Pad Volume: $pct %');
  String get padColor => _t('Couleur du pad :', 'Pad Color:');
  String get textColor => _t('Couleur du texte :', 'Pad Text Color:');

  // Arrange pads
  String get arrange => _t('Organiser :', 'Arrange:');
  String get swapWith => _t('Échanger / déplacer…', 'Swap / move…');
  String get copyTo => _t('Dupliquer vers…', 'Duplicate to…');
  String get pickTargetSwap => _t(
    'Échanger avec quel pad ?\n(choisir un pad vide pour déplacer)',
    'Swap with which pad?\n(pick an empty pad to move)',
  );
  String get pickTargetCopy => _t('Dupliquer vers quel pad ?', 'Duplicate to which pad?');
  String get thisPad => _t('ce pad', 'this pad');
  String overwriteConfirm(String name) =>
      _t('Le pad « $name » sera remplacé. Continuer ?', 'Pad "$name" will be replaced. Continue?');
  String get swapped => _t('Pads échangés', 'Pads swapped');
  String get copied => _t('Pad dupliqué', 'Pad duplicated');

  // Settings screen
  String get projectSettings => _t('Réglages du projet', 'Project Settings');
  String get globalSettings => _t('Réglages généraux', 'Global Settings');
  String get horizontalPads => _t('Pads en largeur', 'Horizontal Pads');
  String get verticalPads => _t('Pads en hauteur', 'Vertical Pads');
  String get fontSize => _t('Taille du texte', 'Font Size');
  String get fontDefault => _t('Automatique (ajustée à la touche)', 'Automatic (fits the pad)');
  String get fadeOut => _t('Fondu à l\'arrêt', 'Fade out when stopping');
  String get fadeOff => _t('Non (coupure nette)', 'Off (cut)');
  String get showRemaining => _t('Afficher le temps restant sur les pads', 'Show remaining time on pads');
  String get keepScreenOn => _t('Garder l\'écran allumé', 'Keep screen on');
  String get language => _t('Langue', 'Language');

  // About
  String get aboutTagline =>
      _t('Sampler / table de sons simple pour Android', 'Simple Sampling / Sound Board app for Android');
  String get originalApp => _t('Application d\'origine', 'Original app');
  String get thisVersion => _t('Cette version', 'This modified version');
  String get modifiedBy => _t(
    'Modernisée et enrichie par Ivan Gontcharenko — IG Littoral Labs, 2026',
    'Modernised and extended by Ivan Gontcharenko — IG Littoral Labs, 2026',
  );
  String get modifiedWhat => _t(
    '(barres de progression, groupes, fondu, mode scène, export, FR/EN…)',
    '(progress bars, groups, fade out, stage mode, export, FR/EN…)',
  );
  String get contact => _t('Contact', 'Contact');
  String get licence => _t('Licence', 'Licence');
  String get licenceText => _t(
    'Distribuée sous Licence publique de l\'Union européenne (EUPL) v1.2',
    'Released under the European Union Public Licence (EUPL) v1.2',
  );

  // Help
  List<(String, String?)> get helpSections => fr
      ? [
          ('Jouer les sons', null),
          (
            '',
            'Appuyez sur un pad pour lancer son son. L\'application n\'a pas de sons intégrés : chargez les vôtres.',
          ),
          (
            '',
            'Pendant la lecture, le pad est entouré de blanc, se remplit de gauche à droite et affiche le temps restant. Un pad en pause est entouré d\'orange.',
          ),
          ('Bouton STOP', null),
          (
            '',
            'Le grand bouton rouge en haut arrête tous les sons avec un fondu (voir Réglages). Appuyez une seconde fois pour couper immédiatement.',
          ),
          ('Mode scène (cadenas)', null),
          (
            '',
            'Verrouillé, les pads se déclenchent dès que le doigt les touche, on peut en lancer plusieurs à la fois, et l\'appui long comme le menu sont désactivés : rien ne peut être modifié par erreur.',
          ),
          ('Régler les pads', null),
          ('', 'Appui long sur un pad pour ouvrir ses réglages (mode scène désactivé).'),
          ('Son', null),
          (
            '',
            'Le fichier choisi est copié dans l\'application : il continue de fonctionner même si l\'original est déplacé ou si le cache du téléphone est vidé.',
          ),
          ('Pastille rouge', null),
          (
            '',
            'Une pastille rouge sur une touche signale un son illisible : touchez-la pour en voir la raison. Les « faux MP3 » (fichiers vidéo .mpg renommés en .mp3, souvent issus de logiciels de montage) sont réparés automatiquement, sans perte de qualité, à l\'import comme au chargement.',
          ),
          ('Son long', null),
          (
            '',
            'À activer pour une musique ou tout son de plus de 5 secondes environ. Les sons courts utilisent un mode faible latence qui peut couper les fichiers longs.',
          ),
          ('Si on appuie pendant la lecture', null),
          (
            '',
            'Ce qui se passe quand on appuie sur un pad déjà en lecture : Redémarrer, Arrêter (avec fondu) ou Pause.',
          ),
          ('Groupe d\'exclusion', null),
          (
            '',
            'Les pads d\'un même groupe (A, B, C ou D) ne jouent jamais ensemble : en lancer un baisse puis arrête les autres. Idéal pour les musiques de fond.',
          ),
          ('Playlist (plusieurs morceaux sur une touche)', null),
          (
            '',
            'Dans les réglages d\'une touche, « Ajouter des morceaux… » en fait une playlist : chaque appui joue le morceau suivant, dans l\'ordre ou au hasard (sans répétition avant que tous aient été joués). Le morceau suivant est préparé à l\'avance pour partir sans délai. La touche affiche le numéro et le nom du morceau.',
          ),
          ('Conducteur de match', null),
          (
            '',
            'Menu > Conducteurs de match : créez la liste des sons d\'un match dans l\'ordre (une étape = une touche + une note facultative, ex. « au coup de sifflet »). Plusieurs conducteurs possibles (match, mi-temps, Cheers…).',
          ),
          (
            '',
            'L\'icône ☰▶ en haut affiche le conducteur au-dessus de la grille : le gros bouton ▶ joue l\'étape « À suivre » et passe à la suivante, ◀ revient en arrière, ⏭ saute une étape, ☰ montre toutes les étapes (un appui pour y aller). Fonctionne aussi en mode scène. Les étapes suivent leurs touches même si on les déplace ou les change de page.',
          ),
          ('Rechercher un son', null),
          (
            '',
            'La loupe 🔍 en haut ouvre la recherche (aussi en mode scène). Tapez une partie du nom : l\'appli va directement à la page de la première touche trouvée et l\'entoure en bleu. S\'il y a plusieurs résultats, « Entrée » ou les flèches ▲▼ passent au suivant. Majuscules et accents sont ignorés, et le nom du fichier compte aussi.',
          ),
          ('Pages (onglets)', null),
          (
            '',
            'Un projet peut contenir plusieurs pages de pads (par ex. « Match », « Mi-temps », « Animations »). Touchez un onglet pour changer de page, « + » pour en ajouter une, appui long sur un onglet pour la renommer, la dupliquer, la déplacer ou la supprimer.',
          ),
          (
            '',
            'Les sons continuent de jouer quand on change de page : un point vert sur un onglet indique qu\'un de ses sons est en cours. Le bouton STOP arrête les sons de toutes les pages, et les groupes d\'exclusion valent pour tout le projet.',
          ),
          ('Organiser', null),
          (
            '',
            'Dans les réglages d\'un pad : « Échanger / déplacer » pour intervertir deux pads (choisir un pad vide pour déplacer), « Dupliquer vers » pour copier le pad ailleurs, y compris sur une autre page.',
          ),
          ('Importer plusieurs sons', null),
          (
            '',
            'Menu ⋮ > Importer plusieurs sons : sélectionnez autant de fichiers que vous voulez. Ils remplissent, par ordre alphabétique, les touches vides de la page affichée puis des pages suivantes (l\'appli propose d\'ajouter des pages s\'il en manque). Le nom de la touche reprend celui du fichier et l\'option « son long » est réglée selon la durée.',
          ),
          ('Sons en cours et sons récents', null),
          (
            '',
            'En bas de l\'écran, le bandeau « En cours » liste les sons qui jouent, quelle que soit leur page : temps restant, bouton pour arrêter ce son seul, et un appui sur son nom montre la touche. La rangée « récents » rappelle les derniers sons lancés : un appui les relance. Les deux se masquent dans les Réglages.',
          ),
          ('Stockage', null),
          (
            '',
            'Réglages > Stockage indique la place prise par les sons et supprime ceux qui ne servent plus dans aucun projet enregistré (sons remplacés, retirés…). Pensez à enregistrer vos projets avant : un son n\'est considéré comme utilisé que s\'il figure dans un projet enregistré.',
          ),
          ('Exporter / importer', null),
          (
            '',
            'Menu ⋮ > Exporter : crée un fichier .zip contenant le projet et tous ses sons, à enregistrer dans un dossier (Téléchargements, carte SD, clé USB…) ou à envoyer directement (Quick Share vers l\'autre tablette, Drive…). Sur l\'autre appareil : menu ⋮ > Importer un projet, puis choisir ce fichier. Les gros projets (plusieurs Go) sont gérés : prévoir l\'espace libre correspondant.',
          ),
        ]
      : [
          ('Playing Sounds', null),
          (
            '',
            'Press a pad to trigger its sound. The app doesn\'t come with built in sound samples, so you need to load your own.',
          ),
          (
            '',
            'While a sound plays, the pad is outlined in white, fills up from left to right and shows the remaining time. A paused pad is outlined in amber.',
          ),
          ('STOP button', null),
          (
            '',
            'The big red button at the top stops all sounds with a fade out (see Settings). Press it a second time to cut immediately.',
          ),
          ('Stage mode (padlock)', null),
          (
            '',
            'When locked, pads fire as soon as your finger touches them, several pads can be hit at once, and long press / menu are disabled so nothing can be changed by accident.',
          ),
          ('Configuring Pads', null),
          ('', 'Long press a pad to open its settings (stage mode must be off).'),
          ('Sound clip', null),
          (
            '',
            'The chosen file is copied inside the app, so it keeps working even if the original file is moved or the phone cache is cleared.',
          ),
          ('Red badge', null),
          (
            '',
            'A red badge on a pad means its sound cannot be played: tap it to see why. "Fake MP3" files (.mpg video files renamed .mp3, often made by video editors) are repaired automatically, losslessly, on import and on load.',
          ),
          ('Long sound', null),
          (
            '',
            'Turn this on for music or any clip longer than about 5 seconds. Short sounds use a low latency mode that may cut long files.',
          ),
          ('Pad behaviour', null),
          (
            '',
            'What happens when the pad is pressed while its sound is already playing: Restart, Stop (with fade out) or Pause.',
          ),
          ('Exclusion group', null),
          (
            '',
            'Pads in the same group (A, B, C or D) never play together: starting one fades out the others. Ideal for background music.',
          ),
          ('Playlist (several tracks on one pad)', null),
          (
            '',
            'In a pad\'s settings, "Add tracks…" turns it into a playlist: each press plays the next track, in order or random (no repeat before all were played). The next track is prepared in advance so it starts at once. The pad shows the track number and name.',
          ),
          ('Match rundown', null),
          (
            '',
            'Menu > Match rundowns: build the list of the sounds of a match, in order (a step = a pad + an optional note, e.g. "at the whistle"). You can have several rundowns (match, half-time, cheerleaders…).',
          ),
          (
            '',
            'The ☰▶ icon at the top shows the rundown above the grid: the big ▶ button plays the "Up next" step and moves on, ◀ goes back, ⏭ skips a step, ☰ shows all steps (tap one to jump to it). Works in stage mode too. Steps follow their pads even when pads are moved or put on another page.',
          ),
          ('Search a sound', null),
          (
            '',
            'The magnifier 🔍 at the top opens the search (also in stage mode). Type part of the name: the app jumps to the page of the first matching pad and frames it in blue. With several results, "Enter" or the ▲▼ arrows go to the next one. Case and accents are ignored, and file names count too.',
          ),
          ('Pages (tabs)', null),
          (
            '',
            'A project can hold several pages of pads (e.g. "Game", "Half-time", "Shows"). Tap a tab to switch page, "+" to add one, long press a tab to rename, duplicate, move or delete it.',
          ),
          (
            '',
            'Sounds keep playing when you switch page: a green dot on a tab means one of its sounds is playing. STOP stops the sounds of every page, and exclusion groups apply to the whole project.',
          ),
          ('Arrange', null),
          (
            '',
            'In a pad\'s settings: "Swap / move" exchanges two pads (pick an empty pad to move), "Duplicate to" copies the pad elsewhere, including on another page.',
          ),
          ('Import several sounds', null),
          (
            '',
            'Menu ⋮ > Import several sounds: pick as many files as you like. They fill, in alphabetical order, the empty pads of the current page then of the following pages (the app offers to add pages if needed). Pad names come from the file names and "long sound" is set from the length.',
          ),
          ('Now playing and recent sounds', null),
          (
            '',
            'At the bottom, the "Now playing" strip lists the sounds playing on any page: remaining time, a button to stop that sound only, and tapping its name shows the pad. The "recent" row recalls the last sounds started: tap to play again. Both can be hidden in Settings.',
          ),
          ('Storage', null),
          (
            '',
            'Settings > Storage shows the space used by sounds and deletes the ones no saved project uses any more (replaced, removed…). Save your projects first: a sound only counts as used when it is in a saved project.',
          ),
          ('Export / import', null),
          (
            '',
            'Menu ⋮ > Export creates a .zip file with the project and all its sounds, to save in a folder (Downloads, SD card, USB drive…) or send directly (Quick Share to the other tablet, Drive…). On the other device: menu ⋮ > Import a project and pick that file. Big projects (several GB) are fine: just keep that much free space.',
          ),
        ];
}

//==============================================================================
