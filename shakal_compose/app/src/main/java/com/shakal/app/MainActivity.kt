package com.shakal.app

import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.LightMode
import androidx.compose.material.icons.rounded.SaveAlt
import androidx.compose.material.icons.rounded.TextFields
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asComposePath
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.graphics.shapes.CornerRounding
import androidx.graphics.shapes.Morph
import androidx.graphics.shapes.RoundedPolygon
import androidx.graphics.shapes.circle
import androidx.graphics.shapes.star
import androidx.graphics.shapes.toPath
import com.shakal.app.ui.theme.ShakalTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.sqrt
import kotlin.random.Random

// ─── M3 Expressive shapes ───

fun createM3Shape(index: Int): Shape {
    val polygon = when (index % 8) {
        0 -> RoundedPolygon.star(
            numVerticesPerRadius = 9,
            innerRadius = 0.88f,
            rounding = CornerRounding(radius = 0.12f)
        )
        1 -> RoundedPolygon.star(
            numVerticesPerRadius = 7,
            innerRadius = 0.85f,
            rounding = CornerRounding(radius = 0.15f)
        )
        2 -> RoundedPolygon.star(
            numVerticesPerRadius = 12,
            innerRadius = 0.92f,
            rounding = CornerRounding(radius = 0.08f)
        )
        3 -> RoundedPolygon(
            numVertices = 6,
            rounding = CornerRounding(radius = 0.3f, smoothing = 0.5f)
        )
        4 -> RoundedPolygon(
            numVertices = 5,
            rounding = CornerRounding(radius = 0.35f, smoothing = 0.5f)
        )
        5 -> RoundedPolygon.star(
            numVerticesPerRadius = 8,
            innerRadius = 0.86f,
            rounding = CornerRounding(radius = 0.14f)
        )
        6 -> RoundedPolygon.star(
            numVerticesPerRadius = 4,
            innerRadius = 0.72f,
            rounding = CornerRounding(radius = 0.28f)
        )
        else -> RoundedPolygon.star(
            numVerticesPerRadius = 6,
            innerRadius = 0.80f,
            rounding = CornerRounding(radius = 0.2f)
        )
    }

    return object : Shape {
        override fun createOutline(
            size: Size,
            layoutDirection: LayoutDirection,
            density: Density
        ): Outline {
            val matrix = android.graphics.Matrix()
            matrix.setScale(size.width / 2f, size.height / 2f)
            matrix.postTranslate(size.width / 2f, size.height / 2f)
            val path = polygon.toPath()
            path.transform(matrix)
            return Outline.Generic(path.asComposePath())
        }
    }
}

// ─── Haptic feedback helper ───

fun performHapticTick(context: android.content.Context) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val vm = context.getSystemService(android.content.Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
        vm?.defaultVibrator?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        @Suppress("DEPRECATION")
        val v = context.getSystemService(android.content.Context.VIBRATOR_SERVICE) as? Vibrator
        v?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
    }
}

// ─── Circular reveal shape ───

class CircularRevealShape(
    private val center: Offset,
    private val radius: Float
) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        return Outline.Generic(Path().apply {
            addOval(Rect(center = center, radius = radius))
        })
    }
}

