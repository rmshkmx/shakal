package com.shakal.app

import android.content.Context
import android.graphics.Bitmap
import androidx.exifinterface.media.ExifInterface
import android.graphics.Matrix
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object MemeProcessor {

    suspend fun loadBitmap(context: Context, uri: Uri): Bitmap? = withContext(Dispatchers.IO) {
        try {
            var inputStream = context.contentResolver.openInputStream(uri) ?: return@withContext null
            var bitmap = BitmapFactory.decodeStream(inputStream)
            inputStream.close()

            if (bitmap != null) {
                val stream = context.contentResolver.openInputStream(uri)
                if (stream != null) {
                    val exif = ExifInterface(stream)
                    val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                    stream.close()

                    val matrix = Matrix()
                    when (orientation) {
                        ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                        ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                        ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
                        ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                            matrix.postRotate(180f)
                            matrix.preScale(-1f, 1f)
                        }
                    }
                    if (orientation != ExifInterface.ORIENTATION_NORMAL && orientation != ExifInterface.ORIENTATION_UNDEFINED) {
                        bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                    }
                }
            }

            bitmap
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    suspend fun renderMeme(
        context: Context,
        uri: Uri,
        topText: String,
        bottomText: String,
        topTextSizeSp: Float,
        bottomTextSizeSp: Float
    ): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val original = loadBitmap(context, uri) ?: return@withContext null
            val bitmap = original.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = Canvas(bitmap)

            if (topText.isNotBlank()) {
                drawMemeText(canvas, topText.uppercase(), topTextSizeSp, isTop = true)
            }
            if (bottomText.isNotBlank()) {
                drawMemeText(canvas, bottomText.uppercase(), bottomTextSizeSp, isTop = false)
            }

            bitmap
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun drawMemeText(canvas: Canvas, text: String, textSizeSp: Float, isTop: Boolean) {
        // Scale text size proportional to image height
        val textSizePx = canvas.height * (textSizeSp / 600f)

        val fillPaint = TextPaint().apply {
            color = Color.WHITE
            textSize = textSizePx
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
            isAntiAlias = true
        }

        val strokePaint = TextPaint(fillPaint).apply {
            style = Paint.Style.STROKE
            strokeWidth = textSizePx * 0.08f
            color = Color.BLACK
            strokeJoin = Paint.Join.ROUND
            strokeCap = Paint.Cap.ROUND
        }

        val width = canvas.width
        val padding = (width * 0.05f).toInt()
        val availableWidth = width - padding * 2

        val strokeLayout = StaticLayout.Builder
            .obtain(text, 0, text.length, strokePaint, availableWidth)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .build()
        val fillLayout = StaticLayout.Builder
            .obtain(text, 0, text.length, fillPaint, availableWidth)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .build()

        val textHeight = fillLayout.height
        val y = if (isTop) {
            padding.toFloat()
        } else {
            canvas.height - textHeight - padding.toFloat()
        }

        canvas.save()
        canvas.translate(padding.toFloat(), y)
        strokeLayout.draw(canvas)
        fillLayout.draw(canvas)
        canvas.restore()
    }
}
