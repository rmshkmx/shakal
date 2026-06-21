package com.shakal.app

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.OutputStream
import kotlin.math.max

object ImageProcessor {

    suspend fun processImage(
        context: Context,
        uri: Uri,
        downscaleFactor: Float,
        quality: Int
    ): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val inputStream = context.contentResolver.openInputStream(uri) ?: return@withContext null
            val originalBitmap = BitmapFactory.decodeStream(inputStream)
            inputStream.close()

            if (originalBitmap == null) return@withContext null

            if (downscaleFactor <= 1.01f) {
                return@withContext originalBitmap
            }

            val targetWidth = max(1, (originalBitmap.width / downscaleFactor).toInt())
            val targetHeight = max(1, (originalBitmap.height / downscaleFactor).toInt())

            // Create scaled down bitmap
            val matrix = Matrix()
            matrix.postScale(targetWidth.toFloat() / originalBitmap.width, targetHeight.toFloat() / originalBitmap.height)
            
            // In Android, createBitmap doesn't let us specify nearest neighbor directly in the simple method,
            // but we can set filter = false which usually means nearest neighbor or bilinear depending on implementation.
            // For blocky artifacts, nearest neighbor is preferred. Setting filter = false.
            val scaledDown = Bitmap.createBitmap(originalBitmap, 0, 0, originalBitmap.width, originalBitmap.height, matrix, downscaleFactor < 4.8f)
            
            // Compress to JPEG to introduce artifacts
            val outputStream = ByteArrayOutputStream()
            scaledDown.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
            val jpegBytes = outputStream.toByteArray()

            // Decode back to Bitmap to show on screen
            BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    suspend fun saveImageToGallery(context: Context, bitmap: Bitmap): Boolean = withContext(Dispatchers.IO) {
        try {
            val filename = "shkl_${System.currentTimeMillis()}.jpg"
            var fos: OutputStream? = null
            var imageUri: Uri? = null

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Zybuchiy Shakal")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }

            val contentResolver = context.contentResolver
            contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)?.also { uri ->
                imageUri = uri
                fos = contentResolver.openOutputStream(uri)
            }

            fos?.use {
                bitmap.compress(Bitmap.CompressFormat.JPEG, 100, it)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                imageUri?.let { uri ->
                    contentResolver.update(uri, contentValues, null, null)
                }
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
