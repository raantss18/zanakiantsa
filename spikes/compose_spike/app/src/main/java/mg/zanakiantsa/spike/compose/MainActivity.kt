// Spike Kotlin + Jetpack Compose : « Compte les pommes » (voir ../../README.md).
package mg.zanakiantsa.spike.compose

import android.media.MediaPlayer
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale
import kotlin.math.hypot
import kotlin.math.sin

// Positions normalisées communes aux trois spikes, et suite des N.
val positions = listOf(
    0.20f to 0.20f, 0.50f to 0.15f, 0.80f to 0.22f, 0.30f to 0.42f,
    0.70f to 0.40f, 0.15f to 0.60f, 0.55f to 0.62f,
)
val rounds = listOf(5, 3, 7, 4, 6)

val Red = Color(0xFFD6362B)
val Green = Color(0xFF1D7A33)
val Bg = Color(0xFFF7F8F6)

class MainActivity : ComponentActivity() {
    private lateinit var tts: TextToSpeech

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts.language = Locale.FRANCE
                say("Touche chaque pomme pour la compter.")
            }
        }
        setContent { Spike(::say) { MediaPlayer.create(this, R.raw.ding).apply { setOnCompletionListener { it.release() } }.start() } }
    }

    private fun say(text: String) {
        tts.speak(text, TextToSpeech.QUEUE_ADD, null, text)
    }

    override fun onDestroy() {
        tts.shutdown()
        super.onDestroy()
    }
}

@Composable
fun Spike(say: (String) -> Unit, ding: () -> Unit) {
    var round by remember { mutableIntStateOf(0) }
    val n = rounds[round % rounds.size]
    val numbers = remember(round) { mutableStateMapOf<Int, Int>() }
    var time by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(Unit) {
        var first = true
        var start = 0L
        var windowStart = 0L
        var frames = 0
        while (true) {
            withFrameNanos { now ->
                if (first) { Log.i("SPIKE", "SPIKE first_frame"); first = false; start = now; windowStart = now }
                time = (now - start) / 1e9f
                frames++
                if (now - windowStart >= 5_000_000_000L) {
                    Log.i("SPIKE", "SPIKE fps %.1f".format(Locale.US, frames / ((now - windowStart) / 1e9f)))
                    frames = 0; windowStart = now
                }
            }
        }
    }

    val density = LocalDensity.current
    val radius = with(density) { 40.dp.toPx() }
    val bob = with(density) { 8.dp.toPx() }
    val textPaint = remember(density) {
        android.graphics.Paint().apply {
            color = android.graphics.Color.WHITE; textSize = with(density) { 34.sp.toPx() }
            textAlign = android.graphics.Paint.Align.CENTER; isFakeBoldText = true; isAntiAlias = true
        }
    }

    fun centers(size: Size) = (0 until n).map { i ->
        val (rx, ry) = positions[i]
        Offset(rx * size.width, ry / 0.75f * size.height + sin(time * 2 + i) * bob)
    }

    Column(Modifier.fillMaxSize().background(Bg).systemBarsPadding()) {
        Canvas(
            Modifier.weight(1f).fillMaxWidth().pointerInput(round, n) {
                detectTapGestures { p ->
                    val hit = centers(Size(size.width.toFloat(), size.height.toFloat()))
                        .indexOfFirst { hypot(it.x - p.x, it.y - p.y) <= radius }
                    if (hit >= 0 && hit !in numbers) {
                        numbers[hit] = numbers.size + 1
                        say("${numbers.size}")
                        if (numbers.size == n) say("Combien de pommes ?")
                    }
                }
            }
        ) {
            centers(size).forEachIndexed { i, c ->
                drawCircle(Red, radius * 0.85f, c)
                drawOval(Green, Offset(c.x, c.y - radius), Size(radius * 0.6f, radius * 0.35f))
                numbers[i]?.let { num ->
                    drawCircle(Green, radius, c, style = Stroke(with(density) { 6.dp.toPx() }))
                    drawContext.canvas.nativeCanvas.drawText("$num", c.x, c.y - (textPaint.ascent() + textPaint.descent()) / 2, textPaint)
                }
            }
        }
        Row(Modifier.fillMaxWidth().height(140.dp), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
            if (numbers.size == n) {
                for (v in listOf(n - 1, n, n + 1)) {
                    Button(
                        onClick = {
                            if (v != n) say("Compte encore.") else { ding(); say("Oui, il y a $n pommes. Bravo !"); round++ }
                        },
                        modifier = Modifier.size(96.dp),
                        shape = RoundedCornerShape(24.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Green),
                        contentPadding = PaddingValues(0.dp),
                    ) { Text("$v", fontSize = 40.sp, color = Color.White, fontWeight = FontWeight.Bold) }
                }
            }
        }
    }
}