// ─── Activity ───

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var isDarkTheme by remember { mutableStateOf(true) }
            var themeClickOffset by remember { mutableStateOf(Offset.Zero) }
            val revealProgress = remember { Animatable(0f) }
            var isRevealing by remember { mutableStateOf(false) }
            var revealToDark by remember { mutableStateOf(false) }
            val coroutineScope = rememberCoroutineScope()
            var currentPage by remember { mutableIntStateOf(0) }

            Box(modifier = Modifier.fillMaxSize()) {
                // Base layer
                ShakalTheme(darkTheme = isDarkTheme) {
                    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.surface) {
                        ShakalApp(
                            isDarkTheme = isDarkTheme,
                            onThemeToggle = { offset ->
                                if (!isRevealing) {
                                    themeClickOffset = offset
                                    revealToDark = !isDarkTheme
                                    coroutineScope.launch {
                                        isRevealing = true
                                        revealProgress.snapTo(0f)
                                        revealProgress.animateTo(
                                            targetValue = 1f,
                                            animationSpec = tween(700, easing = FastOutSlowInEasing)
                                        )
                                        isDarkTheme = revealToDark
                                        isRevealing = false
                                    }
                                }
                            },
                            initialPage = currentPage,
                            onPageChanged = { currentPage = it }
                        )
                    }
                }

                // Reveal overlay
                if (isRevealing) {
                    ShakalTheme(darkTheme = revealToDark) {
                        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                            val screenW = with(LocalDensity.current) { maxWidth.toPx() }
                            val screenH = with(LocalDensity.current) { maxHeight.toPx() }
                            val dx = max(themeClickOffset.x, screenW - themeClickOffset.x)
                            val dy = max(themeClickOffset.y, screenH - themeClickOffset.y)
                            val maxRadius = sqrt(dx * dx + dy * dy)
                            val currentRadius = maxRadius * revealProgress.value

                            Surface(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(CircularRevealShape(themeClickOffset, currentRadius)),
                                color = MaterialTheme.colorScheme.surface
                            ) {
                                ShakalApp(
                                    isDarkTheme = revealToDark,
                                    onThemeToggle = {},
                                    initialPage = currentPage,
                                    onPageChanged = {}
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─── Main app container ───

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShakalApp(
    isDarkTheme: Boolean,
    onThemeToggle: (Offset) -> Unit,
    initialPage: Int = 0,
    onPageChanged: (Int) -> Unit = {}
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val pagerState = rememberPagerState(initialPage = initialPage, pageCount = { 2 })

    // Sync page changes upward
    LaunchedEffect(pagerState.currentPage) {
        onPageChanged(pagerState.currentPage)
    }

    // ── Shakal page state ──
    var shakalImageUri by remember { mutableStateOf<Uri?>(null) }
    var processedBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var quality by remember { mutableFloatStateOf(50f) }
    var downscaleFactor by remember { mutableFloatStateOf(5.2f) }
    var isProcessing by remember { mutableStateOf(false) }
    var shakalHasProcessedOnce by remember { mutableStateOf(false) }
    var prevQualityStep by remember { mutableIntStateOf(50) }
    var prevDownscaleStep by remember { mutableIntStateOf(5) }

    // ── Meme page state ──
    var memeImageUri by remember { mutableStateOf<Uri?>(null) }
    var memeBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var topText by remember { mutableStateOf("") }
    var bottomText by remember { mutableStateOf("") }
    var topTextSize by remember { mutableFloatStateOf(32f) }
    var bottomTextSize by remember { mutableFloatStateOf(32f) }

    // ── Shared state ──
    var isSaving by remember { mutableStateOf(false) }
    var showFullScreenPreview by remember { mutableStateOf(false) }
    var previewBitmap by remember { mutableStateOf<Bitmap?>(null) }

    // Cascade animation
    var isVisible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { isVisible = true }

    // ── Photo pickers ──
    val shakalPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
        onResult = { uri ->
            if (uri != null) {
                shakalImageUri = uri
                processedBitmap = null
                shakalHasProcessedOnce = false
            }
        }
    )

    val memePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
        onResult = { uri ->
            if (uri != null) {
                memeImageUri = uri
                coroutineScope.launch {
                    memeBitmap = MemeProcessor.loadBitmap(context, uri)
                }
            }
        }
    )

    fun pickShakalPhoto() {
        shakalPickerLauncher.launch(
            androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
        )
    }

    fun pickMemePhoto() {
        memePickerLauncher.launch(
            androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
        )
    }

    fun triggerShakalProcessing() {
        shakalImageUri?.let { uri ->
            coroutineScope.launch {
                isProcessing = true
                processedBitmap = ImageProcessor.processImage(context, uri, downscaleFactor, quality.toInt())
                isProcessing = false
                shakalHasProcessedOnce = true
            }
        }
    }

    // ── Save logic ──
    val showSaveButton = when (pagerState.currentPage) {
        0 -> shakalHasProcessedOnce && processedBitmap != null
        1 -> memeImageUri != null && (topText.isNotBlank() || bottomText.isNotBlank())
        else -> false
    }

    fun onSave() {
        when (pagerState.currentPage) {
            0 -> {
                processedBitmap?.let { bmp ->
                    coroutineScope.launch {
                        isSaving = true
                        delay(600)
                        val success = ImageProcessor.saveImageToGallery(context, bmp)
                        isSaving = false
                        Toast.makeText(context, if (success) "Сохранено!" else "Ошибка", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            1 -> {
                memeImageUri?.let { uri ->
                    coroutineScope.launch {
                        isSaving = true
                        delay(600)
                        val result = MemeProcessor.renderMeme(context, uri, topText, bottomText, topTextSize, bottomTextSize)
                        if (result != null) {
                            val success = ImageProcessor.saveImageToGallery(context, result)
                            Toast.makeText(context, if (success) "Сохранено!" else "Ошибка", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(context, "Ошибка", Toast.LENGTH_SHORT).show()
                        }
                        isSaving = false
                    }
                }
            }
        }
    }

    // ── UI ──
    Box(modifier = Modifier.fillMaxSize()) {
        Scaffold(
            bottomBar = {
                // Bottom navigation + save FAB
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    // M3E Segmented navigation bar
                    SingleChoiceSegmentedButtonRow(
                        modifier = Modifier.align(Alignment.Center)
                    ) {
                        SegmentedButton(
                            selected = pagerState.currentPage == 0,
                            onClick = {
                                performHapticTick(context)
                                coroutineScope.launch { pagerState.animateScrollToPage(0) }
                            },
                            shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                            icon = {
                                Icon(
                                    Icons.Rounded.AutoFixHigh,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        ) {
                            Text("Шакал")
                        }
                        SegmentedButton(
                            selected = pagerState.currentPage == 1,
                            onClick = {
                                performHapticTick(context)
                                coroutineScope.launch { pagerState.animateScrollToPage(1) }
                            },
                            shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                            icon = {
                                Icon(
                                    Icons.Rounded.TextFields,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        ) {
                            Text("Текст")
                        }
                    }

                    // Save FAB (right side)
                    AnimatedVisibility(
                        visible = showSaveButton,
                        modifier = Modifier.align(Alignment.CenterEnd),
                        enter = scaleIn(spring(dampingRatio = 0.6f)) + fadeIn(),
                        exit = scaleOut() + fadeOut()
                    ) {
                        MorphingSaveButton(
                            isSaving = isSaving,
                            onClick = { onSave() }
                        )
                    }
                }
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                // Header
                AnimatedVisibility(
                    visible = isVisible,
                    enter = slideInVertically(
                        initialOffsetY = { it / 2 },
                        animationSpec = tween(600, easing = FastOutSlowInEasing)
                    ) + fadeIn(tween(600))
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 22.dp)
                            .padding(top = 18.dp)
                    ) {
                        Text(
                            text = "ШКЛ",
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.weight(1f))

                        var buttonCenter by remember { mutableStateOf(Offset.Zero) }
                        IconButton(
                            onClick = { onThemeToggle(buttonCenter) },
                            modifier = Modifier.onGloballyPositioned { coords ->
                                val pos = coords.localToRoot(Offset.Zero)
                                buttonCenter = Offset(
                                    pos.x + coords.size.width / 2f,
                                    pos.y + coords.size.height / 2f
                                )
                            }
                        ) {
                            Icon(
                                imageVector = if (isDarkTheme) Icons.Rounded.LightMode else Icons.Rounded.DarkMode,
                                contentDescription = "Переключить тему",
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }

                // Page content (swipeable)
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                    beyondViewportPageCount = 1
                ) { page ->
                    when (page) {
                        0 -> ShakalPageContent(
                            imageUri = shakalImageUri,
                            processedBitmap = processedBitmap,
                            quality = quality,
                            downscaleFactor = downscaleFactor,
                            isVisible = isVisible,
                            onPickPhoto = ::pickShakalPhoto,
                            onPreview = {
                                processedBitmap?.let {
                                    previewBitmap = it
                                    showFullScreenPreview = true
                                }
                            },
                            onQualityChange = { newVal ->
                                quality = newVal
                                val step = newVal.toInt()
                                if (step != prevQualityStep) {
                                    prevQualityStep = step
                                    performHapticTick(context)
                                }
                            },
                            onQualityChangeFinished = ::triggerShakalProcessing,
                            onDownscaleChange = { newVal ->
                                downscaleFactor = newVal
                                val step = newVal.toInt()
                                if (step != prevDownscaleStep) {
                                    prevDownscaleStep = step
                                    performHapticTick(context)
                                }
                            },
                            onDownscaleChangeFinished = ::triggerShakalProcessing
                        )
                        1 -> MemePageContent(
                            imageUri = memeImageUri,
                            originalBitmap = memeBitmap,
                            topText = topText,
                            bottomText = bottomText,
                            topTextSize = topTextSize,
                            bottomTextSize = bottomTextSize,
                            isVisible = isVisible,
                            onPickPhoto = ::pickMemePhoto,
                            onPreview = {
                                memeBitmap?.let {
                                    previewBitmap = it
                                    showFullScreenPreview = true
                                }
                            },
                            onTopTextChange = { topText = it },
                            onBottomTextChange = { bottomText = it },
                            onTopTextSizeChange = { topTextSize = it },
                            onBottomTextSizeChange = { bottomTextSize = it }
                        )
                    }
                }
            }
        }

        // Full-screen preview overlay
        if (showFullScreenPreview && previewBitmap != null) {
            FullScreenPreview(
                bitmap = previewBitmap!!,
                topText = if (pagerState.currentPage == 1) topText else "",
                bottomText = if (pagerState.currentPage == 1) bottomText else "",
                topTextSize = topTextSize,
                bottomTextSize = bottomTextSize,
                onDismiss = { showFullScreenPreview = false }
            )
        }
    }
}

// ─── Shakal page (quality degradation) ───

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShakalPageContent(
    imageUri: Uri?,
    processedBitmap: Bitmap?,
    quality: Float,
    downscaleFactor: Float,
    isVisible: Boolean,
    onPickPhoto: () -> Unit,
    onPreview: () -> Unit,
    onQualityChange: (Float) -> Unit,
    onQualityChangeFinished: () -> Unit,
    onDownscaleChange: (Float) -> Unit,
    onDownscaleChangeFinished: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 22.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Spacer(modifier = Modifier.height(24.dp))

        // Central morphing button
        AnimatedVisibility(
            visible = isVisible,
            enter = scaleIn(
                initialScale = 0.8f,
                animationSpec = tween(600, delayMillis = 100, easing = FastOutSlowInEasing)
            ) + fadeIn(tween(600, delayMillis = 100))
        ) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                MorphingImageButton(
                    imageUri = imageUri,
                    displayBitmap = processedBitmap,
                    onPickPhoto = onPickPhoto,
                    onPreview = onPreview
                )
            }
        }

        Spacer(modifier = Modifier.height(26.dp))

        // Quality slider
        AnimatedVisibility(
            visible = isVisible,
            enter = slideInVertically(
                initialOffsetY = { it / 2 },
                animationSpec = tween(600, delayMillis = 200, easing = FastOutSlowInEasing)
            ) + fadeIn(tween(600, delayMillis = 200))
        ) {
            ControlCard(
                title = "Степень сжатия",
                badgeText = "${quality.toInt()}%",
                badgeColor = MaterialTheme.colorScheme.secondaryContainer,
                badgeTextColor = MaterialTheme.colorScheme.onSecondaryContainer
            ) {
                M3ESlider(
                    value = quality,
                    onValueChange = onQualityChange,
                    onValueChangeFinished = onQualityChangeFinished,
                    valueRange = 1f..100f,
                    activeColor = MaterialTheme.colorScheme.primary,
                    inactiveColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    thumbColor = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        "Минимум",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "Максимум",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(18.dp))

        // Artifact slider
        val artifactLabel = when {
            downscaleFactor < 2.4f -> "Низкая"
            downscaleFactor < 4.4f -> "Средняя"
            downscaleFactor < 6.4f -> "Высокая"
            else -> "Жёсткая"
        }

        AnimatedVisibility(
            visible = isVisible,
            enter = slideInVertically(
                initialOffsetY = { it / 2 },
                animationSpec = tween(600, delayMillis = 300, easing = FastOutSlowInEasing)
            ) + fadeIn(tween(600, delayMillis = 300))
        ) {
            ControlCard(
                title = "Интенсивность\nартефактов",
                badgeText = artifactLabel,
                badgeColor = MaterialTheme.colorScheme.secondaryContainer,
                badgeTextColor = MaterialTheme.colorScheme.onSecondaryContainer
            ) {
                M3ESlider(
                    value = downscaleFactor,
                    onValueChange = onDownscaleChange,
                    onValueChangeFinished = onDownscaleChangeFinished,
                    valueRange = 1f..8f,
                    activeColor = MaterialTheme.colorScheme.secondary,
                    inactiveColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    thumbColor = MaterialTheme.colorScheme.secondary
                )
            }
        }

        Spacer(modifier = Modifier.height(100.dp))
    }
}

// ─── Meme page (text overlay) ───

@Composable
fun MemePageContent(
    imageUri: Uri?,
    originalBitmap: Bitmap?,
    topText: String,
    bottomText: String,
    topTextSize: Float,
    bottomTextSize: Float,
    isVisible: Boolean,
    onPickPhoto: () -> Unit,
    onPreview: () -> Unit,
    onTopTextChange: (String) -> Unit,
    onBottomTextChange: (String) -> Unit,
    onTopTextSizeChange: (Float) -> Unit,
    onBottomTextSizeChange: (Float) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 22.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Spacer(modifier = Modifier.height(24.dp))

        // Photo with meme text overlay
        AnimatedVisibility(
            visible = isVisible,
            enter = scaleIn(
                initialScale = 0.8f,
                animationSpec = tween(600, delayMillis = 100, easing = FastOutSlowInEasing)
            ) + fadeIn(tween(600, delayMillis = 100))
        ) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                MorphingImageButton(
                    imageUri = imageUri,
                    displayBitmap = originalBitmap,
                    onPickPhoto = onPickPhoto,
                    onPreview = onPreview,
                    overlayContent = if (originalBitmap != null) {
                        {
                            if (topText.isNotBlank()) {
                                MemeTextOverlay(
                                    text = topText.uppercase(),
                                    fontSize = topTextSize,
                                    modifier = Modifier
                                        .align(Alignment.TopCenter)
                                        .padding(top = 16.dp, start = 8.dp, end = 8.dp)
                                )
                            }
                            if (bottomText.isNotBlank()) {
                                MemeTextOverlay(
                                    text = bottomText.uppercase(),
                                    fontSize = bottomTextSize,
                                    modifier = Modifier
                                        .align(Alignment.BottomCenter)
                                        .padding(bottom = 16.dp, start = 8.dp, end = 8.dp)
                                )
                            }
                        }
                    } else null
                )
            }
        }

        Spacer(modifier = Modifier.height(26.dp))

        // Top text input card
        AnimatedVisibility(
            visible = isVisible,
            enter = slideInVertically(
                initialOffsetY = { it / 2 },
                animationSpec = tween(600, delayMillis = 200, easing = FastOutSlowInEasing)
            ) + fadeIn(tween(600, delayMillis = 200))
        ) {
            TextInputCard(
                title = "Верхний текст",
                text = topText,
                onTextChange = onTopTextChange,
                textSize = topTextSize,
                onDecrease = { onTopTextSizeChange((topTextSize - 4f).coerceAtLeast(16f)) },
                onIncrease = { onTopTextSizeChange((topTextSize + 4f).coerceAtMost(64f)) }
            )
        }

        Spacer(modifier = Modifier.height(18.dp))

        // Bottom text input card
        AnimatedVisibility(
            visible = isVisible,
            enter = slideInVertically(
                initialOffsetY = { it / 2 },
                animationSpec = tween(600, delayMillis = 300, easing = FastOutSlowInEasing)
            ) + fadeIn(tween(600, delayMillis = 300))
        ) {
            TextInputCard(
                title = "Нижний текст",
                text = bottomText,
                onTextChange = onBottomTextChange,
                textSize = bottomTextSize,
                onDecrease = { onBottomTextSizeChange((bottomTextSize - 4f).coerceAtLeast(16f)) },
                onIncrease = { onBottomTextSizeChange((bottomTextSize + 4f).coerceAtMost(64f)) }
            )
        }

        Spacer(modifier = Modifier.height(100.dp))
    }
}

// ─── Text input card for meme page ───

@Composable
fun TextInputCard(
    title: String,
    text: String,
    onTextChange: (String) -> Unit,
    textSize: Float,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit
) {
    val context = LocalContext.current

    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        shape = RoundedCornerShape(22.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(
                value = text,
                onValueChange = onTextChange,
                placeholder = { Text("Текст...") },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                singleLine = true
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Decrease text size
                IconButton(onClick = {
                    performHapticTick(context)
                    onDecrease()
                }) {
                    Text(
                        "тТ",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // Size indicator
                Text(
                    "${textSize.toInt()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // Increase text size
                IconButton(onClick = {
                    performHapticTick(context)
                    onIncrease()
                }) {
                    Text(
                        "ТТ",
                        fontWeight = FontWeight.Black,
                        fontSize = 20.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

// ─── Meme text overlay (white fill + black stroke) ───

@Composable
fun MemeTextOverlay(text: String, fontSize: Float, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    val strokeWidthPx = with(density) { (fontSize * 0.1f).sp.toPx() }

    Box(modifier = modifier) {
        // Black stroke (outline)
        Text(
            text = text,
            style = TextStyle(
                fontSize = fontSize.sp,
                fontWeight = FontWeight.Black,
                color = Color.Black,
                drawStyle = Stroke(width = strokeWidthPx, join = StrokeJoin.Round)
            ),
            textAlign = TextAlign.Center
        )
        // White fill
        Text(
            text = text,
            style = TextStyle(
                fontSize = fontSize.sp,
                fontWeight = FontWeight.Black,
                color = Color.White
            ),
            textAlign = TextAlign.Center
        )
    }
}

// ─── Full-screen image preview overlay ───

@Composable
fun FullScreenPreview(
    bitmap: Bitmap,
    topText: String = "",
    bottomText: String = "",
    topTextSize: Float = 32f,
    bottomTextSize: Float = 32f,
    onDismiss: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.92f))
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onDismiss() }
            .zIndex(100f),
        contentAlignment = Alignment.Center
    ) {
        val aspectRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
                .aspectRatio(aspectRatio)
        ) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Предпросмотр",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit
            )
            if (topText.isNotBlank()) {
                MemeTextOverlay(
                    text = topText.uppercase(),
                    fontSize = topTextSize * 1.2f,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 16.dp, start = 12.dp, end = 12.dp)
                )
            }
            if (bottomText.isNotBlank()) {
                MemeTextOverlay(
                    text = bottomText.uppercase(),
                    fontSize = bottomTextSize * 1.2f,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 16.dp, start = 12.dp, end = 12.dp)
                )
            }
        }
    }
}

// ─── Native M3E Slider ───

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun M3ESlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    onValueChangeFinished: () -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    activeColor: Color,
    inactiveColor: Color,
    thumbColor: Color
) {
    val interactionSource = remember { MutableInteractionSource() }

    Slider(
        value = value,
        onValueChange = onValueChange,
        onValueChangeFinished = onValueChangeFinished,
        valueRange = valueRange,
        interactionSource = interactionSource,
        thumb = {
            SliderDefaults.Thumb(
                interactionSource = interactionSource,
                colors = SliderDefaults.colors(thumbColor = thumbColor),
                thumbSize = androidx.compose.ui.unit.DpSize(4.dp, 44.dp)
            )
        },
        track = { sliderState ->
            SliderDefaults.Track(
                sliderState = sliderState,
                colors = SliderDefaults.colors(
                    activeTrackColor = activeColor,
                    inactiveTrackColor = inactiveColor
                ),
                thumbTrackGapSize = 8.dp,
                trackInsideCornerSize = 4.dp,
                drawStopIndicator = null
            )
        },
        modifier = Modifier.padding(vertical = 4.dp)
    )
}

// ─── Central morphing button ───

@Composable
fun MorphingImageButton(
    imageUri: Uri?,
    displayBitmap: Bitmap?,
    onPickPhoto: () -> Unit,
    onPreview: () -> Unit = {},
    overlayContent: @Composable (BoxScope.() -> Unit)? = null
) {
    val context = LocalContext.current

    // Slow rotation for empty state only
    val infiniteTransition = rememberInfiniteTransition(label = "rotate")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(30000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    // Press physics
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.93f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "scale"
    )

    // Random M3E shape
    val shapeIndex = remember { Random.nextInt(0, 8) }
    val m3Shape = remember { createM3Shape(shapeIndex) }
    val squircleShape = RoundedCornerShape(28.dp)
    val hasImage = imageUri != null
    val hasBitmap = displayBitmap != null

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .scale(scale)
            .then(if (!hasImage) Modifier.rotate(rotation) else Modifier)
            .clip(if (hasImage) squircleShape else m3Shape)
            .background(MaterialTheme.colorScheme.primaryContainer)
            .pointerInput(hasImage, hasBitmap) {
                detectTapGestures(
                    onPress = {
                        isPressed = true
                        tryAwaitRelease()
                        isPressed = false
                    },
                    onTap = {
                        if (hasBitmap) onPreview() else onPickPhoto()
                    },
                    onLongPress = {
                        if (hasBitmap) {
                            performHapticTick(context)
                            onPickPhoto()
                        }
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        if (displayBitmap != null) {
            Image(
                bitmap = displayBitmap.asImageBitmap(),
                contentDescription = "Фото",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
            overlayContent?.invoke(this)
        } else if (imageUri != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(48.dp),
                    color = MaterialTheme.colorScheme.primary
                )
            }
        } else {
            // Counter-rotate the text so it stays readable
            Text(
                text = "ВЫБРАТЬ\nФОТО",
                style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Black,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
                textAlign = TextAlign.Center,
                modifier = Modifier.rotate(-rotation)
            )
        }
    }
}

// ─── Morphing save button (icon only) ───

@Composable
fun MorphingSaveButton(
    isSaving: Boolean,
    onClick: () -> Unit
) {
    val pillPolygon = remember { RoundedPolygon.circle() }
    val cookiePolygon = remember {
        RoundedPolygon.star(
            numVerticesPerRadius = 9,
            innerRadius = 0.8f,
            rounding = CornerRounding(radius = 0.2f)
        )
    }
    val morph = remember { Morph(pillPolygon, cookiePolygon) }

    val morphProgress by animateFloatAsState(
        targetValue = if (isSaving) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = 200f),
        label = "morph"
    )

    val morphShape = remember(morphProgress) {
        object : Shape {
            override fun createOutline(
                size: Size,
                layoutDirection: LayoutDirection,
                density: Density
            ): Outline {
                val matrix = android.graphics.Matrix()
                matrix.setScale(size.width / 2f, size.height / 2f)
                matrix.postTranslate(size.width / 2f, size.height / 2f)
                val path = morph.toPath(morphProgress).apply { transform(matrix) }
                return Outline.Generic(path.asComposePath())
            }
        }
    }

    Box(
        modifier = Modifier
            .size(72.dp)
            .clip(morphShape)
            .background(MaterialTheme.colorScheme.primary)
            .clickable(enabled = !isSaving) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            Icons.Rounded.SaveAlt,
            "Сохранить",
            tint = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier.size(28.dp)
        )
    }
}

// ─── Control card ───

@Composable
fun ControlCard(
    title: String,
    badgeText: String,
    badgeColor: Color,
    badgeTextColor: Color,
    content: @Composable () -> Unit
) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        ),
        shape = RoundedCornerShape(22.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.weight(1f))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(badgeColor)
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        badgeText,
                        style = MaterialTheme.typography.labelLarge,
                        color = badgeTextColor,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            content()
        }
    }
}
