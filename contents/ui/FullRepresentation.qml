import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import "components" as Components
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: rootItem

    property var weatherData

    property int temperatureUnit: root.temperatureUnit

    readonly property string unitStr: (temperatureUnit === 0) ? "°C" : "°F"
    readonly property string currentTempText: (weatherData && weatherData.temperaturaActualPopup) ? weatherData.temperaturaActualPopup : "--"
    readonly property bool anyDetailEnabled: !!(root.showApparentTemp || root.showHumidity || root.showUVIndex || root.showWind)
    readonly property bool showBottomDetails: !!(anyDetailEnabled && root.showConditionFull)

    // --- VUE DÉTAIL JOURNALIÈRE (courbes) ---
    // -1 = vue classique. >= 0 = index du jour sélectionné.
    property int selectedDayIndex: -1

    // Courbe active dans la vue détail : 0=temp, 1=humidity, 2=wind, 3=uv
    property int activeChart: 0

    readonly property var hourlyData: (weatherData && weatherData.weatherData && weatherData.weatherData.hourly) ? weatherData.weatherData.hourly : null
    readonly property bool hasHourlyData: !!hourlyData

    // Accès sécurisé et centralisé aux données journalières. Évite de répéter
    // "weatherData && weatherData.weatherData && weatherData.weatherData.daily"
    // à chaque utilisation — l'original accédait parfois directement à
    // ".weatherData.daily" sans vérifier l'étage intermédiaire, ce qui pouvait
    // planter le popup si "weatherData" existait sans "weatherData.weatherData".
    readonly property var dailyData: (weatherData && weatherData.weatherData && weatherData.weatherData.daily) ? weatherData.weatherData.daily : null

    // Index du jour courant dans le tableau daily
    readonly property int currentDayIndex: {
        if (!dailyData) return 0;
        let today = new Date();
        let todayStr = today.getFullYear() + "-" +
        String(today.getMonth() + 1).padStart(2, "0") + "-" +
        String(today.getDate()).padStart(2, "0");
        let times = dailyData.time;
        for (let i = 0; i < times.length; i++) {
            if (times[i] === todayStr) return i;
        }
        return 0;
    }

    // Source unique de vérité pour les 4 courbes (température, humidité, vent,
    // UV) : libellé complet, libellé court d'onglet, unité et couleur. Avant,
    // ces informations étaient dupliquées dans deux switch/case distincts et
    // dans 4 littéraux de couleur répétés pour les onglets — toute couleur
    // changée à un endroit risquait d'être oubliée à l'autre.
    readonly property var chartDefs: [
        {
            field: "temperature_2m",
            label: i18n("Temp."),
            tabLabel: i18n("Temp."),
            unit: unitStr,
            color: Qt.rgba(0.92, 0.62, 0.15, 1.0) // ambre
        },
        {
            field: "relative_humidity_2m",
            label: i18n("Hum."),
            tabLabel: i18n("Hum."),
            unit: "%",
            color: Qt.rgba(0.29, 0.56, 0.88, 1.0) // bleu doux
        },
        {
            field: "wind_speed_10m",
            label: i18n("Wind"),
            tabLabel: i18n("Wind"),
            unit: (temperatureUnit === 0 ? " km/h" : " mph"),
            color: Qt.rgba(0.29, 0.50, 0.66, 1.0)
        },
        {
            field: "uv_index",
            label: i18n("UV Index"),
            tabLabel: i18n("UV"),
            unit: "",
            color: Qt.rgba(0.55, 0.25, 0.90, 1.0) // violet
        }
    ]

    function hourlySlice(fieldName) {
        if (!hourlyData || !hourlyData[fieldName] || selectedDayIndex < 0) return [];
        let start = selectedDayIndex * 24;
        return hourlyData[fieldName].slice(start, start + 24);
    }

    function openDayDetail(dayIndex) {
        if (hasHourlyData) {
            activeChart = 0; // reset à température à chaque ouverture
            selectedDayIndex = dayIndex;
        }
    }

    function closeDayDetail() {
        selectedDayIndex = -1;
    }

    function resetScroll() {
        forecastSection.positionViewAtBeginning();
        closeDayDetail();
    }

    readonly property int fixedWidth: Kirigami.Units.gridUnit * 15
    readonly property int calculatedHeight: {
        let base = Kirigami.Units.gridUnit * 12.5;
        return (showBottomDetails) ? base : (base - Kirigami.Units.gridUnit * 2.5);
    }

    width: fixedWidth
    height: calculatedHeight
    Layout.minimumWidth: fixedWidth
    Layout.maximumWidth: fixedWidth
    Layout.preferredWidth: fixedWidth
    Layout.minimumHeight: calculatedHeight
    Layout.maximumHeight: calculatedHeight
    Layout.preferredHeight: calculatedHeight

    // --- 1. LE FOND ANIMÉ ---
    Rectangle {
        id: backgroundContainer
        anchors { fill: parent; margins: -8 }
        color: Kirigami.Theme.backgroundColor
        radius: root.borderRadius
        clip: true

        layer.enabled: !!plasmoid.configuration.showAnimations
        layer.smooth: true
        z: -1

        Item {
            id: animationsLayers
            anchors.fill: parent

            visible: !!(plasmoid.configuration.showAnimations &&
            weatherData &&
            weatherData.weatherData &&
            weatherData.temperaturaActual !== "--")

            // Vrai quand on inspecte un jour précis dans la vue détail
            // (courbes). Dans ce cas, le fond animé doit refléter la météo
            // DE CE JOUR-LÀ plutôt que la condition réelle actuelle.
            readonly property bool dayDetailActive: rootItem.selectedDayIndex !== -1

            // Code météo affiché par le fond. En vue détail, on suit
            // désormais l'heure SURVOLÉE sur la courbe plutôt que le code
            // unique du jour entier : avant, weatherCode restait figé sur
            // dailyData.weather_code (un seul effet — pluie, brume, etc. —
            // pour toute la journée), alors que isDay et windValue
            // suivaient déjà viewedHour. weather_code existe aussi dans
            // les données horaires (hourlyParams le demande déjà dans
            // GetWeather.js), donc aucune requête supplémentaire n'est
            // nécessaire : hourlySlice("weather_code") donne directement
            // le code de l'heure pointée. Sans survol, on retombe sur le
            // code du jour entier (comportement inchangé), et en vue
            // classique sur la condition réelle actuelle.
            readonly property int weatherCode: {
                if (dayDetailActive) {
                    // 1. Si on survole une heure précise, on prend la prévision de cette heure
                    if (dayLineChart && dayLineChart.hoverIndex !== -1 && rootItem.hasHourlyData) {
                        let codeSlice = rootItem.hourlySlice("weather_code");
                        let hc = codeSlice[animationsLayers.viewedHour];
                        if (hc !== undefined && hc !== null) return parseInt(hc);
                    }

                    // --- DÉBUT DE LA CORRECTION ---
                    // 2. Pas de survol, mais on est sur le JOUR ACTUEL :
                    // On affiche la condition réelle actuelle au lieu de la globale du jour.
                    if (rootItem.selectedDayIndex === rootItem.currentDayIndex) {
                        return weatherData && weatherData.codeweather ? parseInt(weatherData.codeweather) : 0;
                    }
                    // --- FIN DE LA CORRECTION ---

                    // 3. Pas de survol, et on regarde un AUTRE jour (passé ou futur) :
                    // On se rabat sur la tendance globale de ce jour-là.
                    if (rootItem.dailyData && rootItem.dailyData.weather_code) {
                        let code = rootItem.dailyData.weather_code[rootItem.selectedDayIndex];
                        return (code !== undefined && code !== null) ? parseInt(code) : 0;
                    }
                    return 0;
                }

                // Vue classique (widget réduit ou courbes fermées)
                return weatherData && weatherData.codeweather ? parseInt(weatherData.codeweather) : 0;
            }

            // Minute "regardée" dans la journée (0-1439) : celle survolée
            // sur la courbe en vue détail (le marqueur suit la souris sur le
            // graphique — précision à l'heure, c'est la seule offerte par
            // les données horaires), sinon l'heure réelle actuelle à la
            // minute près. Sans survol, on retombe simplement sur
            // "maintenant".
            readonly property int viewedMinutes: {
                if (dayDetailActive && dayLineChart && dayLineChart.hoverIndex !== -1) {
                    return dayLineChart.hoverIndex * 60;
                }
                let now = new Date();
                return now.getHours() * 60 + now.getMinutes();
            }
            readonly property int viewedHour: Math.floor(viewedMinutes / 60)

            // Extrait "HH:MM" d'une chaîne ISO Open-Meteo (ex: "2026-06-17T05:48")
            // et la convertit en minutes depuis minuit. La requête utilise
            // "timezone=auto", donc cette heure est déjà locale — pas de
            // conversion de fuseau à faire ici.
            function minutesFromIso(iso) {
                if (!iso) return null;
                let t = iso.split("T")[1];
                if (!t) return null;
                let p = t.split(":");
                return parseInt(p[0]) * 60 + parseInt(p[1]);
            }

            // Jour/nuit à partir du VRAI lever et coucher de soleil du jour
            // concerné (rootItem.dailyData.sunrise/sunset), plutôt que d'un
            // seuil fixe 7h-20h qui mentait en plein hiver ou en plein été.
            // Repli sur l'heuristique 7h-20h si ces données venaient à
            // manquer (sécurité).
            function isDayAt(dayIdx, minutesOfDay) {
                let sunrise = (rootItem.dailyData && rootItem.dailyData.sunrise) ? minutesFromIso(rootItem.dailyData.sunrise[dayIdx]) : null;
                let sunset  = (rootItem.dailyData && rootItem.dailyData.sunset)  ? minutesFromIso(rootItem.dailyData.sunset[dayIdx])  : null;
                if (sunrise === null || sunset === null) {
                    let h = Math.floor(minutesOfDay / 60);
                    return (h >= 7 && h <= 20);
                }
                return minutesOfDay >= sunrise && minutesOfDay < sunset;
            }

            // Vent : pris dans les prévisions horaires du jour inspecté (à
            // l'heure regardée) en vue détail, sinon le vent réel actuel.
            readonly property real windValue: {
                if (dayDetailActive && rootItem.hasHourlyData) {
                    let windSlice = rootItem.hourlySlice("wind_speed_10m");
                    let v = windSlice[animationsLayers.viewedHour];
                    return (v !== undefined) ? parseFloat(v) : 0;
                }
                return weatherData && weatherData.windSpeed && weatherData.windSpeed !== "--" ? parseFloat(weatherData.windSpeed) : 0;
            }

            readonly property bool isDay: {
                if (!dayDetailActive) {
                    // Vue classique ("maintenant") : on privilégie le drapeau
                    // is_day renvoyé par l'API pour l'instant présent — déjà
                    // calculé côté serveur, c'est la source la plus fiable.
                    if (weatherData && weatherData.weatherData && weatherData.weatherData.current) {
                        return weatherData.weatherData.current.is_day === 1;
                    }
                    return isDayAt(rootItem.currentDayIndex, viewedMinutes);
                }
                // Vue détail : vrai lever/coucher DU JOUR SÉLECTIONNÉ, comparé
                // à l'heure regardée sur la courbe.
                return isDayAt(rootItem.selectedDayIndex, viewedMinutes);
            }

            // --- Soleil / Nuit en fondu croisé ---
            // Avant : un seul Loader dont la "source" basculait entre les
            // deux animations selon isDay. À chaque bascule, QML détruit
            // entièrement l'ancien composant et instancie le nouveau —
            // d'où la coupure nette. Ici, les deux animations restent
            // chargées en permanence (donc jamais détruites/recréées) et on
            // fait varier leur opacité en sens inverse avec un Behavior :
            // le changement devient un fondu doux plutôt qu'un instantané.
            // Comme isDay peut changer plusieurs fois rapidement pendant un
            // survol de la courbe, le Behavior se "retargete" en douceur à
            // chaque nouvelle valeur sans jamais sembler saccadé.
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/soleil.qml"
                opacity: animationsLayers.isDay ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/nuit.qml"
                opacity: animationsLayers.isDay ? 0.0 : 1.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            // --- Effets météo (nuage / pluie / neige / etc.) en fondu ---
            // Même principe que Soleil/Nuit ci-dessus : avant, un Loader
            // unique changeait de "source" selon le code météo, ce qui
            // détruisait et recréait l'effet à chaque bascule — coupure
            // nette, et de toute façon weatherCode ne suivait pas l'heure
            // survolée donc l'effet ne changeait jamais pendant un survol.
            // Maintenant que weatherCode suit viewedHour, le survol de la
            // courbe peut faire défiler plusieurs conditions météo dans la
            // même journée ; chaque effet reste chargé en permanence et
            // seule son opacité varie, avec le même Behavior (1100ms) que
            // pour isDay, pour un fondu cohérent entre tous les effets de
            // fond plutôt qu'un instantané pour les uns et un fondu pour
            // les autres.
            readonly property bool showCloud:  weatherCode >= 3 && weatherCode !== 45 && weatherCode !== 48
            readonly property bool showOrage:  weatherCode >= 95
            readonly property bool showNeige:  (weatherCode >= 71 && weatherCode <= 77) || weatherCode === 85 || weatherCode === 86
            readonly property bool showPluie:  (weatherCode >= 61 && weatherCode <= 67) || (weatherCode >= 80 && weatherCode <= 82)
            readonly property bool showBruine: weatherCode >= 51 && weatherCode <= 57
            readonly property bool showBrume:  weatherCode === 45 || weatherCode === 48

            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/nuage.qml"
                opacity: animationsLayers.showCloud ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/orage.qml"
                opacity: animationsLayers.showOrage ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/neige.qml"
                opacity: animationsLayers.showNeige ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/pluie.qml"
                opacity: animationsLayers.showPluie ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/bruine.qml"
                opacity: animationsLayers.showBruine ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/brume.qml"
                opacity: animationsLayers.showBrume ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
            // Vent : même traitement de cohérence — windValue suit déjà
            // viewedHour, donc sans ce fondu le vent apparaîtrait/
            // disparaîtrait brutalement pendant le survol alors que tous
            // les autres effets de fond sont désormais en transition douce.
            Loader {
                anchors.fill: parent
                active: !!(plasmoid.configuration.showAnimations && animationsLayers.visible)
                source: "animations/vent.qml"
                opacity: animationsLayers.windValue >= 20 ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 1100; easing.type: Easing.InOutSine } }
            }
        }
    }

    // --- 2. LAYOUT PRINCIPAL ---
    Item {
        id: infoLayout
        anchors.fill: parent

        // ============================================================
        // === VUE CLASSIQUE ===
        // ============================================================
        ColumnLayout {
            id: classicContent
            anchors.fill: parent
            spacing: 0

            // Fondu croisé entre vue classique et vue détail, plutôt qu'une
            // bascule de "visible" sèche : rendu plus doux, toujours minimal.
            opacity: rootItem.selectedDayIndex === -1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RowLayout {
                id: headerSection
                Layout.fillWidth: true
                Layout.topMargin: -Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.gridUnit
                Layout.rightMargin: Kirigami.Units.gridUnit
                spacing: 0

                Item { Layout.fillWidth: true; visible: !rightSideContainer.visible }

                Row {
                    id: tempContainer
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents3.Label {
                        text: currentTempText
                        font.pixelSize: Kirigami.Units.gridUnit * 2.5
                        font.bold: true
                        leftPadding: currentTempText.length === 1 ? Kirigami.Units.gridUnit * 0.4 : 0
                        // BUG FIX (texte noir lors d'un changement de thème) :
                        // un bug connu de Kirigami/Plasma fait que la couleur
                        // héritée d'un Label ne se repropage pas toujours de
                        // façon fiable pendant une transition de thème,
                        // surtout dans un sous-arbre animé en opacité comme
                        // celui-ci (cf. headerSection, ligne ~302). Fixer
                        // explicitement color: Kirigami.Theme.textColor crée
                        // un binding direct, qui se réévalue de façon fiable
                        // au lieu de dépendre de cette chaîne d'héritage.
                        color: Kirigami.Theme.textColor
                    }
                    PlasmaComponents3.Label {
                        text: unitStr
                        font.pixelSize: Kirigami.Units.gridUnit * 1.5
                        font.bold: true
                        topPadding: Kirigami.Units.gridUnit * 0.2
                        color: Kirigami.Theme.textColor
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    id: rightSideContainer
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    visible: !!(root.showConditionFull || anyDetailEnabled)

                    PlasmaComponents3.Label {
                        visible: !!root.showConditionFull
                        Layout.fillWidth: true
                        text: weatherData ? weatherData.weatherLongtext : ""
                        font.pixelSize: text.length <= 10 ? Kirigami.Units.gridUnit * 1.3 : Kirigami.Units.gridUnit * 1.0
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: Kirigami.Units.gridUnit * 0.55
                        color: Kirigami.Theme.textColor
                    }

                    GridLayout {
                        id: detailsGrid
                        visible: !!(!root.showConditionFull && anyDetailEnabled)
                        columns: 2
                        rowSpacing: Kirigami.Units.gridUnit * 0.3
                        columnSpacing: Kirigami.Units.smallSpacing
                        layoutDirection: Qt.RightToLeft
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                        // Micro-ajustement visuel : compense le padding interne
                        // des Label pour un alignement optique parfait avec le
                        // bord droit du widget.
                        readonly property real rightNudge: -7.5
                        Layout.rightMargin: rightNudge
                        Layout.topMargin: root.showConditionFull ? 0 : Kirigami.Units.gridUnit * 0.4

                        // On ne génère que les éléments réellement visibles :
                        // plus besoin de "visible: !!root.showX" sur chaque
                        // CompactGridItem, et GridLayout n'a rien à exclure.
                        readonly property var quickStats: [
                            { label: i18n("Wind"),  value: (weatherData && weatherData.windSpeed !== "--") ? (weatherData.windSpeed + (temperatureUnit === 0 ? " km/h" : " mph")) : "--", show: !!root.showWind },
                            { label: i18n("UV"),    value: (weatherData && weatherData.uvIndex !== "--") ? weatherData.uvIndex : "--", show: !!root.showUVIndex },
                            { label: i18n("Hum."),  value: (weatherData && weatherData.humidity !== "--") ? (weatherData.humidity + "%") : "--", show: !!root.showHumidity },
                            { label: i18n("Feels"), value: (weatherData && weatherData.apparentTemp !== "--") ? (weatherData.apparentTemp + unitStr) : "--", show: !!root.showApparentTemp }
                        ].filter(function (d) { return d.show; })

                        Repeater {
                            model: detailsGrid.quickStats
                            delegate: CompactGridItem {
                                label: modelData.label
                                value: modelData.value
                            }
                        }
                    }
                }
            }

            // --- SECTION PRÉVISIONS ---
            ListView {
                id: forecastSection
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                Layout.topMargin: -Kirigami.Units.gridUnit * 0.5
                spacing: 0
                orientation: ListView.Horizontal

                snapMode: ListView.SnapToItem
                boundsBehavior: Flickable.OvershootBounds
                maximumFlickVelocity: 500
                flickDeceleration: 1000
                interactive: true
                clip: true

                model: (rootItem.dailyData && rootItem.dailyData.time) ? (rootItem.dailyData.time.length - root.forecastStartDay) : 0

                delegate: ColumnLayout {
                    width: forecastSection.width / 3
                    spacing: 0
                    readonly property int dayIndex: index + root.forecastStartDay

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: {
                            if (rootItem.dailyData && rootItem.dailyData.time) {
                                let d = new Date(rootItem.dailyData.time[dayIndex]);
                                return root.days ? root.days[d.getDay()] : "";
                            }
                            return "";
                        }
                        horizontalAlignment: Text.AlignHCenter
                        font.capitalization: Font.Capitalize
                        font.pixelSize: Kirigami.Units.gridUnit * 0.65
                        opacity: 0.8
                        color: Kirigami.Theme.textColor
                    }

                    Item {
                        id: iconWrapper
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.7
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.7
                        Layout.alignment: Qt.AlignHCenter

                        // Pour le jour courant (dayIndex === currentDayIndex),
                        // on utilise codeweather (condition réelle actuelle,
                        // déjà rafraîchie par l'API à chaque requête) plutôt
                        // que dailyData.weather_code[dayIndex], qui est un
                        // résumé/tendance pour la journée entière et peut
                        // donc être daté (ex: calculé tôt le matin, ou
                        // représentant la condition dominante du jour plutôt
                        // que celle de l'instant présent). Pour les autres
                        // jours de la liste (demain, après-demain...), aucune
                        // "condition actuelle" n'existe : on garde le code
                        // météo journalier, seule donnée disponible pour un
                        // jour qui n'est pas encore arrivé.
                        readonly property bool isCurrentDay: dayIndex === rootItem.currentDayIndex
                        readonly property int displayedCode: {
                            if (isCurrentDay && weatherData && weatherData.codeweather !== undefined && weatherData.codeweather !== "--") {
                                return parseInt(weatherData.codeweather);
                            }
                            return (rootItem.dailyData && rootItem.dailyData.weather_code) ? rootItem.dailyData.weather_code[dayIndex] : null;
                        }

                        Kirigami.Icon {
                            anchors.fill: parent
                            source: (rootItem.dailyData && iconWrapper.displayedCode !== null) ? weatherData.asingicon(iconWrapper.displayedCode) : ""
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: rootItem.hasHourlyData
                            enabled: rootItem.hasHourlyData
                            cursorShape: rootItem.hasHourlyData ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rootItem.openDayDetail(dayIndex)
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        PlasmaComponents3.Label {
                            text: rootItem.dailyData ? Math.round(rootItem.dailyData.temperature_2m_max[dayIndex]) + "°" : ""
                            font.bold: true
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            color: Kirigami.Theme.textColor
                        }
                        PlasmaComponents3.Label {
                            text: rootItem.dailyData ? Math.round(rootItem.dailyData.temperature_2m_min[dayIndex]) + "°" : ""
                            opacity: 0.6
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            color: Kirigami.Theme.textColor
                        }
                    }
                }
            }

            RowLayout {
                id: detailsRow
                visible: !!showBottomDetails
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                Layout.leftMargin: Kirigami.Units.gridUnit * 0.5
                Layout.rightMargin: Kirigami.Units.gridUnit * 0.5
                spacing: 0

                // Même principe que pour "quickStats" : on filtre les éléments
                // visibles puis on les enchaîne avec un séparateur entre
                // chaque paire. Avant, chaque séparateur portait une condition
                // manuelle du type "showA && (showB || showC || showD)",
                // fragile dès qu'une option de configuration changeait.
                readonly property var visibleDetails: [
                    { label: i18n("Apparent Temp"), value: (weatherData && weatherData.apparentTemp !== "--") ? (weatherData.apparentTemp + unitStr) : "--", show: !!root.showApparentTemp },
                    { label: i18n("Humidity"),      value: (weatherData && weatherData.humidity !== "--") ? (weatherData.humidity + "%") : "--", show: !!root.showHumidity },
                    { label: i18n("UV Index"),      value: (weatherData && weatherData.uvIndex !== "--") ? weatherData.uvIndex : "--", show: !!root.showUVIndex },
                    { label: i18n("Wind"),          value: (weatherData && weatherData.windSpeed !== "--") ? (weatherData.windSpeed + (temperatureUnit === 0 ? " km/h" : " mph")) : "--", show: !!root.showWind }
                ].filter(function (d) { return d.show; })

                Repeater {
                    model: detailsRow.visibleDetails
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Rectangle {
                            visible: index > 0
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2
                            color: Kirigami.Theme.textColor
                            opacity: 0.15
                            Layout.alignment: Qt.AlignVCenter
                        }
                        DetailColumn {
                            label: modelData.label
                            value: modelData.value
                        }
                    }
                }
            }
        }

        // ============================================================
        // === VUE DÉTAIL ===
        // ============================================================
        ColumnLayout {
            id: dayDetailView
            anchors.fill: parent
            spacing: 0

            opacity: rootItem.selectedDayIndex !== -1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            readonly property string dayLabelFull: {
                if (!rootItem.dailyData || rootItem.selectedDayIndex < 0) return "";
                let d = new Date(rootItem.dailyData.time[rootItem.selectedDayIndex]);
                let locale = Qt.locale();
                return d.toLocaleString(locale, "dddd");
            }

            // Toutes les infos de la courbe active proviennent désormais de
            // "rootItem.chartDefs" — une seule source, plus de switch/case.
            readonly property var activeDef: rootItem.chartDefs[rootItem.activeChart]
            readonly property var activeValues: rootItem.hourlySlice(activeDef.field)
            readonly property string activeUnit: activeDef.unit
            readonly property string activeLabel: activeDef.label
            readonly property color activeColor: activeDef.color

            RowLayout {
                id: navigationHeader
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                spacing: 0

                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: Kirigami.Theme.textColor
                        opacity: backMouse.pressed ? 0.15 : (backMouse.containsMouse ? 0.08 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.gridUnit * 1.0
                        height: Kirigami.Units.gridUnit * 1.0
                        source: "go-previous"
                        opacity: backMouse.pressed ? 0.6 : (backMouse.containsMouse ? 1.0 : 0.75)
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootItem.closeDayDetail()
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.capitalization: Font.Capitalize
                    text: dayDetailView.dayLabelFull
                    color: Kirigami.Theme.textColor
                }

                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                }
            }

            Components.LineChart {
                id: dayLineChart
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing

                label:       dayDetailView.activeLabel
                unit:        dayDetailView.activeUnit
                values:      dayDetailView.activeValues
                lineColor:   dayDetailView.activeColor
                // currentHour est géré en interne par LineChart.qml ; le
                // recalcul est forcé à chaque ouverture via "viewActive"
                // (voir LineChart.qml pour le détail du fix anti-veille).
                isToday:     rootItem.selectedDayIndex === rootItem.currentDayIndex
                viewActive:  rootItem.selectedDayIndex !== -1

                preciseTemp: root.preciseTempChart
                chartType:   rootItem.activeChart
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                component ChartTab : Rectangle {
                    property string tabLabel: ""
                    property int tabIndex: 0
                    property color tabColor: Kirigami.Theme.highlightColor

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                    radius: Kirigami.Units.smallSpacing

                    readonly property bool isActive: rootItem.activeChart === tabIndex
                    color: isActive
                    ? Qt.rgba(tabColor.r, tabColor.g, tabColor.b, 0.20)
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        visible: parent.isActive
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 3
                        height: 2
                        radius: 1
                        color: parent.tabColor
                    }

                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        text: parent.tabLabel
                        font.pixelSize: Kirigami.Units.gridUnit * 0.52
                        font.bold: parent.isActive
                        color: parent.isActive ? parent.tabColor : Kirigami.Theme.textColor
                        opacity: parent.isActive ? 1.0 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    TapHandler {
                        onTapped: rootItem.activeChart = parent.tabIndex
                    }
                }

                Repeater {
                    model: rootItem.chartDefs
                    delegate: ChartTab {
                        tabLabel: modelData.tabLabel
                        tabIndex: index
                        tabColor: modelData.color
                    }
                }
            }
        }
    }

    component CompactGridItem : ColumnLayout {
        property string label: ""
        property string value: ""
        spacing: 1
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2

        PlasmaComponents3.Label {
            text: parent.label
            font.pixelSize: Kirigami.Units.gridUnit * 0.50
            opacity: 0.55
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: Kirigami.Theme.textColor
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            readonly property var _split: {
                let v = parent.value;
                let m = v.match(/^(-?\d+(?:\.\d+)?)\s*(.+)$/);
                return m ? { num: m[1], unit: m[2] } : { num: v, unit: "" };
            }
            // unit type: "degree" for °C/°F, "percent" for %, "speed" for km/h mph
            readonly property string _unitType: {
                let u = _split.unit;
                if (u === "°C" || u === "°F") return "degree";
                if (u === "%") return "percent";
                return "speed";
            }
            PlasmaComponents3.Label {
                id: compactNumLabel
                text: parent._split.num
                font.pixelSize: Kirigami.Units.gridUnit * 0.68
                font.bold: true
                color: Kirigami.Theme.textColor
            }
            // Degree : Symbole ° (Placé tout en haut, un peu plus petit)
            PlasmaComponents3.Label {
                visible: parent._unitType === "degree"
                text: parent._split.unit.charAt(0) // Extrait le "°"
                font.pixelSize: Kirigami.Units.gridUnit * 0.45 // Taille réduite pour le petit rond
                font.bold: true
                leftPadding: 1.2
                anchors.top: compactNumLabel.top
                anchors.topMargin: 1 // Collé au plafond du chiffre
                color: Kirigami.Theme.textColor
            }

            // Degree : Lettre C ou F (Placée légèrement plus bas)
            PlasmaComponents3.Label {
                visible: parent._unitType === "degree"
                text: parent._split.unit.substring(1) // Extrait le "C" ou "F"
                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                font.bold: true
                leftPadding: -0.5
                anchors.top: compactNumLabel.top
                anchors.topMargin: 1.8 // Descend la lettre de 3 pixels (Ajuste selon ton goût)
                color: Kirigami.Theme.textColor
            }
            // Percent → légèrement sous le centre, gap à gauche
            PlasmaComponents3.Label {
                visible: parent._unitType === "percent"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.48
                font.bold: true
                leftPadding: 3
                anchors.verticalCenter: compactNumLabel.verticalCenter
                //anchors.verticalCenterOffset: -Kirigami.Units.gridUnit * 0
                color: Kirigami.Theme.textColor
            }
            // Speed (km/h, mph) → baseline-aligned, small gap
            PlasmaComponents3.Label {
                visible: parent._unitType === "speed"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.50
                font.bold: true
                leftPadding: 2

                // On garde l'alignement sur la ligne de base du chiffre
                anchors.baseline: compactNumLabel.baseline

                anchors.baselineOffset: -0.5

                color: Kirigami.Theme.textColor
            }
        }
    }

    component DetailColumn : ColumnLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 1

        PlasmaComponents3.Label {
            text: parent.label
            font.pixelSize: Kirigami.Units.gridUnit * 0.52
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.60
            color: Kirigami.Theme.textColor
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            readonly property var _split: {
                let v = parent.value;
                let m = v.match(/^(-?\d+(?:\.\d+)?)\s*(.+)$/);
                return m ? { num: m[1], unit: m[2] } : { num: v, unit: "" };
            }
            readonly property string _unitType: {
                let u = _split.unit;
                if (u === "°C" || u === "°F") return "degree";
                if (u === "%") return "percent";
                return "speed";
            }
            PlasmaComponents3.Label {
                id: detailNumLabel
                text: parent._split.num
                font.pixelSize: Kirigami.Units.gridUnit * 0.72
                font.bold: true
                color: Kirigami.Theme.textColor
            }
            // Degree : Symbole ° (Placé tout en haut)
            PlasmaComponents3.Label {
                visible: parent._unitType === "degree"
                text: parent._split.unit.charAt(0)
                font.pixelSize: Kirigami.Units.gridUnit * 0.48
                font.bold: true
                leftPadding: 1
                anchors.top: detailNumLabel.top
                anchors.topMargin: 1
                color: Kirigami.Theme.textColor
            }

            // Degree : Lettre C ou F
            PlasmaComponents3.Label {
                visible: parent._unitType === "degree"
                text: parent._split.unit.substring(1)
                font.pixelSize: Kirigami.Units.gridUnit * 0.55
                font.bold: true
                leftPadding: 0.5
                anchors.top: detailNumLabel.top
                anchors.topMargin: 2 // Descend la lettre de 4 pixels (Ajuste selon ton goût)
                color: Kirigami.Theme.textColor
            }
            PlasmaComponents3.Label {
                visible: parent._unitType === "percent"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.54
                font.bold: true
                leftPadding: 2
                anchors.verticalCenter: detailNumLabel.verticalCenter
                //anchors.verticalCenterOffset: -Kirigami.Units.gridUnit * 0.01
                color: Kirigami.Theme.textColor
            }
            PlasmaComponents3.Label {
                visible: parent._unitType === "speed"
                text: parent._split.unit
                font.pixelSize: Kirigami.Units.gridUnit * 0.53
                font.bold: true
                leftPadding: 2

                // On garde l'accroche sur la ligne de base
                anchors.baseline: detailNumLabel.baseline

                // On décale de quelques pixels vers le HAUT (Valeur négative)
                anchors.baselineOffset: -0.55

                color: Kirigami.Theme.textColor
            }
        }
    }
}
