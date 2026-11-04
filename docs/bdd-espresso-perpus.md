# BDD Android Perpus dengan Espresso

## Cakupan

Skenario kecil ini memeriksa batas Android native: ketika Android mengirimkan
tautan reset ke `MainActivity`, activity mempertahankan URI tersebut dan host
Flutter tampil. Test ini tidak mengirim OTP, mengganti kata sandi, menguji
verifikasi domain Android, atau menghubungi Supabase.

Widget dan alur layar Flutter sudah memiliki test pada
`apps/mobile/integration_test/m5_public_navigation_test.dart`. Espresso dipakai
di sini untuk memeriksa handoff intent Android dan tampilan Flutter host.

## Skenario Given / When / Then

- **Given** aplikasi uji BDD terpasang dan Android menerima URI reset Perpus.
- **When** Android membuka `MainActivity` dengan URI itu.
- **Then** intent pada activity tetap berisi URI reset yang sama dan `FlutterView`
  terlihat.

Diagram skenario untuk lampiran: [alur BDD Espresso](attachments/bdd-espresso-scenario.svg).
Diagram ini menjelaskan skenario, bukan screenshot hasil runtime.

Paket BDD menggunakan application ID `id.perpus.perpus_mobile.bddtest`, sehingga
instalasi test tidak mengganti aplikasi `id.perpus.perpus_mobile` atau paket M5.

## Implementasi test

File: [source test](../lampiran/espresso/ResetLinkEntryEspressoTest.kt). Di aplikasi Perpus, file ini ditempatkan di `apps/mobile/android/app/src/androidTest/kotlin/id/perpus/perpus_mobile/`.

```kotlin
@RunWith(AndroidJUnit4::class)
class ResetLinkEntryEspressoTest {
    @Test
    fun givenResetLink_whenAndroidResolvesPerpus_thenFlutterHostReceivesLink() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val resetLink = Uri.parse("https://perpus.smkalmunawwarah.sch.id/reset")
        val intent = Intent(Intent.ACTION_VIEW, resetLink)
            .setPackage(context.packageName)
        assertEquals(
            MainActivity::class.java.name,
            intent.resolveActivity(context.packageManager)?.className,
        )

        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                assertEquals(resetLink, activity.intent.data)
            }
            onView(isAssignableFrom(FlutterView::class.java))
                .check(matches(isDisplayed()))
        }
    }
}
```

`ActivityScenario` membuka activity dalam lifecycle Android yang dikelola test.
Assertion pertama memastikan URI diterima host. Assertion Espresso memastikan
view Flutter tampil. URI memakai alamat halaman tetap dan tidak memuat OTP,
token, email, atau kata sandi.

| Bagian kode | Fungsi |
| --- | --- |
| `@RunWith(AndroidJUnit4::class)` | Menjalankan kelas dengan runner AndroidX Test. |
| `@Test` | Mendaftarkan method sebagai satu kasus test. |
| `Uri.parse(...)` | Membentuk tautan reset tetap untuk fixture. |
| `Intent.ACTION_VIEW` | Meniru intent pembuka tautan yang dikirim Android. |
| `setPackage(context.packageName)` | Menguji filter implicit Android dalam paket uji, tanpa membuka chooser aplikasi lain. |
| `resolveActivity(...)` | Memastikan filter URI/path paket uji benar-benar mencocokkan tautan. Ini belum menguji verifikasi domain otomatis Android. |
| `ActivityScenario.launch(...)` | Membuka dan mengelola lifecycle `MainActivity`. |
| `assertEquals(...)` | Memastikan host menerima URI yang diharapkan. |
| `onView(...).check(matches(isDisplayed()))` | Memastikan `FlutterView` terlihat memakai Espresso. |

## Menjalankan di Android

Gunakan perangkat uji khusus atau pastikan paket BDD belum ada. Perintah harus
menyertakan endpoint lokal yang tidak mengarah ke server sekolah. `:1` sengaja
menolak koneksi dan key di bawah hanya nilai sintetis untuk test. Jangan jalankan
perintah ini tanpa argumen dart-define tersebut.

```powershell
Set-Location D:\apps\Perpus\apps\mobile\android
$url = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('SUPABASE_URL=http://127.0.0.1:1'))
$key = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('SUPABASE_PUBLISHABLE_KEY=sb_publishable_local_bdd_test'))
& .\gradlew.bat :app:compileDebugAndroidTestKotlin -PperpusBddTest=true "-Pdart-defines=$url,$key"
```

Untuk menjalankan assertion pada perangkat yang sudah tersambung, jalankan:

```powershell
& .\gradlew.bat :app:connectedDebugAndroidTest -PperpusBddTest=true -Pdart-defines="$url,$key"
```

Setelah command, hasil lulus harus menunjukkan `ResetLinkEntryEspressoTest` dan
exit code `0`. Kegagalan koneksi ke `127.0.0.1:1` dari banner koneksi bukan
kegagalan Espresso; test hanya lulus bila assertion URI dan Flutter host lulus.
Jangan memakai konfigurasi default aplikasi yang menunjuk ke server sekolah.

## Hasil pada sesi ini

- Kompilasi source instrumentation Espresso **PASS**, exit code `0`:
  `:app:compileDebugAndroidTestKotlin -PperpusBddTest=true` dengan dua
  dart-define lokal yang dicantumkan di bawah. Ini hanya membuktikan kode test
  dapat dikompilasi, bukan bahwa assertion sudah berjalan di Android.
- Metadata manifest hasil konfigurasi mengonfirmasi application ID uji
  `id.perpus.perpus_mobile.bddtest` dan label `Perpus BDD Uji`.
- Runtime Espresso **BLOCKED**: `adb devices -l` tidak menampilkan perangkat
  dan `emulator -list-avds` tidak menemukan AVD.
- Test Flutter yang ada tidak bisa dijalankan pada Windows karena repo tidak
  memiliki Windows desktop project. Itu bukan hasil test Android.
- Belum ada bukti runtime Espresso PASS dan belum ada screenshot perangkat.

## Bukti untuk lampiran tugas

Gunakan screenshot terminal setelah menjalankan perintah di perangkat Android
uji. Screenshot harus memperlihatkan nama test dan ringkasan `1 passed`, tanpa
menampilkan OTP, password, token, atau akun nyata. Screenshot source code dapat
menjadi lampiran penjelasan, tetapi bukan bukti test runtime.
