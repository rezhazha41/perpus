# Implementasi dan Unit Testing Lampiran Pengajuan Perpus

Tanggal: 4 November 2026

Lampiran berkas tambahan untuk pengajuan pinjaman bersifat opsional. Selfie atau foto kartu siswa tetap merupakan bukti utama yang wajib. Test menggunakan data sintetis dan callback palsu; tidak membaca foto pribadi, membuka kamera, mengakses jaringan, atau menyentuh Supabase produksi.

## Perubahan implementasi

- Anggota dapat memilih satu PDF/JPEG/PNG maksimal 10 MiB. Batas berasal dari bucket `loan-evidence` yang sudah ada. Validasi memeriksa extension, MIME signature, dan ukuran.
- File masuk ke bucket privat sebelum RPC pengajuan dipanggil. Path deterministik memakai request key. Jika hasil RPC ambigu, retry menggunakan key/path yang sama dan kontrol bukti dikunci agar data yang sudah dicoba tidak diganti menjadi permintaan baru.
- RPC kandidat membuat metadata idempoten dan menjaga akses anggota/pengurus melalui RLS. Pengurus dapat melihat preview PDF/gambar. Lampiran mengikuti jadwal retensi foto bukti utama.
- Migrasi `202611040001_optional_loan_attachments.sql` belum diterapkan ke server aktif. Jangan rilis client yang memanggil RPC baru sebelum migrasi disetujui dan diterapkan.
- Tidak ada dukungan video atau banyak lampiran.

## Cara menjalankan test fokus
```powershell
Set-Location D:\apps\Perpus\apps\mobile
C:\flutter\bin\flutter.bat test --no-pub test\loan_request_evidence_test.dart test\loan_request_submission_test.dart
```
Hasil sesi ini: **PASS 9/9**, exit code 0. Suite Flutter penuh sengaja tidak dijalankan sesuai ruang lingkup tugas.

## Demo dan bukti untuk dosen

1. Tampilkan `loan_request_evidence_test.dart`: pilih “Selfie”; kamera terbuka setelah jenis bukti dipilih, tetapi tombol pengajuan tetap nonaktif karena foto belum diambil. Tunjukkan label “Lampiran tambahan (opsional)”.
2. Jalankan perintah focused test di atas dan tunjukkan total 9 test lulus.
3. Jelaskan skenario timeout: upload fake berhasil, RPC pertama memberi timeout, retry tidak upload ulang dan memakai path serta key yang sama.
4. Jelaskan skenario gagal upload: error diteruskan dan hitungan pemanggilan RPC tetap nol.
5. Jelaskan validator: PDF/JPEG/PNG lolos bila signature sesuai; file kosong, format lain, isi palsu, dan ukuran di atas 10 MiB ditolak.

Bukti gambar yang dilampirkan adalah `docs/unit-testing/evidence/unit-testing-results.jpg`, dibuat dari hasil aktual command di atas (bukan mock). Output teks asli tersimpan di `docs/unit-testing/evidence/flutter-test-output.txt`. Dua file test utuh juga disertakan di `docs/unit-testing/code/`. Repo tugas ini berisi bahan presentasi; jalankan test di repo sumber aplikasi karena checkout ini tidak menyertakan aplikasi Flutter maupun `pubspec.yaml`.

## Isi lengkap `loan_request_evidence_test.dart`
```dart
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

```

