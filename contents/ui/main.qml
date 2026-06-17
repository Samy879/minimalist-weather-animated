import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "components" as Components

PlasmoidItem {
  id: root
  width: compactRepresentation.implicitWidth

  Components.WeatherData {
    id: weatherSource
  }

  // Propriétés de configuration (Lien avec main.xml)
  property bool showConditionOnPanel: Plasmoid.configuration.showConditionOnPanel
  property int borderRadius: Plasmoid.configuration.borderRadius
  property bool showAnimations: Plasmoid.configuration.showAnimations
  property bool boldTempPanel: Plasmoid.configuration.boldTempPanel
  property bool boldCondPanel: Plasmoid.configuration.boldCondPanel
  property bool reverseOrder: Plasmoid.configuration.reverseOrder
  property int temperatureUnit: Plasmoid.configuration.temperatureUnit
  property real sizeFontTemp: Plasmoid.configuration.sizeFontTemp
  property real sizeFontCond: Plasmoid.configuration.sizeFontCond

  property bool preciseTemp: Plasmoid.configuration.preciseTemp
  property bool preciseTempChart: Plasmoid.configuration.preciseTempChart

  property bool showApparentTemp: Plasmoid.configuration.showApparentTemp
  property bool showHumidity: Plasmoid.configuration.showHumidity
  property bool showUVIndex: Plasmoid.configuration.showUVIndex
  property bool showWind: Plasmoid.configuration.showWind

  // Gère l'affichage du titre dans la vue détaillée
  property bool showConditionFull: Plasmoid.configuration.showConditionFull

  property bool textweather: Plasmoid.configuration.textweather
  property int forecastStartDay: Plasmoid.configuration.forecastStartDay

  // Référence vers la FullRepresentation pour pouvoir appeler resetScroll()
  property var fullRepRef: null

  property var days: []
  Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
  preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

  Component.onCompleted: {
    let locale = Qt.locale();
    let tempDays = [];
    for (let i = 0; i < 7; i++) {
      tempDays.push(locale.dayName(i, Locale.ShortFormat));
    }
    days = tempDays;
  }

  compactRepresentation: CompactRepresentation {
    weatherData: weatherSource
  }

  fullRepresentation: FullRepresentation {
    weatherData: weatherSource
    Component.onCompleted: root.fullRepRef = this
  }

  Connections {
    target: root
    function onExpandedChanged() {
      if (root.expanded && root.fullRepRef) {
        root.fullRepRef.resetScroll();
      }
    }
  }
}
