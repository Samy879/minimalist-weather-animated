import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: iconAndTem

    property var weatherData: root.weatherSource

    Layout.minimumWidth: isVertical ? root.width : initial.implicitWidth
    Layout.minimumHeight: isVertical ? wrapper_vertical.implicitHeight : root.height

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // --- PROPRIÉTÉS DE CONFIGURATION ---
    property bool showTemperatureText: Plasmoid.configuration.textweather
    property real fontTemp: Plasmoid.configuration.sizeFontTemp
    property real fontCond: Plasmoid.configuration.sizeFontCond
    property bool reverseOrder: Plasmoid.configuration.reverseOrder

    readonly property bool showCondition: Plasmoid.configuration.showConditionOnPanel || false

    MouseArea {
        id: panelMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }

    // Léger retour tactile au clic — cohérent avec les éléments interactifs
    // de la vue complète (bouton retour, jours de prévisions cliquables).
    opacity: panelMouse.pressed ? 0.75 : 1.0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    // --- MODE HORIZONTAL (Panel en bas/haut) ---
    RowLayout {
        id: initial
        anchors.fill: parent
        visible: !isVertical
        spacing: 4

        Kirigami.Icon {
            id: icon
            Layout.preferredWidth: parent.height * 0.9
            Layout.preferredHeight: parent.height * 0.9
            Layout.alignment: Qt.AlignVCenter
            source: weatherData.iconWeatherCurrent

            isMask: false
            smooth: true
            roundToIconSize: false
        }

        // Utilisation d'un GridLayout pour permettre l'inversion des lignes
        GridLayout {
            columns: 1
            rowSpacing: 0
            Layout.alignment: Qt.AlignVCenter
            visible: showTemperatureText || showCondition

            // 1. BLOC TEMPÉRATURE
            Row {
                id: tempRow
                visible: showTemperatureText
                // Si reverseOrder est vrai, on passe à la ligne 1 (bas), sinon ligne 0 (haut)
                Layout.row: reverseOrder ? 1 : 0

                PlasmaComponents3.Label {
                    text: root.preciseTemp ? weatherData.temperaturaActual : weatherData.temperaturaActualPopup
                    font.bold: Plasmoid.configuration.boldTempPanel // Mise en gras spécifique température
                    font.pixelSize: fontTemp
                }
                PlasmaComponents3.Label {
                    text: (root.temperatureUnit === 0) ? "°C" : "°F"
                    font.bold: Plasmoid.configuration.boldTempPanel // Mise en gras spécifique température
                    font.pixelSize: fontTemp
                }
            }

            // 2. BLOC CONDITION (Texte court)
            PlasmaComponents3.Label {
                id: conditionLabel
                text: weatherData.weatherShottext
                // Si reverseOrder est vrai, on passe à la ligne 0 (haut), sinon ligne 1 (bas)
                Layout.row: reverseOrder ? 0 : 1
                font.pixelSize: fontCond
                font.bold: Plasmoid.configuration.boldCondPanel // Mise en gras spécifique condition
                opacity: 0.9
                visible: showCondition
                Layout.fillWidth: true
            }
        }
    }

    // --- MODE VERTICAL (Panel à gauche/droite) ---
    ColumnLayout {
        id: wrapper_vertical
        anchors.fill: parent
        visible: isVertical
        spacing: 2

        Kirigami.Icon {
            Layout.preferredWidth: parent.width * 0.8
            Layout.preferredHeight: parent.width * 0.8
            Layout.alignment: Qt.AlignHCenter
            source: weatherData.iconWeatherCurrent
            isMask: false
            smooth: true
            roundToIconSize: false
        }

        PlasmaComponents3.Label {
            text: weatherData.temperaturaActual + "°"
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: fontTemp
            font.bold: Plasmoid.configuration.boldTempPanel // Appliqué ici aussi pour la température
        }
    }
}