## Isi lengkap `loan_request_submission_test.dart`
```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/loan_request_submission.dart';

void main() {
  test(
    'uploads evidence before RPC and reuses key/path after ambiguous failure',
    () async {
      var nextKey = 0;
      final submission = LoanRequestSubmission(() => 'request-${++nextKey}');
      final events = <String>[];
      var rpcCalls = 0;

      Future<void> send() => submission.submit(
        memberId: 'member-a',
        extension: 'jpg',
        uploadEvidence: (path) async => events.add('upload:$path'),
        createRequest: (key, path, _) async {
          events.add('rpc:$key:$path');
          if (++rpcCalls == 1) throw TimeoutException('response unknown');
        },
      );

      await expectLater(send(), throwsA(isA<TimeoutException>()));
      expect(submission.evidenceUploaded, isTrue);
      expect(submission.requestAttempted, isTrue);
      await send();

      expect(events, [
        'upload:member-a/request-1.jpg',
        'rpc:request-1:member-a/request-1.jpg',
        'rpc:request-1:member-a/request-1.jpg',
      ]);
      expect(nextKey, 1);
    },
  );

  test('does not call the RPC when evidence upload fails', () async {
    final submission = LoanRequestSubmission(() => 'request-1');
    var rpcCalls = 0;

    await expectLater(
      submission.submit(
        memberId: 'member-a',
        extension: 'jpg',
        uploadEvidence: (_) async => throw StateError('offline'),
        createRequest: (_, _, _) async => rpcCalls++,
      ),
      throwsA(isA<StateError>()),
    );

    expect(rpcCalls, 0);
    expect(submission.evidenceUploaded, isFalse);
  });

  test('new evidence resets the idempotency identity', () async {
    var nextKey = 0;
    final submission = LoanRequestSubmission(() => 'request-${++nextKey}');
    final requestKeys = <String>[];

    Future<void> send() => submission.submit(
      memberId: 'member-a',
      extension: 'jpg',
      uploadEvidence: (_) async {},
      createRequest: (key, _, _) async => requestKeys.add(key),
    );

    await send();
    submission.reset();
    expect(submission.requestAttempted, isFalse);
    await send();

    expect(requestKeys, ['request-1', 'request-2']);
  });

  test('uploads optional attachment before RPC and reuses its path on retry', () async {
    final submission = LoanRequestSubmission(() => 'request-1');
    final events = <String>[];
    var rpcCalls = 0;

    Future<void> send() => submission.submit(
      memberId: 'member-a',
      extension: 'jpg',
      uploadEvidence: (path) async => events.add('evidence:$path'),
      attachmentExtension: 'pdf',
      uploadAttachment: (path) async => events.add('attachment:$path'),
      createRequest: (key, evidencePath, attachmentPath) async {
        events.add('rpc:$key:$evidencePath:$attachmentPath');
        if (++rpcCalls == 1) throw TimeoutException('response unknown');
      },
    );

    await expectLater(send(), throwsA(isA<TimeoutException>()));
    await send();

    expect(events, [
      'evidence:member-a/request-1.jpg',
      'attachment:member-a/request-1-attachment.pdf',
      'rpc:request-1:member-a/request-1.jpg:member-a/request-1-attachment.pdf',
      'rpc:request-1:member-a/request-1.jpg:member-a/request-1-attachment.pdf',
    ]);
  });

  test('attachment upload failure does not call the RPC', () async {
    final submission = LoanRequestSubmission(() => 'request-1');
    var rpcCalls = 0;

    await expectLater(
      submission.submit(
        memberId: 'member-a',
        extension: 'jpg',
        uploadEvidence: (_) async {},
        attachmentExtension: 'pdf',
        uploadAttachment: (_) async => throw StateError('offline'),
        createRequest: (_, _, _) async => rpcCalls++,
      ),
      throwsA(isA<StateError>()),
    );

    expect(rpcCalls, 0);
  });
}

```

## Cara membaca test

### `loan_request_evidence_test.dart`

- `Uint8List` membentuk bytes dummy, sehingga test tidak memakai file pengguna.
- `LoanRequestAttachment.parse` diuji untuk signature PDF, JPEG, PNG, batas 10 MiB, file kosong, ekstensi/isi tidak cocok, dan format yang tidak didukung.
- Widget test merender form dengan buku sintetis. Setelah jenis foto dipilih, tombol kamera aktif. Tanpa hasil foto, tombol “Ajukan pinjaman” tetap nonaktif. Test memastikan lampiran hanya tambahan dan foto utama tetap wajib.

### `loan_request_submission_test.dart`

- `LoanRequestSubmission` menjaga request key, evidence path, attachment path, dan state upload.
- Callback upload dan RPC adalah fake; daftar `events` membuktikan urutan, tanpa Supabase/network.
- Timeout setelah RPC pertama meniru hasil server yang belum diketahui. Test memastikan retry tidak upload ulang serta menggunakan key/path yang sama.
- `requestAttempted` memastikan perubahan bukti/lampiran dikunci setelah mutasi dicoba. Ini mencegah pengguna membuat request key baru untuk transaksi yang hasilnya ambigu.
- Test kegagalan upload memastikan RPC tidak dipanggil. Test `reset` memastikan bukti baru sebelum percobaan RPC mendapat key baru.

## Hasil dan batas verifikasi

- `flutter test --no-pub test/loan_request_evidence_test.dart test/loan_request_submission_test.dart`: **PASS 9/9**, exit 0.
- `flutter analyze --no-pub` pada lima file yang berubah: **PASS**, exit 0.
- `node --test supabase/functions/evidence-retention/processor.test.mjs`: **PASS 6/6**.
- `node scripts/sql-tests/test.mjs`: **PASS** dengan PGlite. Ini bukan bukti Supabase/Storage runtime atau multi-connection.
- `git diff --check`: **PASS**, exit 0.
- Seluruh Flutter suite, perangkat Android, runtime Storage/RLS, dan penerapan migrasi: **NOT RUN**.

Unit test tidak membuktikan file picker/preview pada perangkat, layanan Supabase nyata, RLS runtime, atau penerapan migrasi. Perubahan hanya lokal; belum commit/push. Jika nanti diunggah sebagai tugas, tujuan yang ditentukan adalah repo skripsi `https://github.com/rezhazha41/perpus`, bukan repo aplikasi sumber.

## Berkas unit testing yang disertakan

- docs/unit-testing/code/loan_request_evidence_test.dart: salinan utuh test widget dan validasi lampiran dari aplikasi sumber.
- docs/unit-testing/code/loan_request_submission_test.dart: salinan utuh test urutan upload, kegagalan upload, dan retry pengajuan.
- docs/unit-testing/evidence/unit-testing-results.jpg: gambar hasil aktual, 9 dari 9 test PASS.
- docs/unit-testing/evidence/flutter-test-output.txt: keluaran teks command test yang dijalankan.

File test disalin sebagai bahan tugas dan pembacaan kode. Test dijalankan dari repo aplikasi pps-perpus, bukan dari repo dokumentasi perpus.
