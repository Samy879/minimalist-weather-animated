import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: chartRoot

    property var values: []
    property color lineColor: Kirigami.Theme.highlightColor
    property string unit: ""
    property string label: ""
    property bool preciseTemp: false
    property int chartType: 0 // 0=Temp, 1=Hum, 2=Vent, 3=UV

    // Vrai uniquement si le jour affiché est le jour courant. Un marqueur
    // "heure actuelle" n'a de sens que sur la journée d'aujourd'hui ; sur un
    // jour passé ou futur il serait trompeur (ex: "il est 7h" affiché sur les
    // prévisions de demain). FullRepresentation le calcule via
    // "selectedDayIndex === currentDayIndex".
    property bool isToday: true

    // Vrai pendant que cette vue détail est réellement affichée (jour
    // sélectionné). Sert à couper le timer quand le graphique est caché ET,
    // surtout, à FORCER un recalcul immédiat de l'heure à chaque ouverture.
    //
    // BUG FIX (point figé après une longue veille) : l'ancienne version se
    // fiait uniquement à un Timer minute par minute comparant l'heure à la
    // précédente. Pendant une mise en veille système, l'event loop Qt est
    // gelé : aucun "tick" n'est traité, et selon la plateforme le timer peut
    // ensuite tarder à se resynchroniser au réveil — le marqueur restait
    // alors bloqué sur l'heure d'avant la veille. En recalculant l'heure
    // directement à chaque ouverture de la vue (plutôt que de dépendre d'un
    // historique de tics), le graphique est toujours correct dès l'affichage,
    // indépendamment de ce qu'a fait le timer pendant que le widget dormait.
    property bool viewActive: false

    property int currentHour: new Date().getHours()

    function refreshCurrentHour() {
        let h = new Date().getHours();
        if (chartRoot.currentHour !== h) {
            chartRoot.currentHour = h;
        }
    }

    onViewActiveChanged: {
        if (viewActive) {
            refreshCurrentHour();
            canvas.requestPaint(); // au cas où l'heure n'a pas changé mais que values l'a (autre jour)
        }
    }

    Timer {
        interval: 30000   // 30s : réactif sans solliciter le CPU pour rien
        running: chartRoot.viewActive
        repeat: true
        triggeredOnStart: true // se resynchronise dès la réactivation, pas seulement après 30s
        onTriggered: chartRoot.refreshCurrentHour()
    }

    property int hoverIndex: -1

    function arrMin(a) {
        if (!a || a.length === 0) return 0;
        let m = a[0];
        for (let i = 1; i < a.length; i++) { if (a[i] < m) m = a[i]; }
        return m;
    }
    function arrMax(a) {
        if (!a || a.length === 0) return 1;
        let m = a[0];
        for (let i = 1; i < a.length; i++) { if (a[i] > m) m = a[i]; }
        return m;
    }

    readonly property real minV: arrMin(values)
    readonly property real maxV: arrMax(values)

    // Marges asymétriques (identiques à l'original)
    readonly property real padLeft:   Kirigami.Units.gridUnit * 1.5
    readonly property real padRight:  Kirigami.Units.gridUnit * 0.7
    readonly property real padTop:    Kirigami.Units.gridUnit * 0.6
    readonly property real padBottom: Kirigami.Units.gridUnit * 1.2

    // --- PALETTE PAR TYPE DE COURBE ---
    // Avant : la couleur de remplissage (getFillColor) et le dégradé du trait
    // (un bloc if/else par type) étaient deux logiques séparées et dupliquées.
    // Ici, une seule fonction décrit pour chaque type : le domaine de valeurs
    // utilisé par le dégradé vertical du trait (top = valeur en haut du
    // graphique, bottom = valeur en bas), les arrêts de couleur de ce
    // dégradé, et la couleur de remplissage (fonction de la valeur, pour la
    // température et l'UV qui changent de teinte selon l'intensité).
    // Les couleurs et seuils sont strictement ceux de la version d'origine.
    function paletteFor(type, unitText) {
        switch (type) {
            case 0: { // Température
                let isF = unitText.indexOf("F") !== -1;
                return {
                    domain: isF ? { top: 113, bottom: 14 } : { top: 45, bottom: -10 },
                    stops: [
                        [0.000, "#8B0000"], [0.181, "#DC143C"], [0.272, "#FF4500"],
                        [0.363, "#FF8C00"], [0.454, "#FFD700"], [0.545, "#32CD32"],
                        [0.636, "#00BFFF"], [0.818, "#1E90FF"], [1.000, "#00008B"]
                    ],
                    fillColor: function (v) {
                        let valC = isF ? (v - 32) * 5 / 9 : v;
                        if (valC >= 35) return "220, 20, 60";
                        if (valC >= 30) return "255, 69, 0";
                        if (valC >= 25) return "255, 140, 0";
                        if (valC >= 20) return "255, 215, 0";
                        if (valC >= 15) return "50, 205, 50";
                        if (valC >= 10) return "0, 191, 255";
                        if (valC >= 0)  return "30, 144, 255";
                        return "0, 0, 139";
                    }
                };
            }
            case 1: // Humidité
                return {
                    domain: { top: 100, bottom: 0 },
                    stops: [[0.0, "#2C3E50"], [0.5, "#4A90E2"], [1.0, "#AED6F1"]],
                    fillColor: function () { return "74, 144, 226"; }
                };
            case 2: { // Wind — bleu ardoise
                let isMph = unitText.indexOf("mph") !== -1;
                return {
                    domain: { top: isMph ? 62 : 100, bottom: 0 },
                    stops: [
                        [0.0, "#2A5070"],
                        [0.5, "#4A7FA8"],
                        [1.0, "#A8C8E0"]
                    ],
                    fillColor: function() { return "74, 127, 168"; }
                };
            }
            case 3: // UV
                return {
                    domain: { top: 12, bottom: 0 },
                    stops: [[0.00, "#800080"], [0.33, "#FF0000"], [0.50, "#FF8C00"], [0.75, "#FFD700"], [1.00, "#32CD32"]],
                    fillColor: function (v) {
                        if (v >= 8) return "255, 0, 0";
                        if (v >= 6) return "255, 140, 0";
                        if (v >= 3) return "255, 215, 0";
                        return "50, 205, 50";
                    }
                };
            default:
                return null;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: chartRoot.label + (chartRoot.unit ? " (" + chartRoot.unit.trim() + ")" : "")
                font.pixelSize: Kirigami.Units.gridUnit * 0.55
                font.bold: true
                // Couleur fixée explicitement plutôt que laissée à
                // l'héritage automatique de palette Kirigami. BUG FIX
                // (texte noir lors d'un changement de thème) : un bug connu
                // de Kirigami/Plasma fait que la couleur héritée d'un Label
                // ne se repropage pas toujours de façon fiable pendant une
                // transition de thème ou une animation d'opacité/visibilité
                // (cf. bug KDE 497054) — le Label peut alors rester
                // figé sur la couleur de texte de l'ancien thème (sombre)
                // alors que le fond, lui, a déjà basculé sombre, d'où un
                // texte noir illisible. Un binding direct sur
                // Kirigami.Theme.textColor se réévalue de façon fiable,
                // indépendamment de cette chaîne d'héritage défaillante.
                color: Kirigami.Theme.textColor
                opacity: 1.0
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Label {
                text: chartRoot.values.length
                ? (chartRoot.preciseTemp ? parseFloat(chartRoot.minV.toFixed(1)) : Math.round(chartRoot.minV)) + " – " +
                (chartRoot.preciseTemp ? parseFloat(chartRoot.maxV.toFixed(1)) : Math.round(chartRoot.maxV))
                : "--"
                font.pixelSize: Kirigami.Units.gridUnit * 0.5
                color: Kirigami.Theme.textColor
                opacity: 0.9
            }
        }

        Canvas {
            id: canvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true
            renderTarget: Canvas.Image

            readonly property var pts: chartRoot.values
            readonly property real pL: chartRoot.padLeft
            readonly property real pR: chartRoot.padRight
            readonly property real pT: chartRoot.padTop
            readonly property real pB: chartRoot.padBottom

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                // Position d'entrée dans la zone — on ignore les mouvements
                // tant que la souris n'a pas bougé d'au moins 8px depuis l'entrée,
                // ce qui évite que le clic sur l'icône météo déplace immédiatement
                // le marqueur.
                property real _entryX: -1
                property real _entryY: -1
                property bool _moved: false

                onEntered: {
                    _entryX = -1;
                    _entryY = -1;
                    _moved  = false;
                }
                onExited: {
                    _moved = false;
                    chartRoot.hoverIndex = -1;
                }

                onPositionChanged: (mouse) => {
                    // Mémorise la position d'entrée au premier événement
                    if (_entryX < 0) {
                        _entryX = mouse.x;
                        _entryY = mouse.y;
                    }

                    // N'active le hover qu'après un vrai déplacement (>= 8px)
                    if (!_moved) {
                        let dx = mouse.x - _entryX;
                        let dy = mouse.y - _entryY;
                        if ((dx * dx + dy * dy) < 64) return;
                        _moved = true;
                    }

                    let w = canvas.width;
                    let h = canvas.height;
                    let n = chartRoot.values.length;
                    if (n < 2) return;

                    let pL = chartRoot.padLeft;
                    let pR = chartRoot.padRight;
                    let pT = chartRoot.padTop;
                    let pB = chartRoot.padBottom;
                    let rawIdx = Math.round((mouse.x - pL) / (w - pL - pR) * (n - 1));
                    let idx = Math.max(0, Math.min(rawIdx, n - 1));

                    let range = (chartRoot.maxV - chartRoot.minV) || 1;
                    let val = chartRoot.values[idx];
                    let ptY = pT + (h - pT - pB) * (1 - (val - chartRoot.minV) / range);
                    let isAxisHover = mouse.y >= (h - pB - 15);
                    let isCurveHover = Math.abs(mouse.y - ptY) <= 30;
                    if (isAxisHover || isCurveHover) {
                        chartRoot.hoverIndex = idx;
                    } else {
                        chartRoot.hoverIndex = -1;
                    }
                }
            }

            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();

                let n = pts.length;
                if (n < 2) return;

                let w = width;
                let h = height;
                let range = (chartRoot.maxV - chartRoot.minV) || 1;
                let textColor = Kirigami.Theme.textColor;
                let bgColor   = Kirigami.Theme.backgroundColor;

                // Un même alpha ne donne pas le même contraste perçu selon que
                // le fond est clair ou sombre (sensibilité au contraste de
                // l'œil + nombreux thèmes clairs avec un fond très lumineux où
                // un trait fin à faible opacité se "noie"). On adapte donc le
                // dosage à la luminosité réelle du fond plutôt que de figer une
                // valeur unique qui ne marche bien que sur un thème sombre.
                let bgLuminance = 0.2126 * bgColor.r + 0.7152 * bgColor.g + 0.0722 * bgColor.b;
                let isLightTheme = bgLuminance > 0.5;

                let axisOpacity  = 0.35;                          // axe X plein + ticks
                let gridOpacity  = isLightTheme ? 0.22 : 0.12;     // grille horizontale en pointillés
                let guideOpacity = isLightTheme ? 0.34 : 0.22;     // ligne verticale du marqueur
                let labelOpacity = 0.80;

                function xAt(i) { return pL + (w - pL - pR) * (i / (n - 1)); }
                function yAt(v) { return pT + (h - pT - pB) * (1 - (v - chartRoot.minV) / range); }

                // --- Courbes Catmull-Rom → Bézier cubiques ---
                // Produit une courbe lisse qui passe exactement par chaque
                // donnée, sans les angles droits visibles des lineTo.
                function buildSmoothPath() {
                    ctx.moveTo(xAt(0), yAt(pts[0]));
                    for (let i = 0; i < n - 1; i++) {
                        let i0 = Math.max(0, i - 1);
                        let i3 = Math.min(n - 1, i + 2);
                        let x0 = xAt(i0), y0 = yAt(pts[i0]);
                        let x1 = xAt(i),   y1 = yAt(pts[i]);
                        let x2 = xAt(i+1), y2 = yAt(pts[i+1]);
                        let x3 = xAt(i3), y3 = yAt(pts[i3]);
                        // Formule standard Catmull-Rom (tension = 1/6)
                        let cp1x = x1 + (x2 - x0) / 6;
                        let cp1y = y1 + (y2 - y0) / 6;
                        let cp2x = x2 - (x3 - x1) / 6;
                        let cp2y = y2 - (y3 - y1) / 6;
                        ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, x2, y2);
                    }
                }

                // --- Grille Y + libellés (lignes fines et discrètes) ---
                function drawYGrid() {
                    let ySteps = 3;
                    for (let s = 0; s <= ySteps; s++) {
                        let v  = chartRoot.minV + (range * s / ySteps);
                        let yy = yAt(v);

                        if (s > 0) {
                            ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, gridOpacity);
                            ctx.lineWidth = 0.9;
                            ctx.beginPath();
                            ctx.setLineDash([2, 4]);
                            ctx.moveTo(pL, yy);
                            ctx.lineTo(w - pR, yy);
                            ctx.stroke();
                            ctx.setLineDash([]);
                        }

                        let labelText = chartRoot.preciseTemp ?
                        parseFloat(v.toFixed(1)).toString() : Math.round(v).toString();
                        let fontSize = Math.round(Kirigami.Units.gridUnit * 0.48);
                        ctx.font = fontSize + "px sans-serif";
                        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, labelOpacity);
                        ctx.textAlign = "right";
                        ctx.textBaseline = "middle";
                        ctx.shadowColor = Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.85);
                        ctx.shadowBlur = 3;
                        ctx.fillText(labelText, pL - 4, yy);
                        ctx.shadowBlur = 0;
                    }
                }

                // --- Axe X + ligne de base ---
                // BUG FIX : avant [0, 6, 12, 18, 24] où "24h" était placé à
                // l'index 23 (= 23h réels), ce qui décalait visuellement tous
                // les repères. Maintenant : [0, 6, 12, 18] — propre, exact.
                function drawXAxis() {
                    let xLabels = [0, 6, 12, 18];
                    let xFontSize = Math.round(Kirigami.Units.gridUnit * 0.45);
                    ctx.font = xFontSize + "px sans-serif";
                    for (let k = 0; k < xLabels.length; k++) {
                        let xi = xLabels[k];
                        let xx = xAt(xi);
                        let lbl = xi + "h";

                        ctx.textAlign = xi === 0 ? "left" : "center";
                        ctx.textBaseline = "top";
                        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, labelOpacity);
                        ctx.shadowColor = Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.85);
                        ctx.shadowBlur = 3;
                        ctx.fillText(lbl, xx, h - pB + 4);
                        ctx.shadowBlur = 0;

                        ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, axisOpacity);
                        ctx.lineWidth = 0.5;
                        ctx.beginPath();
                        ctx.moveTo(xx, h - pB);
                        ctx.lineTo(xx, h - pB + 3);
                        ctx.stroke();
                    }

                    ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, axisOpacity);
                    ctx.lineWidth = 0.5;
                    ctx.setLineDash([]);
                    ctx.beginPath();
                    ctx.moveTo(pL, h - pB);
                    ctx.lineTo(w - pR, h - pB);
                    ctx.stroke();
                }

                // --- Aire sous la courbe (dégradé 3 arrêts, transition douce) ---
                function drawAreaFill(colorStr) {
                    let gradFill = ctx.createLinearGradient(0, pT, 0, h - pB);
                    gradFill.addColorStop(0.0, "rgba(" + colorStr + ", 0.26)");
                    gradFill.addColorStop(0.6, "rgba(" + colorStr + ", 0.07)");
                    gradFill.addColorStop(1.0, "rgba(" + colorStr + ", 0.00)");

                    ctx.beginPath();
                    buildSmoothPath();
                    ctx.lineTo(xAt(n - 1), h - pB);
                    ctx.lineTo(xAt(0), h - pB);
                    ctx.closePath();
                    ctx.fillStyle = gradFill;
                    ctx.fill();
                }

                // --- Trait de la courbe (dégradé vertical selon la palette) ---
                function drawCurveLine(strokeStyle) {
                    ctx.beginPath();
                    buildSmoothPath();
                    ctx.strokeStyle = strokeStyle;
                    ctx.lineWidth = 2.2;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.setLineDash([]);
                    ctx.stroke();
                }

                // --- Marqueur heure courante / survol ---
                function drawMarker(strokeStyle, pointColorStr, curIdx) {
                    let cx = xAt(curIdx);
                    let cy = yAt(pts[curIdx]);

                    // Ligne verticale guide — toujours visible, discrète
                    ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, guideOpacity);
                    ctx.lineWidth = 1.1;
                    ctx.setLineDash([2, 3]);
                    ctx.beginPath();
                    ctx.moveTo(cx, pT);
                    ctx.lineTo(cx, h - pB);
                    ctx.stroke();
                    ctx.setLineDash([]);

                    // Halo du point
                    ctx.fillStyle = strokeStyle;
                    ctx.globalAlpha = 0.20;
                    ctx.beginPath();
                    ctx.arc(cx, cy, 6, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.globalAlpha = 1.0;

                    // Point central
                    ctx.beginPath();
                    ctx.arc(cx, cy, 3, 0, Math.PI * 2);
                    ctx.fill();

                    // Bordure blanche/fond
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 1.0);
                    ctx.stroke();

                    // Valeur textuelle
                    let curVal = chartRoot.preciseTemp
                    ? parseFloat(pts[curIdx].toFixed(1))
                    : Math.round(pts[curIdx]);
                    let textToDraw = curVal.toString();
                    let fontSize = Math.round(Kirigami.Units.gridUnit * 0.55);
                    ctx.font = "bold " + fontSize + "px sans-serif";

                    let alignText = curIdx === 0 ? "left" : (curIdx === n - 1 ? "right" : "center");
                    let isNearTop = cy < pT + 25;
                    ctx.textBaseline = isNearTop ? "top" : "bottom";
                    let yOff = isNearTop ? cy + 12 : cy - 10;

                    ctx.fillStyle = "rgb(" + pointColorStr + ")";
                    ctx.textAlign = alignText;
                    ctx.shadowColor = Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.6);
                    ctx.shadowBlur = 4;
                    ctx.shadowOffsetY = 1;
                    ctx.fillText(textToDraw, cx, yOff);
                    ctx.shadowColor = "transparent";
                    ctx.shadowBlur = 0;
                    ctx.shadowOffsetY = 0;
                }

                // --- Couleur/dégradé "par défaut" si le type de courbe est
                // inconnu (sécurité, ne devrait pas arriver en pratique) ---
                let defaultColorStr = Math.round(chartRoot.lineColor.r * 255) + "," +
                Math.round(chartRoot.lineColor.g * 255) + "," +
                Math.round(chartRoot.lineColor.b * 255);

                let palette = chartRoot.paletteFor(chartRoot.chartType, chartRoot.unit);

                drawYGrid();
                drawXAxis();

                let baseColorStr = palette ? palette.fillColor(chartRoot.maxV) : defaultColorStr;
                drawAreaFill(baseColorStr);

                let strokeStyle;
                if (palette) {
                    strokeStyle = ctx.createLinearGradient(0, yAt(palette.domain.top), 0, yAt(palette.domain.bottom));
                    for (let i = 0; i < palette.stops.length; i++) {
                        strokeStyle.addColorStop(palette.stops[i][0], palette.stops[i][1]);
                    }
                } else {
                    strokeStyle = chartRoot.lineColor;
                }
                drawCurveLine(strokeStyle);

                let curIdx;
                if (chartRoot.hoverIndex !== -1) {
                    curIdx = chartRoot.hoverIndex;
                } else if (chartRoot.isToday) {
                    curIdx = Math.max(0, Math.min(chartRoot.currentHour, n - 1));
                } else {
                    curIdx = -1; // jour passé/futur : pas de marqueur "maintenant"
                }
                if (curIdx !== -1) {
                    let pointColorStr = palette ? palette.fillColor(pts[curIdx]) : defaultColorStr;
                    drawMarker(strokeStyle, pointColorStr, curIdx);
                }
            }

            Component.onCompleted: requestPaint()
        }
    }

    onValuesChanged:      canvas.requestPaint()
    onWidthChanged:       canvas.requestPaint()
    onHeightChanged:      canvas.requestPaint()
    onCurrentHourChanged: canvas.requestPaint()
    onHoverIndexChanged:  canvas.requestPaint()

    // BUG FIX (thème non actualisé) : onPaint lit directement
    // Kirigami.Theme.textColor / backgroundColor à chaque dessin, mais
    // aucun des signaux ci-dessus ne se déclenche quand l'utilisateur change
    // de thème KDE (Plasma) à la volée. Le canvas ne se repeignait alors que
    // par effet de bord, via onHoverIndexChanged déclenché en bougeant la
    // souris. Connections écoute explicitement les couleurs du thème et
    // force un repaint dès qu'elles changent, sans dépendre du hover.
    Connections {
        target: Kirigami.Theme
        function onTextColorChanged() { canvas.requestPaint(); }
        function onBackgroundColorChanged() { canvas.requestPaint(); }
        function onHighlightColorChanged() { canvas.requestPaint(); }
    }
}
