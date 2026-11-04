package id.perpus.perpus_mobile

import android.content.Intent
import android.net.Uri
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isAssignableFrom
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import io.flutter.embedding.android.FlutterView
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ResetLinkEntryEspressoTest {
    @Test
    fun givenResetLink_whenAndroidOpensPerpus_thenFlutterHostReceivesLink() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val resetLink = Uri.parse("https://perpus.smkalmunawwarah.sch.id/reset")
        val intent = Intent(Intent.ACTION_VIEW, resetLink)
            .setClass(context, MainActivity::class.java)

        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                assertEquals(resetLink, activity.intent.data)
            }
            onView(isAssignableFrom(FlutterView::class.java))
                .check(matches(isDisplayed()))
        }
    }
}
