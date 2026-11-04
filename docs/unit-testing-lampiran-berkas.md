# Unit Testing Lampiran Berkas

## Tujuan

Dokumen ini menjelaskan cara menguji fitur lampiran berkas pada aplikasi Perpus dan cara menyiapkan bukti commit atau Pull Request GitHub untuk tugas:

> Unit Testing Lampiran Berkas (Dokumen, Gambar, Video)

Dokumen ini adalah panduan pengujian, bukan implementasi dukungan lampiran dokumen atau video. Kode serta test yang ada harus diperiksa kembali sebelum pekerjaan implementasi dimulai.

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

## Contoh unit test yang sudah ada

Berikut pola yang dipakai `loan_request_submission_test.dart` (diringkas):

```dart
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
```

Penjelasan:

1. `LoanRequestSubmission` dibuat dengan pembangkit ID deterministik agar test tidak bergantung pada UUID acak.
2. `rpcCalls` menghitung apakah mutasi pengajuan pernah dipanggil.
3. `uploadEvidence` dibuat gagal secara terkontrol, mensimulasikan kondisi offline.
4. `expectLater(... throwsA(...))` memastikan kegagalan upload diteruskan ke pemanggil, bukan disamarkan sebagai sukses.
5. `expect(rpcCalls, 0)` adalah assertion utama: tanpa bukti yang terunggah, RPC tidak boleh dijalankan.
6. `evidenceUploaded` harus tetap `false`, sehingga retry berikutnya tidak menganggap upload berhasil.

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

## Bukti GitHub: commit atau Pull Request

GitHub menggunakan istilah **Pull Request (PR)**; “Merge Request (MR)” adalah istilah yang umum dipakai layanan Git lain.

Repositori tujuan versi skripsi: [github.com/rezhazha41/perpus](https://github.com/rezhazha41/perpus). Setelah commit dan PR dibuat, cantumkan URL GitHub yang benar-benar dihasilkan pada laporan pengumpulan tugas. Jangan mengisi URL tebakan.

1. Pastikan diff hanya berisi perubahan yang dimaksud dan tidak memuat file rahasia atau data uji pribadi.
2. Jalankan test terfokus, suite Flutter, analyzer, dan `git diff --check`; cantumkan hasilnya pada deskripsi PR.
3. Buat commit dengan pesan yang menjelaskan cakupan test.
4. Push ke repositori/branch yang telah ditentukan pemilik proyek, lalu buat PR GitHub bila diminta.
Repositori skripsi tersebut terpisah dari repo proyek asli. Pastikan perubahan yang dikirim hanya masuk ke repo skripsi yang benar.

## Kriteria selesai untuk implementasi test

- Test menguji perilaku lampiran yang benar-benar didukung produk.
- Kegagalan upload tidak membuat RPC atau menampilkan sukses palsu.
- Retry setelah hasil ambigu tidak menggandakan pengajuan.
- Unit test tidak menyentuh server produksi atau memakai berkas pribadi.
- Dukungan format dan batas ukuran berasal dari kontrak yang disetujui dan cocok dengan kebijakan Storage.
- Hasil test, analyzer, dan pemeriksaan diff dicatat; link commit/PR hanya dicantumkan setelah benar-benar dibuat.
