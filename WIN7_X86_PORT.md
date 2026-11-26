# Порт qFlipper на Windows 7 SP1 x86

Этот документ описывает изменения относительно исходной сборки для Windows 10/11 x64.

## Что изменено

| Файл | Изменение |
|---|---|
| `build_windows.bat` | `ARCH_BITS=32`, Qt **5.15.2** (kit `msvc2019`, 32-bit), `vcvars32.bat`, OpenSSL из `Tools\OpenSSL\Win_x86`. На 64-бит: `ARCH_BITS=64` и kit `msvc2019_64`. |
| `installer_windows.nsi` | Минимум Windows 7 SP1. Установка в `Program Files (x86)`. Ключи VC++ runtime для x86. `pnputil -i -a` для Windows 7 (на Windows 8+ остаётся `/add-driver /install`). DPI-хак без `GetDpiForSystem` на Windows 7. `SetRegView` берётся из `ARCH_BITS`. |
| `qflipper_common.pri` | Для Qt5 задано `_WIN32_WINNT=0x0601` и `WINVER=0x0601`. Win8+ API теперь не скомпилируется молча. |
| `application/applicationupdater.cpp` | Для x86 сборки автообновление запрашивает платформу `windows/386` вместо `windows/amd64`. |
| `.github/workflows/ci.yml` | Артефакты Windows переименованы в `qFlipperSetup-32bit.exe` и `qFlipper-32bit.zip`. |
| `README.md` | Требования к сборке под Windows обновлены. |

Код приложения, бэкенд, DFU и USB-слой (SetupAPI/WinUSB) не менялись: они уже совместимы с Windows 7. Все вызовы SetupAPI и WinUSB доступны на Windows 7.

## Требования к машине сборки

- Windows 10/11 x64 (или CI-раннер), Visual Studio 2019 с компонентом MSVC v142.
- Qt 5.15.2 с компонентом **MSVC 2019 32-bit** в `C:\Qt\5.15.2\msvc2019`.
- Qt 5 `Tools\OpenSSL\Win_x86`, `Tools\QtCreator\bin\jom\jom.exe`.
- `C:\Qt\vcredist\vcredist_msvc2019_x86.exe` и `vcredist_x86.exe` (VC++ 2010 x86).
- NSIS 3.x в `Program Files (x86)\NSIS`.
- `C:\STM32 Driver` с драйвером DFU от Flipper.

## Открытые вопросы и что проверить

1. **Ключ платформы обновлений.** В коде стоит `windows/386`. Нужно сверить с сервером обновлений: если там другой ключ для 32-бит, поправить строку в `applicationupdater.cpp`.
2. **Сборка не проверялась компилятором.** В окружении подготовки не было Qt, MSVC и NSIS. Перед релизом нужна реальная сборка `build_windows.bat` на Windows.
3. **Отрисовка QML на Windows 7.** Qt Quick работает через ANGLE/D3D11. На старых видеокартах возможны проблемы. Тогда можно попробовать `QT_QUICK_BACKEND=software` (программная отрисовка).
4. **Обновления Windows.** VC++ 2019 runtime на Windows 7 требует установленного обновления Universal CRT (KB2999226). Без него установщик может не поставить зависимости.
5. **DFU-драйвер.** Установка через `pnputil -i -a` на Windows 7 должна быть проверена на живой машине.
6. **`delete_all_dfu_drivers.ps1`.** Скрипт внешний, должен работать в PowerShell 2.0 (он есть на Windows 7).
7. **`driver-tool`.** Не собирается `build_windows.bat` и не менялся.
