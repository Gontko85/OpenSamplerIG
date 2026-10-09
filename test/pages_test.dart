import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/project_archive.dart';
import 'package:opensampler/settings.dart';

void main() {
  setUpAll(() {
    documentDirectory = Directory.systemTemp.createTempSync('os_pages');
  });

  Settings demo() {
    final s = Settings.temp('Match', 2, 2);
    s.padsOfPage(0)[0].caption = 'A1';
    s.addPage('Mi-temps');
    s.padsOfPage(1)[3].caption = 'B4';
    s.addPage('');
    s.padsOfPage(2)[1].caption = 'C2';
    return s;
  }

  test('old single-page project opens as one page', () {
    final s = Settings.temp('Old', 2, 1);
    final json = '{"name":"Old","x":2,"y":1,"padSettings":${'[${s.padSettings.map((p) => '{"caption":"x","sample":""}').join(',')}]'}}';
    final r = Settings.fromJson(File('o.json'), json);
    expect(r.pageCount, 1);
    expect(r.padSettings.length, 2);
  });

  test('pages round-trip through JSON', () {
    final s = demo()..currentPage = 2;
    final r = Settings.fromJson(File('p.json'), s.getJson());
    expect(r.pageCount, 3);
    expect(r.pageNames, ['', 'Mi-temps', '']);
    expect(r.padsOfPage(0)[0].caption, 'A1');
    expect(r.padsOfPage(1)[3].caption, 'B4');
    expect(r.padsOfPage(2)[1].caption, 'C2');
    expect(r.currentPage, 2);
    expect(r.pageLabel(2, (n) => 'Page $n'), 'Page 3');
  });

  test('grid resize keeps each page own pads', () {
    final s = demo();
    s.x = 3;
    s.y = 2;
    s.validate();
    expect(s.padSettings.length, 18);
    expect(s.padsOfPage(1)[3].caption, 'B4');
    expect(s.padsOfPage(2)[1].caption, 'C2');
    s.x = 1;
    s.y = 1;
    s.validate();
    expect(s.padSettings.length, 3);
    expect(s.padsOfPage(0)[0].caption, 'A1');
  });

  test('move, duplicate and remove pages', () {
    final s = demo();
    s.movePage(2, -1);
    expect(s.pageNames, ['', '', 'Mi-temps']);
    expect(s.padsOfPage(1)[1].caption, 'C2');
    expect(s.padsOfPage(2)[3].caption, 'B4');
    final d = s.duplicatePage(2, 'Copie');
    expect(d, 3);
    expect(s.padsOfPage(3)[3].caption, 'B4');
    expect(identical(s.padsOfPage(3)[3], s.padsOfPage(2)[3]), false);
    s.removePage(0);
    expect(s.pageCount, 3);
    expect(s.padsOfPage(0)[1].caption, 'C2');
    s.removePage(0);
    s.removePage(0);
    s.removePage(0); // the last page is never removed
    expect(s.pageCount, 1);
  });

  test('export / import keeps pages', () async {
    final src = Directory.systemTemp.createTempSync('os_psrc');
    final f = File('${src.path}/hymne.mp3')..writeAsBytesSync(List.filled(1000, 7));
    final s = demo();
    s.padsOfPage(1)[3].sample = f.path;
    final zip = await ProjectArchive.export(s);
    final (r, count) = await ProjectArchive.import(zip);
    expect(count, 1);
    expect(r.pageCount, 3);
    expect(r.pageNames[1], 'Mi-temps');
    expect(File(r.padsOfPage(1)[3].sample).existsSync(), true);
  });
}
