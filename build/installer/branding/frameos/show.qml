import QtQuick
Rectangle {
    id: root
    color: "#191b21"
    function onActivate() { motion.start() }
    function onLeave() { motion.stop() }
    Rectangle {
        id: ring
        width: 126; height: 126; radius: 32
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -50
        color: "#303b52"
        Rectangle { anchors.centerIn: parent; width: 74; height: 74; radius: 20; border.width: 4; border.color: "#a3b9f5"; color: "transparent" }
        SequentialAnimation on opacity {
            id: motion; running: false; loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 1100; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutQuad }
        }
    }
    Text { anchors.top: ring.bottom; anchors.topMargin: 30; anchors.horizontalCenter: parent.horizontalCenter; text: "Installing FrameOS"; color: "#edf0f7"; font.pixelSize: 26 }
}
