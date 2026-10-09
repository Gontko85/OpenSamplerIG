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

  // Export / import
  String get exporting => _t('Préparation de l\'export…', 'Preparing export…');
  String get importing => _t('Import en cours…', 'Importing…');
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
  String get looped => _t('En boucle :', 'Looped:');
  String get longSound => _t('Son long (musique, > 5 s) :', 'Long sound (music, > 5 s):');
  String get behaviour => _t('Si on appuie pendant la lecture :', 'Behaviour when pressed while playing:');
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
  String get fontDefault => _t('Par défaut', 'Default');
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
          ('Exporter / importer', null),
          (
            '',
            'Menu ⋮ > Exporter : crée un fichier .zip contenant le projet et tous ses sons, à enregistrer (Téléchargements, Drive…). Sur un autre appareil : menu ⋮ > Importer, puis choisir ce fichier.',
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
          ('Export / import', null),
          (
            '',
            'Menu ⋮ > Export creates a .zip file with the project and all its sounds, to save anywhere (Downloads, Drive…). On another device: menu ⋮ > Import and pick that file.',
          ),
        ];
}

//==============================================================================
