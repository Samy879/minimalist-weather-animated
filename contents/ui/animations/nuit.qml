import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: nightRoot
    anchors.fill: parent
    clip: true

    // Palette de teintes rares pour les étoiles : on reste sur des tons
    // pastel/doux, jamais saturés, pour ne pas trahir l'esprit discret du
    // ciel nocturne d'origine. La grande majorité des étoiles restent
    // neutres (textColor) ; ces couleurs ne touchent qu'une minorité.
    readonly property var tintPalette: ["#FF8A80", "#82B1FF", "#FFE082"] // rouge doux, bleu doux, jaune doux

    function randomTint() {
        return tintPalette[Math.floor(Math.random() * tintPalette.length)];
    }

    // Palette plus large pour les étoiles filantes : chacune a sa propre
    // couleur, tirée au hasard à chaque apparition, pour que deux étoiles
    // filantes successives ne se ressemblent pas forcément.
    readonly property var shootingStarPalette: ["#FF8A80", "#82B1FF", "#B39DDB", "#FFE082", "#80D8C3"] // rouge, bleu, violet, jaune, vert d'eau

    function randomShootingColor() {
        return shootingStarPalette[Math.floor(Math.random() * shootingStarPalette.length)];
    }

    // --- LUNE ---
    // Même emplacement que le soleil (haut-droite), pour que les deux
    // astres se substituent naturellement l'un à l'autre selon le moment
    // de la journée. Forme en croissant (deux cercles superposés) plutôt
    // qu'un disque plein, pour rester identifiable comme lune au premier
    // coup d'œil et se distinguer clairement du soleil.
    Item {
        id: moonRoot
        x: parent.width * 0.88
        y: parent.height * 0.12

        readonly property color moonColor: "#E8EDF5" // blanc-bleuté très doux, pas de blanc pur
        readonly property color haloColor: "#C9D6EA"

        // Halo très discret : la nuit doit rester sombre, pas illuminée.
        // Réduit en deux passes (260→130→90px, opacité max 0.14→0.06) :
        // l'ancien halo éclaircissait toute la zone autour de la lune, ce
        // qui écrasait le contraste des étoiles voisines et donnait
        // l'impression d'un ciel "lavé" plutôt que sombre.
        RadialGradient {
            anchors.centerIn: parent
            width: 90
            height: 90
            opacity: 0.04
            gradient: Gradient {
                GradientStop { position: 0.0; color: moonRoot.haloColor }
                GradientStop { position: 0.4; color: "transparent" }
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.06; duration: 7000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.03; duration: 7000; easing.type: Easing.InOutSine }
            }
        }

        Item {
            id: moonDisc
            anchors.centerIn: parent
            width: 22
            height: 22

            Rectangle {
                id: moonBase
                anchors.fill: parent
                radius: width / 2
                color: moonRoot.moonColor
            }

            // Le "mordant" du croissant : un cercle de la couleur de fond,
            // décalé, qui mange une partie du disque lunaire. Comme on ne
            // connaît pas la couleur de fond exacte du plasmoïde, on simule
            // l'ombre avec une opacité réduite plutôt qu'une vraie
            // composition, ce qui reste correct visuellement sans dépendre
            // du thème pour la couleur de fond.
            Rectangle {
                width: parent.width
                height: parent.height
                radius: width / 2
                x: parent.width * 0.30
                y: -parent.height * 0.08
                color: Kirigami.Theme.backgroundColor
                opacity: 0.92
            }

            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 2
                samples: 8
            }
        }
    }

    // 1. Étoiles classiques (45, comme à l'origine) — quasi toutes neutres,
    // une poignée seulement (~1 sur 15) reçoit une teinte rouge/bleu/jaune
    // douce.
    //
    // RESPIRATION RALENTIE : le cycle d'origine (4-10s par cycle complet,
    // toutes les étoiles tournant en continu) faisait qu'avec 45 étoiles
    // indépendantes, il y en avait statistiquement toujours plusieurs en
    // train de monter/descendre à la fois — ça lisait comme un
    // scintillement nerveux plutôt qu'une respiration. On revient à un
    // rythme lent et profond (8-16s par moitié de cycle) avec une pause
    // aléatoire entre deux respirations, qui désynchronise les étoiles
    // entre elles et laisse de vrais moments de calme dans le ciel.
    Repeater {
        model: 45
        delegate: Rectangle {
            x: Math.random() * parent.width; y: Math.random() * parent.height
            width: 1.1; height: 1.1; radius: 0.5
            readonly property bool tinted: Math.random() < 0.07
            color: tinted ? nightRoot.randomTint() : Kirigami.Theme.textColor
            opacity: 0.1
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: Math.random() * 4000 }
                NumberAnimation { to: tinted ? 0.45 : 0.55; duration: 8000 + Math.random() * 8000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.08; duration: 8000 + Math.random() * 8000; easing.type: Easing.InOutSine }
            }
        }
    }

    // 2. Étoiles profondes (8) — halo + point, inchangées dans leur
    // mécanique, toujours neutres : ce sont des points d'ancrage discrets,
    // pas l'endroit où on veut attirer l'œil avec de la couleur.
    Repeater {
        model: 8
        delegate: Item {
            x: Math.random() * parent.width; y: Math.random() * parent.height
            width: 25; height: 25
            RadialGradient {
                anchors.fill: parent
                opacity: 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Kirigami.Theme.textColor }
                    GradientStop { position: 0.3; color: "transparent" }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    PauseAnimation { duration: Math.random() * 8000 }
                    NumberAnimation { to: 0.5; duration: 1200; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InOutQuad }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1.5; height: 1.5; radius: 0.7
                color: Kirigami.Theme.textColor
            }
        }
    }

    // --- ÉTOILE FILANTE ---
    // Un trait lumineux qui traverse l'écran, occasionnellement et au
    // hasard. Plutôt qu'un Repeater fixe (qui afficherait toujours le
    // même nombre d'étoiles filantes en boucle), on utilise un Timer dont le
    // délai change à chaque déclenchement et qui crée un objet éphémère :
    // la plupart du temps il n'y a tout simplement rien à l'écran, ce qui
    // correspond à l'effet "parfois" demandé plutôt qu'à un cycle régulier.
    Component {
        id: shootingStarComponent
        Item {
            id: star

            // Direction libre mais jamais ascendante : une étoile filante
            // ne remonte pas vers le haut. Avec cette convention (0° = vers
            // la droite, sens horaire car l'axe Y pointe vers le bas en
            // QML), l'intervalle [0°, 180°] couvre exactement tout ce qui
            // va horizontalement ou vers le bas — droite, bas-droite, bas,
            // bas-gauche, gauche — en excluant toute composante vers le
            // haut. Longueur variable (15% à 45% de la diagonale de
            // l'écran).
            property real travelLength: Math.sqrt(nightRoot.width * nightRoot.width + nightRoot.height * nightRoot.height) * (0.15 + Math.random() * 0.30)
            property real travelAngle: Math.random() * 180 // degrés, 0 = droite, 90 = bas, 180 = gauche
            property real dx: travelLength * Math.cos(travelAngle * Math.PI / 180)
            property real dy: travelLength * Math.sin(travelAngle * Math.PI / 180)

            // Point de départ choisi pour que toute la trajectoire reste
            // visible. La marge en bas doit couvrir la composante verticale
            // du trajet (puisque l'étoile ne va jamais vers le haut, c'est
            // la seule direction qui peut faire sortir du cadre par le
            // bas) ; en haut, aucune marge n'est nécessaire puisque le
            // mouvement ne remonte jamais.
            property real marginX: Math.max(travelLength, 40)
            property real marginBottom: Math.max(Math.abs(dy), 20)
            property real startX: marginX + Math.random() * Math.max(1, nightRoot.width - 2 * marginX)
            property real startY: Math.random() * Math.max(1, nightRoot.height - marginBottom)

            property color trailColor: nightRoot.randomShootingColor()
            // Longueur visuelle du trait proportionnelle au trajet parcouru
            // (un trajet plus long = un trait plus long), dans des bornes
            // raisonnables pour rester lisible à toutes les échelles.
            property real trailLength: Math.max(35, Math.min(110, travelLength * 0.22))

            x: startX
            y: startY
            rotation: travelAngle
            opacity: 0

            Rectangle {
                width: star.trailLength
                height: 1.6
                radius: 0.8
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: star.trailColor }
                }
            }

            // Durée proportionnelle à la distance parcourue, pour garder
            // une vitesse de défilement à peu près constante : sans ça,
            // un trajet long irait visiblement plus vite qu'un court avec
            // la même durée fixe, ce qui casserait l'illusion.
            property int travelDuration: Math.round(550 + travelLength * 0.9)

            SequentialAnimation {
                running: true
                ParallelAnimation {
                    NumberAnimation { target: star; property: "opacity"; from: 0; to: 0.85; duration: 120 }
                    NumberAnimation { target: star; property: "x"; from: star.startX; to: star.startX + star.dx; duration: star.travelDuration; easing.type: Easing.OutQuad }
                    NumberAnimation { target: star; property: "y"; from: star.startY; to: star.startY + star.dy; duration: star.travelDuration; easing.type: Easing.OutQuad }
                }
                NumberAnimation { target: star; property: "opacity"; to: 0; duration: 250 }
                ScriptAction { script: star.destroy() }
            }
        }
    }

    Timer {
        id: shootingStarTimer
        running: true
        repeat: true
        // Premier passage assez tôt pour ne pas attendre longtemps à
        // l'ouverture, puis un délai aléatoire entre ~8s et ~30s ensuite :
        // assez espacé pour rester un événement rare et remarqué, jamais
        // un effet répétitif.
        interval: 5000 + Math.random() * 5000
        onTriggered: {
            shootingStarComponent.createObject(nightRoot);
            interval = 8000 + Math.random() * 22000;
        }
    }
}
