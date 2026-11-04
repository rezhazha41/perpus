# Unit Testing Lampiran Berkas

## Tujuan

Dokumen ini menjelaskan cara menguji fitur lampiran berkas pada aplikasi Perpus :

> Unit Testing Lampiran Berkas (Dokumen, Gambar, Video)

Dokumen ini adalah panduan pengujian.

## Status implementasi yang ditemukan

Pada alur pengajuan pinjaman, lampiran saat ini adalah foto bukti. Pengguna memilih jenis bukti, mengambil foto, aplikasi memeriksa wajah, lalu mengunggah JPEG/PNG ke bucket privat `loan-evidence` sebelum memanggil RPC `submit_loan_request`.

Test yang sudah ada:

- `apps/mobile/test/loan_request_evidence_test.dart`: menguji bahwa pengguna harus memilih jenis bukti sebelum kamera aktif dan foto tetap wajib sebelum pengajuan.
- `apps/mobile/test/loan_request_submission_test.dart`: menguji upload mendahului RPC, RPC tidak dipanggil ketika upload gagal, retry memakai request key/path yang sama setelah hasil timeout tidak diketahui, dan lampiran baru memulai identitas request baru.

PDF/dokumen dan video belum menjadi format lampiran untuk alur pengajuan pinjaman tersebut. Jangan mengubah test untuk menganggap PDF/video didukung tanpa keputusan produk, validasi ukuran/MIME, dan aturan Storage yang sesuai. Pengujian lintas akun/RLS dan isi bucket adalah integration test, bukan bukti unit test. Implementasi Flutter yang dirujuk berada di repo sumber aplikasi [`apps-perpus`](https://github.com/rezhazha41/apps-perpus); repo skripsi `perpus` adalah repo dokumentasi/tugas yang terpisah.

## Rencana pengujian

| Area | Perilaku yang diuji | Jenis test |
|---|---|---|
| Pemilihan | Kamera diblokir sebelum jenis bukti dipilih; pembatalan kamera tidak mengirim pengajuan | Widget |
| Validasi gambar | Format yang diizinkan diterima; format lain dan berkas kosong/terlalu besar ditolak jika batas tersebut memang ditetapkan | Unit |
| Urutan operasi | Berkas berhasil diunggah sebelum RPC dibuat | Unit dengan fake |
| Kegagalan | Upload gagal berarti RPC tidak dipanggil dan UI tidak menyatakan berhasil | Unit/widget |
| Timeout ambigu | Retry manual memakai request key dan object path yang sama; tidak membuat mutasi kedua | Unit |
| Lampiran baru | Mengganti foto mereset identitas request sesuai alur sekarang | Unit |
| Otorisasi Storage | Anon/anggota lain ditolak; pemilik dan pengurus mendapat akses sesuai policy | Integration pada Supabase disposable |
| Format dokumen/video | Hanya diuji jika fitur tersebut sudah disetujui dan benar-benar didukung end-to-end | Unit + integration |

Batas ukuran dan tipe MIME tidak boleh ditebak. Sebelum menambah pengujian ukuran atau PDF/video, cari batas yang berlaku di PRD, konfigurasi Storage, migrasi, dan UI. Bila belum ditetapkan, dokumentasikan sebagai keputusan yang diperlukan, bukan membuat angka produk baru.

## Cara implementasi bertahap

1. Periksa widget, helper, konfigurasi bucket, RPC, dan test yang ada. Pertahankan perilaku pengajuan: upload sukses harus terjadi sebelum RPC.
2. Tentukan kontrak lampiran yang memang didukung. Untuk alur sekarang, kontraknya adalah foto bukti JPEG/PNG; jangan menambahkan PDF/video secara diam-diam.
3. Tambahkan atau sesuaikan test yang gagal terlebih dahulu untuk bug/perilaku yang akan dikerjakan. Gunakan fake callback/repository agar unit test tidak mengakses jaringan, Supabase aktif, kamera, atau file pribadi.
4. Implementasikan perubahan terkecil di helper/use case yang sudah ada. Hindari memindahkan seluruh logika server shell hanya demi test.
5. Jalankan test terfokus, seluruh test Flutter, analyzer, dan `git diff --check`. Untuk policy Storage/RLS gunakan stack disposable yang isolasinya sudah dibuktikan; unit test tidak membuktikan RLS runtime.
6. Catat hasil aktual. Jangan memasukkan foto siswa, OTP, token, atau data akun ke fixture, screenshot, log, maupun commit.

## Isi lengkap unit test pengajuan bukti

Berikut isi lengkap `apps/mobile/test/loan_request_submission_test.dart` pada repo sumber aplikasi:

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
        createRequest: (key, path) async {
          events.add('rpc:$key:$path');
          if (++rpcCalls == 1) throw TimeoutException('response unknown');
        },
      );

      await expectLater(send(), throwsA(isA<TimeoutException>()));
      expect(submission.evidenceUploaded, isTrue);
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
        createRequest: (_, _) async => rpcCalls++,
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
      createRequest: (key, _) async => requestKeys.add(key),
    );

    await send();
    submission.reset();
    await send();

    expect(requestKeys, ['request-1', 'request-2']);
  });
}
```

### Penjelasan import dan susunan test

- `import 'dart:async';` menyediakan `TimeoutException`, yang dipakai untuk meniru kondisi server menerima request tetapi jawaban tidak sampai ke aplikasi.
- `flutter_test.dart` menyediakan fungsi test dan assertion seperti `test`, `expect`, `expectLater`, `throwsA`, serta `isA`.
- `loan_request_submission.dart` adalah unit produksi yang sedang diuji. Test memanggil unit ini langsung, bukan widget, kamera, Supabase, atau jaringan sungguhan.
- `void main()` adalah titik kumpul test yang ditemukan dan dijalankan Flutter Test.
- Setiap `test(...)` adalah satu skenario terpisah. Fungsi `() async { ... }` membuat skenario bisa menunggu operasi `Future`.
- `LoanRequestSubmission(() => 'request-...')` diberi pembangkit ID buatan agar hasil stabil dan mudah dibandingkan. Test tidak membuat ID acak atau transaksi nyata.
- Callback `uploadEvidence` dan `createRequest` adalah pengganti (fake) untuk dua efek eksternal: unggah file dan membuat pengajuan. Karena callback berada dalam kendali test, urutan, jumlah pemanggilan, dan kegagalannya dapat diperiksa.

### Test 1: urutan upload dan retry setelah timeout ambigu

Test pertama memastikan upload terjadi sebelum RPC. Fungsi lokal `send()` menjalankan submit dengan callback palsu. Callback upload menambahkan peristiwa `upload:<path>` ke `events`. Callback RPC menambahkan `rpc:<key>:<path>` dan melempar `TimeoutException` hanya pada pemanggilan pertama.

`expectLater(send(), throwsA(isA<TimeoutException>()))` memastikan kegagalan pertama benar-benar diteruskan. Setelah itu `evidenceUploaded` harus `true`, sebab upload selesai sebelum respons RPC timeout. Pemanggilan `send()` kedua mensimulasikan retry manual. Assertion pada `events` memastikan upload tidak diulang, sedangkan RPC kedua memakai key dan path yang sama. `expect(nextKey, 1)` membuktikan retry tidak membuat key baru. Ini menguji perlindungan dari duplikasi berdasarkan idempotency key; test ini sendiri tidak menghubungi atau membuktikan perilaku server.

### Test 2: upload gagal menghentikan pengajuan

Callback upload langsung melempar `StateError('offline')` untuk mensimulasikan kegagalan jaringan. Callback RPC menaikkan `rpcCalls` jika dipanggil. `expectLater(... throwsA(isA<StateError>()))` memastikan error upload tidak ditelan. `expect(rpcCalls, 0)` memastikan pengajuan tidak diteruskan, dan `evidenceUploaded` tetap `false` supaya status unit tidak menyatakan file telah tersimpan.

### Test 3: bukti baru mendapat identitas baru

Test mengirim satu pengajuan, memanggil `submission.reset()` saat bukti diganti, lalu mengirim lagi. Callback RPC menyimpan key ke `requestKeys`. Hasil `['request-1', 'request-2']` membuktikan reset membuat pengajuan berikutnya menggunakan identitas baru, bukan key/path milik lampiran sebelumnya.


Pakai pola **Arrange – Act – Assert**:

1. **Arrange (siapkan):** buat `LoanRequestSubmission`, penghitung, daftar peristiwa, dan callback palsu.
2. **Act (jalankan):** panggil `submit()` atau `reset()` sesuai skenario.
3. **Assert (buktikan):** gunakan `expect` untuk memeriksa error, jumlah panggilan RPC, status upload, urutan operasi, dan penggunaan key/path.

Contoh kalimat: “Test ini mensimulasikan upload yang gagal. Saya memastikan error muncul, RPC tidak terpanggil, dan status bukti tidak berubah menjadi berhasil. Jadi test tidak membutuhkan foto sungguhan atau koneksi ke server.”

Contoh ini menguji perilaku unit `LoanRequestSubmission`; ia tidak menguji koneksi Storage sungguhan, policy RLS, kamera, atau apakah file di server benar-benar dapat dibaca.

Test widget yang sudah ada memakai pola serupa:

- **Arrange:** render `MemberLoanRequestPage` dengan buku sintetis.
- **Act:** periksa tombol, pilih “Selfie”, lalu render ulang.
- **Assert:** tombol kamera aktif, tombol pengajuan tetap nonaktif sebelum foto dipilih, dan label alur pinjam lama tidak muncul.

## Menjalankan test

Dari PowerShell:

```powershell
Set-Location D:\apps\Perpus\apps\mobile
C:\flutter\bin\flutter.bat test --no-pub test\loan_request_evidence_test.dart test\loan_request_submission_test.dart
C:\flutter\bin\flutter.bat analyze --no-pub
C:\flutter\bin\flutter.bat test --no-pub
```

Catat exit code dan output lengkap yang relevan untuk setiap command. Jika Flutter SDK berada di lokasi lain, gunakan path yang terdeteksi pada mesin tersebut.

## Kriteria selesai untuk implementasi test

- Test menguji perilaku lampiran yang benar-benar didukung produk.
- Kegagalan upload tidak membuat RPC atau menampilkan sukses palsu.
- Retry setelah hasil ambigu tidak menggandakan pengajuan.
- Unit test tidak menyentuh server produksi atau memakai berkas pribadi.
- Dukungan format dan batas ukuran berasal dari kontrak yang disetujui dan cocok dengan kebijakan Storage.
- Hasil test, analyzer, dan pemeriksaan diff dicatat; link commit/PR hanya dicantumkan setelah benar-benar dibuat.
