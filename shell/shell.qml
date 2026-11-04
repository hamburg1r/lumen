import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool connected: false

    // Expose the same state as the label for a smoke test without screen scraping.
    IpcHandler {
        target: "status"
        function connection(): string {
            return root.connected ? "connected" : "disconnected";
        }
    }

    // A successful method call (not merely an owned bus name) proves the daemon is responsive.
    Process {
        id: ping
        command: ["busctl", "--user", "--timeout=1", "call", "org.lumen", "/org/lumen", "org.lumen.Daemon", "Ping"]
        onExited: (exitCode, exitStatus) => root.connected = exitCode === 0
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!ping.running)
                ping.running = true;
        }
    }

    PanelWindow {
        anchors {
            top: true
            left: true
        }
        implicitWidth: 220
        implicitHeight: 36
        color: "#202631"

        Text {
            anchors.centerIn: parent
            text: root.connected ? "● Lumen connected" : "○ Lumen disconnected"
            color: root.connected ? "#9de2b1" : "#f0acac"
            font.pixelSize: 14
        }
    }
}
