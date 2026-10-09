//==============================================================================
//    help_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';

//==============================================================================

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const h1 = TextStyle(fontSize: 24);
    const h2 = TextStyle(fontSize: 18);
    const gap = SizedBox(height: 10);

    Widget iconLine(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text("Help")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text("Playing Sounds", style: h1),
          const Divider(),
          const Text("Press a pad to trigger its sound. The app doesn't come with built in sound samples, so you need to load your own."),
          gap,
          const Text("While a sound plays, the pad is outlined in white, fills up from left to right and shows the remaining time. A paused pad is outlined in amber."),
          const SizedBox(height: 20),
          iconLine(Icons.volume_off_rounded,
              "Stops all sounds with a short fade out (see Settings). Press it a second time to cut immediately."),
          iconLine(Icons.lock_open,
              "Stage mode. When locked, pads fire as soon as your finger touches them, several pads can be hit at once, and long press / menu are disabled so nothing can be changed by accident."),
          const SizedBox(height: 20),
          const Text("Configuring Pads", style: h1),
          const Divider(),
          const Text("Long press a pad to open its settings (stage mode must be off)."),
          gap,
          const Text("Sound clip", style: h2),
          gap,
          const Text("The chosen file is copied inside the app, so it keeps working even if the original file is moved or the phone cache is cleared."),
          gap,
          const Text("Long sound", style: h2),
          gap,
          const Text("Turn this on for music or any clip longer than about 5 seconds. Short sounds use a low latency mode that may cut long files."),
          gap,
          const Text("Pad behaviour", style: h2),
          gap,
          const Text("Defines what happens when the pad is pressed while its sound is already playing: Restart, Stop (with fade out) or Pause."),
          gap,
          const Text("Exclusion group", style: h2),
          gap,
          const Text("Pads in the same group (A, B, C or D) never play together: starting one fades out the others. Ideal for background music."),
        ],
      ),
    );
  }
}

//==============================================================================
