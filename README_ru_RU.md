<div>

[**English**](README.md)

</div>

## MeowClash

> MeowClash - это форк [MeowClash](https://github.com/chen08209/MeowClash)

[![Downloads](https://img.shields.io/github/downloads/Loischsiy/MeowClash/total?style=flat-square&logo=github)](https://github.com/Loischsiy/MeowClash/releases/)[![Last Version](https://img.shields.io/github/release/Loischsiy/MeowClash/all.svg?style=flat-square)](https://github.com/Loischsiy/MeowClash/releases/)[![License](https://img.shields.io/github/license/Loischsiy/MeowClash?style=flat-square)](LICENSE)

Мультиплатформенный прокси-клиент на базе ClashMeta, простой и удобный в использовании, с открытым исходным кодом и без рекламы.

на Десктопе:
<p style="text-align: center;">
    <img alt="desktop" src="snapshots/desktop.gif">
</p>

на Мобильных устройствах:
<p style="text-align: center;">
    <img alt="mobile" src="snapshots/mobile.gif">
</p>

## Особенности

✈️ Мультиплатформенность: Android, Windows, macOS и Linux

💻 Адаптивность под разные размеры экранов, Доступно несколько цветовых тем

💡 Дизайн на основе Material You, UI в стиле [Surfboard](https://github.com/getsurfboard/surfboard)

☁️ Поддержка синхронизации данных через WebDAV

✨ Поддержка ссылок на подписки, Темный режим

## Использование

### Linux

⚠️ Перед использованием убедитесь, что установлены следующие зависимости

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
    sudo apt-get install libkeybinder-3.0-dev
   ```

### Android

Поддерживаются следующие действия (actions)

   ```bash
    com.follow.clash.action.START
    
    com.follow.clash.action.STOP
    
    com.follow.clash.action.TOGGLE
   ```

## Скачать

<a href="https://chen08209.github.io/MeowClash-fdroid-repo/repo?fingerprint=789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD"><img alt="Get it on F-Droid" src="snapshots/get-it-on-fdroid.svg" width="200px"/></a> <a href="https://github.com/Loischsiy/MeowClash/releases"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="200px"/></a>

## Сборка

1. Обновите подмодули
   ```bash
   git submodule update --init --recursive
   ```

2. Установите окружение `Flutter` и `Golang`

3. Соберите приложение

    - android

        1. Установите `Android SDK` , `Android NDK`

        2. Установите переменные окружения `ANDROID_NDK`

        3. Запустите скрипт сборки

           ```bash
           dart .\setup.dart android
           ```

    - windows

        1. Вам понадобится клиент на Windows

        2. Установите `Gcc`，`Inno Setup`

        3. Запустите скрипт сборки

           ```bash
           dart .\setup.dart windows --arch <arm64 | amd64>
           ```

    - linux

        1. Вам понадобится клиент на Linux

        2. Запустите скрипт сборки

           ```bash
           dart .\setup.dart linux --arch <arm64 | amd64>
           ```

    - macOS

        1. Вам понадобится клиент на macOS

        2. Запустите скрипт сборки

           ```bash
           dart .\setup.dart macos --arch <arm64 | amd64>
           ```

## Звезды (Star)

Самый простой способ поддержать разработчиков - поставить звезду (⭐) в верхней части страницы.

<p style="text-align: center;">
    <a href="https://api.star-history.com/svg?repos=Loischsiy/MeowClash&Date">
        <img alt="start" width=50% src="https://api.star-history.com/svg?repos=Loischsiy/MeowClash&Date"/>
    </a>
</p>
