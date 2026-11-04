import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/loan_request_attachment.dart';
import 'package:perpus_mobile/features/server/server_shell.dart';

void main() {
  testWidgets('evidence type unlocks camera but photo is still required', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MemberLoanRequestPage(
          copy: {
            'id': 'test-copy',
            'code': 'TEST-01',
            'books': {'id': 'test-book', 'title': 'Buku uji'},
          },
        ),
      ),
    );
    final camera = find.widgetWithText(
      OutlinedButton,
      'Pilih jenis bukti terlebih dahulu',
    );
    expect(tester.widget<OutlinedButton>(camera).onPressed, isNull);
    await tester.tap(find.text('Selfie'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Ambil foto bukti'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Ajukan pinjaman'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Pinjam sekarang'), findsNothing);
    expect(find.text('Lampiran tambahan (opsional)'), findsOneWidget);
    expect(
      find.textContaining('Foto bukti selfie/kartu tetap wajib.'),
      findsOneWidget,
    );
  });

  test('accepts a supported PDF attachment within the existing size limit', () {
    final bytes = Uint8List(LoanRequestAttachment.maxBytes)
      ..setRange(0, 5, '%PDF-'.codeUnits);
    final attachment = LoanRequestAttachment.parse(
      name: 'dokumen-uji.pdf',
      bytes: bytes,
    );

    expect(attachment.contentType, 'application/pdf');
    expect(attachment.bytes, hasLength(LoanRequestAttachment.maxBytes));
  });

  test('accepts JPEG and PNG photo attachments by file signature', () {
    expect(
      LoanRequestAttachment.parse(
        name: 'foto.JPG',
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ).contentType,
      'image/jpeg',
    );
    expect(
      LoanRequestAttachment.parse(
        name: 'foto.png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ).contentType,
      'image/png',
    );
  });

  test('rejects unsupported, empty, oversized, and mislabeled attachments', () {
    expect(
      () => LoanRequestAttachment.parse(
        name: 'video.mp4',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsFormatException,
    );
    expect(
      () =>
          LoanRequestAttachment.parse(name: 'kosong.pdf', bytes: Uint8List(0)),
      throwsFormatException,
    );
    expect(
      () => LoanRequestAttachment.parse(
        name: 'terlalu-besar.pdf',
        bytes: Uint8List(LoanRequestAttachment.maxBytes + 1),
      ),
      throwsFormatException,
    );
    expect(
      () => LoanRequestAttachment.parse(
        name: 'palsu.pdf',
        bytes: Uint8List.fromList('bukan pdf'.codeUnits),
      ),
      throwsFormatException,
    );
  });
}
