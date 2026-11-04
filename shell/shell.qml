import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

ShellRoot {
    id: root
    property bool connected: false
    property string challengeId: ""
    property string challengePrompt: ""
    property string outgoingSecret: ""
    property bool polkitRegistered: polkit.isRegistered

    // Registration is scoped by Quickshell to this process's logind session.
    // Polkit validates responses through its own PAM conversation, not the sudo broker.
    PolkitAgent {
        id: polkit
        onAuthenticationRequestStarted: polkitPassword.forceActiveFocus()
        onFlowChanged: polkitPassword.text = ""
    }

    Connections {
        target: polkit.flow
        function onIsResponseRequiredChanged() {
            polkitPassword.text = "";
            if (polkit.flow && polkit.flow.isResponseRequired)
                polkitPassword.forceActiveFocus();
        }
        function onAuthenticationFailed() { polkitPassword.text = ""; }
    }

    // Expose the same state as the label for a smoke test without screen scraping.
    IpcHandler {
        target: "status"
        function connection(): string {
            return root.connected ? "connected" : "disconnected";
        }
        function polkit(): string {
            return root.polkitRegistered ? "registered" : "unregistered";
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

    FloatingWindow {
        id: polkitWindow
        visible: polkit.flow !== null && !polkit.flow.isCompleted
        title: "Lumen PolicyKit authentication"
        implicitWidth: 440
        implicitHeight: 300
        color: "#202631"

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.message : ""
                color: "white"
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.actionId : ""
                color: "#aeb9c9"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            ComboBox {
                id: polkitIdentity
                width: parent.width
                visible: polkit.flow && polkit.flow.identities.length > 1
                model: polkit.flow ? polkit.flow.identities : []
                textRole: "displayName"
                onActivated: index => {
                    if (polkit.flow) polkit.flow.selectedIdentity = polkit.flow.identities[index];
                    polkitPassword.text = "";
                }
            }
            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.inputPrompt : ""
                color: "white"
                wrapMode: Text.Wrap
            }
            Rectangle {
                width: parent.width
                height: 36
                visible: polkit.flow && polkit.flow.isResponseRequired
                color: "#384252"
                TextInput {
                    id: polkitPassword
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "white"
                    echoMode: polkit.flow && polkit.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    onAccepted: polkitSubmit.clicked()
                }
            }
            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.supplementaryMessage : ""
                color: polkit.flow && polkit.flow.supplementaryIsError ? "#f0acac" : "#aeb9c9"
                wrapMode: Text.Wrap
            }
            Row {
                spacing: 16
                Button {
                    id: polkitSubmit
                    text: "Submit"
                    enabled: polkit.flow && polkit.flow.isResponseRequired
                    onClicked: {
                        const flow = polkit.flow;
                        if (!flow || !flow.isResponseRequired) return;
                        const response = polkitPassword.text;
                        polkitPassword.text = "";
                        flow.submit(response);
                    }
                }
                Button {
                    text: "Cancel"
                    onClicked: {
                        polkitPassword.text = "";
                        if (polkit.flow) polkit.flow.cancelAuthenticationRequest();
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
