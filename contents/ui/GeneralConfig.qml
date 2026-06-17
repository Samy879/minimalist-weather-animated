import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: configRoot
    title: i18n("General")

    // --- ABSORPTION DES VALEURS PAR DÉFAUT (Pour nettoyer les logs) ---
    property var cfg_useCoordinatesIpDefault
    property var cfg_latitudeCDefault
    property var cfg_longitudeCDefault
    property var cfg_showConditionOnPanelDefault
    property var cfg_showConditionFullDefault
    property var cfg_reverseOrderDefault
    property var cfg_temperatureUnitDefault
    property var cfg_sizeFontTempDefault
    property var cfg_sizeFontCondDefault
    property var cfg_textweatherDefault
    property var cfg_preciseTempDefault
    property var cfg_preciseTempChartDefault
    property var cfg_updateIntervalDefault
    property var cfg_forecastStartDayDefault
    property var cfg_boldTempPanelDefault
    property var cfg_boldCondPanelDefault
    property var cfg_showApparentTempDefault
    property var cfg_showHumidityDefault
    property var cfg_showUVIndexDefault
    property var cfg_showWindDefault
    property var cfg_showAnimationsDefault
    property var cfg_refreshTriggerDefault
    property var cfg_borderRadiusDefault

    // --- ALIAS DE CONFIGURATION ---
    property alias cfg_borderRadius: borderRadiusSpin.value

    property alias cfg_showAnimations: showAnimationsCheck.checked
    property alias cfg_showConditionFull: conditionFullCheck.checked
    property alias cfg_useCoordinatesIp: autoCoorde.checked
    property alias cfg_latitudeC: latitudeField.text
    property alias cfg_longitudeC: longitudeField.text
    property alias cfg_temperatureUnit: temperatureCombo.currentIndex
    property alias cfg_updateInterval: intervalSpin.value
    property alias cfg_textweather: textWeatherCheck.checked
    property alias cfg_showConditionOnPanel: conditionOnPanelCheck.checked

    property alias cfg_preciseTemp: preciseTempCheck.checked
    property alias cfg_preciseTempChart: preciseTempChartCheck.checked

    property alias cfg_reverseOrder: reverseCheck.checked
    property alias cfg_sizeFontTemp: fontSizeTempSpin.realValue
    property alias cfg_boldTempPanel: boldTempCheck.checked
    property alias cfg_sizeFontCond: fontSizeCondSpin.realValue
    property alias cfg_boldCondPanel: boldCondCheck.checked
    property alias cfg_forecastStartDay: startDaySpin.value
    property alias cfg_showApparentTemp: apparentCheck.checked
    property alias cfg_showHumidity: humidityCheck.checked
    property alias cfg_showUVIndex: uvCheck.checked
    property alias cfg_showWind: windCheck.checked

    // Alias obligatoire pour le déclencheur de rafraîchissement
    property alias cfg_refreshTrigger: refreshTriggerHidden.value

    Kirigami.FormLayout {

        SpinBox {
            id: refreshTriggerHidden
            visible: false
        }

        // --- LOCALISATION ---
        CheckBox {
            id: autoCoorde
            Kirigami.FormData.label: i18n("Automatic Location (IP):")
        }
        TextField {
            id: latitudeField
            Kirigami.FormData.label: i18n("Latitude:")
            visible: !autoCoorde.checked
        }
        TextField {
            id: longitudeField
            Kirigami.FormData.label: i18n("Longitude:")
            visible: !autoCoorde.checked
        }

        Kirigami.Separator { }

        // --- ANIMATIONS ---
        CheckBox {
            id: showAnimationsCheck
            Kirigami.FormData.label: i18n("Enable weather animations:")
        }

        Kirigami.Separator { }

        // --- SYSTÈME & UNITÉS ---
        ComboBox {
            id: temperatureCombo
            Kirigami.FormData.label: i18n("Temperature & Speed Unit:")
            model: [i18n("(°C) / (km/h)"), i18n("(°F) / (mph)")]
        }
        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Update Interval (min):")
            from: 5; to: 360; stepSize: 5
        }

        Kirigami.Separator { }

        // --- CONFIGURATION DU PANEL ---
        CheckBox { id: textWeatherCheck; Kirigami.FormData.label: i18n("Show temperature:") }
        CheckBox { id: conditionOnPanelCheck; Kirigami.FormData.label: i18n("Show condition text (panel):") }
        CheckBox { id: conditionFullCheck; Kirigami.FormData.label: i18n("Show condition text (Full view):") }
        CheckBox { id: preciseTempCheck; Kirigami.FormData.label: i18n("Show decimals (only panel):") }
        CheckBox { id: preciseTempChartCheck; Kirigami.FormData.label: i18n("Show decimals on charts:") }
        CheckBox { id: reverseCheck; Kirigami.FormData.label: i18n("Reverse Temp/Condition order:") }

        Kirigami.Separator { }

        // --- STYLE & POLICES ---
        SpinBox {
            id: borderRadiusSpin
            Kirigami.FormData.label: i18n("Border radius (desktop view):")
            from: 0; to: 40; stepSize: 1
        }

        SpinBox {
            id: fontSizeTempSpin
            Kirigami.FormData.label: i18n("Temperature font size:")
            property real realValue: 11.0
            value: Math.round(realValue * 10)
            onValueModified: realValue = value / 10
            editable: true
            from: 80; to: 300; stepSize: 5
            textFromValue: (value, locale) => Number(value / 10).toLocaleString(locale, 'f', 1)
            valueFromText: (text, locale) => Math.round(Number.fromLocaleString(locale, text) * 10)
        }
        CheckBox { id: boldTempCheck; Kirigami.FormData.label: i18n("Bold temperature:") }

        SpinBox {
            id: fontSizeCondSpin
            Kirigami.FormData.label: i18n("Condition font size:")
            property real realValue: 10.0
            value: Math.round(realValue * 10)
            onValueModified: realValue = value / 10
            editable: true
            from: 50; to: 250; stepSize: 5
            textFromValue: (value, locale) => Number(value / 10).toLocaleString(locale, 'f', 1)
            valueFromText: (text, locale) => Math.round(Number.fromLocaleString(locale, text) * 10)
        }
        CheckBox { id: boldCondCheck; Kirigami.FormData.label: i18n("Bold condition text:") }

        Kirigami.Separator { }

        // --- DÉTAILS À AFFICHER ---
        Kirigami.Separator { Kirigami.FormData.label: i18n("Details to show:") }
        CheckBox { id: apparentCheck; text: i18n("Apparent Temperature") }
        CheckBox { id: humidityCheck; text: i18n("Humidity") }
        CheckBox { id: uvCheck; text: i18n("UV Index") }
        CheckBox { id: windCheck; text: i18n("Wind Speed") }

        Kirigami.Separator { }

        // --- PRÉVISIONS ---
        SpinBox {
            id: startDaySpin
            Kirigami.FormData.label: i18n("Forecast start day offset:")
            from: 0; to: 4; stepSize: 1
        }

        Kirigami.Separator { }

        // --- ACTION MANUELLE ---
        Button {
            id: manualRefreshButton
            Kirigami.FormData.label: i18n("Manual Actions:")
            text: i18n("Refresh Weather Data")
            icon.name: "view-refresh"
            onClicked: refreshTriggerHidden.value++
            Layout.fillWidth: true
        }
    }
}
