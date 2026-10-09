//==============================================================================
//    about_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'l10n.dart';

//==============================================================================

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _link(String text, String url) => InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(text, style: const TextStyle(color: Colors.blueGrey, decoration: TextDecoration.underline)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.about)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text("Open Sampler IG v${packageInfo.version}", style: const TextStyle(fontSize: 24)),
          const Divider(),
          Text(S.aboutTagline),
          const SizedBox(height: 16),
          Text(S.originalApp, style: const TextStyle(fontSize: 18)),
          const Divider(),
          const Text("Developed by Leszek \"Лешы\" Szczepański — Cherry Tree Studio, 2021"),
          _link('Open Sampler @ GitHub', 'https://github.com/trvekvltgames/opensampler'),
          const SizedBox(height: 16),
          Text(S.thisVersion, style: const TextStyle(fontSize: 18)),
          const Divider(),
          Text(S.modifiedBy),
          Text(S.modifiedWhat),
          _link(S.contact, 'https://www.linkedin.com/in/ivangontcharenko'),
          const SizedBox(height: 16),
          Text(S.licence, style: const TextStyle(fontSize: 18)),
          const Divider(),
          Text(S.licenceText),
          _link('EUPL v1.2', 'https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12'),
        ],
      ),
    );
  }
}

//==============================================================================
