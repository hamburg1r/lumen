import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool connected: false
    property string challengeId: ""
    property string challengePrompt: ""
    property string outgoingSecret: ""

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

    // The helper keeps secrets off argv and environment. Heartbeats only while this shell is running.
    Process {
        id: authPoll
        command: ["lumen-auth-gui", "next"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse(this.text);
                    root.challengeId = reply.id;
                    root.challengePrompt = reply.prompt;
                    if (!reply.id) password.text = "";
                } catch (e) { root.challengeId = ""; }
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!authPoll.running) authPoll.running = true
    }
    Process {
        id: authSubmit
        stdinEnabled: true
        onStarted: {
            write(root.outgoingSecret + "\n");
            root.outgoingSecret = "";
        }
    }
    Process { id: authDeny }

    FloatingWindow {
        id: authWindow
        visible: root.challengeId !== ""
        title: "Lumen authentication"
        implicitWidth: 420
        implicitHeight: 180
        color: "#202631"
        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            Text { text: root.challengePrompt; color: "white"; wrapMode: Text.Wrap }
            Rectangle {
                width: parent.width
                height: 36
                color: "#384252"
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "white"
                    echoMode: TextInput.Password
                    onAccepted: submitButton.clicked()
                }
            }
            Row {
                spacing: 16
                Button {
                    id: submitButton
                    text: "Submit"
                    onClicked: {
                        if (!root.challengeId || !password.text || authSubmit.running) return;
                        root.outgoingSecret = password.text;
                        password.text = "";
                        authSubmit.command = ["lumen-auth-gui", "submit", root.challengeId];
                        authSubmit.running = true;
                    }
                }
                Button {
                    text: "Deny"
                    onClicked: {
                        if (!root.challengeId || authDeny.running) return;
                        authDeny.command = ["lumen-auth-gui", "deny", root.challengeId];
                        authDeny.running = true;
                    }
                }
            }
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
