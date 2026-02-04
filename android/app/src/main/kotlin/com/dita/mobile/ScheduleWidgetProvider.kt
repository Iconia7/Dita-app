package com.dita.mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.dita.mobile.R
import java.io.File

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        android.util.Log.d("ScheduleWidgetProvider", "onUpdate called for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            try {
                android.util.Log.d("DITA_WIDGET", "Updating widget ID: $appWidgetId")
                
                // Retrieve the path to the rendered image
                val imagePath = widgetData.getString("widget_image", null)
                
                val views = RemoteViews(context.packageName, R.layout.schedule_widget)
                
                if (imagePath != null) {
                    android.util.Log.d("DITA_WIDGET", "Loading image from path: $imagePath")
                    val imageFile = File(imagePath)
                    if (imageFile.exists()) {
                        val myBitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                        views.setImageViewBitmap(R.id.widget_image, myBitmap)
                        android.util.Log.d("DITA_WIDGET", "Image set successfully")
                    } else {
                        android.util.Log.e("DITA_WIDGET", "Image file does not exist at path: $imagePath")
                    }
                } else {
                    android.util.Log.w("DITA_WIDGET", "No image path found in widgetData")
                }

                android.util.Log.d("DITA_WIDGET", "Committing update to AppWidgetManager")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                android.util.Log.d("DITA_WIDGET", "Update successful for ID: $appWidgetId")

            } catch (e: Exception) {
                android.util.Log.e("DITA_WIDGET", "FATAL CRASH updating ID $appWidgetId: ${e.message}", e)
            }
        }
    }
}
