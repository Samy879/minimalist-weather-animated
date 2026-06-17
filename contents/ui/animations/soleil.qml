import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: sunRoot
    anchors.fill: parent

    // --- COULEURS ADOUCIES ---
    // Le blanc pur ("#FFFFFF") est ce qui rendait le soleil éblouissant :
    // combiné au flou et aux pics d'opacité, il créait un effet de
    // "surexposition" façon flash photo. On le remplace partout par des
    // tons ivoire/crème chauds mais jamais blancs purs, qui restent
    // lumineux sans agresser l'œil.
    readonly property color sunColor: "#FFE9A8"  // Jaune pastel chaud
    readonly property color rayColor: "#FFF6DC"  // Ivoire doux (plus de blanc pur)
    readonly property color coreColor: "#FFF3D0" // Crème très clair (centre, non blanc)

    Item {
        id: sunPositioner
        // --- POSITION AJUSTÉE ICI ---
        // Plus à droite (88%) et plus haut (12%)
        x: parent.width * 0.88
        y: parent.height * 0.12

        // --- 1. HALO GLOBAL (Plus transparent et resserré) ---
        RadialGradient {
            anchors.centerIn: parent
            width: 700
            height: 700
            opacity: 0.06 // Légèrement réduit (était 0.08)
            gradient: Gradient {
                GradientStop { position: 0.0; color: sunColor }
                GradientStop { position: 0.3; color: "transparent" } // S'estompe plus vite
            }
        }

        // --- 2. LES FAISCEAUX (Oscillants et doux) ---
        Item {
            id: raysContainer
            anchors.centerIn: parent
            width: Math.max(sunRoot.width, sunRoot.height) * 3
            height: width

            Repeater {
                model: 12
                delegate: Rectangle {
                    anchors.centerIn: parent

                    width: raysContainer.width * (index % 3 === 0 ? 0.8 : 0.6)
                    height: index % 2 === 0 ? 8 : 3
                    // Opacité réduite (était 0.12 / 0.06) : des faisceaux qui
                    // se devinent plutôt que des traits qui sautent aux yeux.
                    opacity: index % 2 === 0 ? 0.08 : 0.04

                    // On sauvegarde l'angle de base pour l'animation d'oscillation
                    property real baseAngle: index * (360 / 12) + (index * 8)
                    rotation: baseAngle

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.4; color: rayColor }
                        GradientStop { position: 0.5; color: sunColor }
                        GradientStop { position: 0.6; color: rayColor }
                        GradientStop { position: 1.0; color: "transparent" }
                    }

                    // --- ANIMATION D'OSCILLATION (Légèrement accélérée) ---
                    SequentialAnimation on rotation {
                        loops: Animation.Infinite

                        // Mouvement fluide vers l'avant
                        NumberAnimation {
                            from: baseAngle
                            to: baseAngle + 20
                            // Durée réduite (de 80000 à 55000) pour plus de dynamisme
                            duration: 40000 + (index * 2000)
                            easing.type: Easing.InOutSine
                        }
                        // Retour en arrière fluide
                        NumberAnimation {
                            from: baseAngle + 20
                            to: baseAngle - 10
                            // Durée réduite (de 90000 à 65000)
                            duration: 45000 + (index * 2000)
                            easing.type: Easing.InOutSine
                        }
                        // Retour à la position de base
                        NumberAnimation {
                            from: baseAngle - 10
                            to: baseAngle
                            // Durée réduite (de 70000 à 45000)
                            duration: 45000 + (index * 2000)
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 12
                samples: 24
            }

            // Pulsation resserrée (était 0.7 → 1.0) : on ne monte plus
            // jusqu'au pic de luminosité, on reste dans une plage plus douce.
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 0.55; to: 0.80; duration: 6000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.80; to: 0.55; duration: 6000; easing.type: Easing.InOutSine }
            }
        }

        // --- 3. LE CŒUR DU SOLEIL (Sans blanc pur ni orange saturé) ---
        Item {
            anchors.centerIn: parent
            width: 200
            height: 200

            Rectangle {
                id: sunCore
                anchors.centerIn: parent
                // Légèrement plus petit (était 0.12) : un point lumineux,
                // pas un disque qui domine le coin de l'écran.
                width: Math.min(sunRoot.width, sunRoot.height) * 0.10
                height: width
                radius: width / 2

                // Dégradé pastel : plus aucun blanc pur, on part d'un crème
                // clair et on termine sur un jaune doré chaleureux.
                gradient: Gradient {
                    GradientStop { position: 0.0; color: coreColor }
                    GradientStop { position: 0.6; color: "#FFE9A8" } // Jaune pastel chaud
                    GradientStop { position: 1.0; color: "#F7C75C" } // Jaune doré, non agressif
                }
            }

            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 5
                samples: 16
            }
        }
    }
}
