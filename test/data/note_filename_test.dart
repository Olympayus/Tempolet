import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/models/note_format.dart';
import 'package:tempolet/data/vault/note_filename.dart';

void main() {
  group('sanitizeNoteTitle', () {
    test(
      'replaces Windows-illegal and control characters with underscores',
      () {
        expect(sanitizeNoteTitle('  a/b:c  '), 'a_b_c');
        expect(
          sanitizeNoteTitle(r'a<b>c:d"e/f\g|h?i*j'),
          'a_b_c_d_e_f_g_h_i_j',
        );
        expect(sanitizeNoteTitle('a\u0000b\u001fc'), 'a_b_c');
      },
    );

    test('falls back to Untitled for empty or whitespace-only titles', () {
      expect(sanitizeNoteTitle(''), 'Untitled');
      expect(sanitizeNoteTitle('   '), 'Untitled');
    });

    test('prefixes Windows reserved device names', () {
      expect(sanitizeNoteTitle('CON'), '_CON');
      expect(sanitizeNoteTitle('prn'), '_prn');
      expect(sanitizeNoteTitle('COM9'), '_COM9');
      expect(sanitizeNoteTitle('LPT1'), '_LPT1');
      expect(sanitizeNoteTitle('CON.txt'), '_CON.txt');
      expect(sanitizeNoteTitle('CONSOLE'), 'CONSOLE');
    });

    test('trims, collapses whitespace runs, and caps at 80 runes', () {
      expect(sanitizeNoteTitle('  a   b  '), 'a b');

      final sanitized = sanitizeNoteTitle('字' * 81);
      expect(sanitized.runes.length, 80);
      expect(sanitized, '字' * 80);
    });

    test('truncation never yields an empty title', () {
      expect(sanitizeNoteTitle(' ' * 100), 'Untitled');
    });

    test('replaces a leading run of dots so titles never become hidden', () {
      expect(sanitizeNoteTitle('.hidden'), '_hidden');
      expect(sanitizeNoteTitle('..notes'), '_notes');
      expect(sanitizeNoteTitle('.'), '_');
      expect(
        buildNoteFileName(
          title: '.hidden',
          shortId: 'abcd',
          format: NoteFormat.md,
        ),
        '_hidden~abcd.md',
      );
    });
  });

  group('parseShortId', () {
    test('reads a lowercase four-hex suffix after dropping the extension', () {
      expect(parseShortId('产品周会~7f3a.md'), '7f3a');
      expect(parseShortId('a~7f3a.txt'), '7f3a');
      expect(parseShortId('nested/a~7f3a.md'), '7f3a');
    });

    test('does not mistake ordinary hex-looking titles for an id', () {
      expect(parseShortId('Budget-cafe.md'), isNull);
      expect(parseShortId('产品周会~7F3A.md'), isNull);
      expect(parseShortId('产品周会.md'), isNull);
    });
  });

  group('buildNoteFileName', () {
    test('composes a sanitized title, lowercased short id, and extension', () {
      expect(
        buildNoteFileName(
          title: '产品周会',
          shortId: '7f3a',
          format: NoteFormat.md,
        ),
        '产品周会~7f3a.md',
      );
      expect(
        buildNoteFileName(
          title: 'a/b',
          shortId: 'ABCD',
          format: NoteFormat.txt,
        ),
        'a_b~abcd.txt',
      );
      expect(
        buildNoteFileName(title: '   ', shortId: '7f3a', format: NoteFormat.md),
        'Untitled~7f3a.md',
      );
    });
  });

  group('titleFromNoteFileName', () {
    test('strips the short id suffix and extension', () {
      expect(titleFromNoteFileName('产品周会~7f3a.md'), '产品周会');
      expect(titleFromNoteFileName('a~7f3a.txt'), 'a');
    });

    test('keeps titles without a valid short id intact', () {
      expect(titleFromNoteFileName('Budget-cafe.md'), 'Budget-cafe');
    });
  });
}
