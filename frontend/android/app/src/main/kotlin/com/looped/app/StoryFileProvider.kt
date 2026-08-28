package com.looped.app

import androidx.core.content.FileProvider

/**
 * FileProvider propio para pasarle el sticker de la story a Instagram.
 *
 * Tiene clase propia a proposito: el merge del manifest agrupa los providers por
 * `android:name`, asi que declarar otro `androidx.core.content.FileProvider` en
 * el manifest de la app le termina pisando la autoridad al de image_picker.
 */
class StoryFileProvider : FileProvider()
