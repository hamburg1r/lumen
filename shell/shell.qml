import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Services.Pipewire
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool connected: false
    property string challengeId: ""
    property string challengePrompt: ""
    property string outgoingSecret: ""
    property bool polkitRegistered: polkit.isRegistered
    property var theme: ({ background: "#202631", surface: "#384252", foreground: "#f4f6fa", muted: "#aeb9c9", accent: "#9de2b1", warning: "#f0acac", radius: 18, pill_radius: 24, spacing: 10, edge: 8, background_opacity: 0.88 })
    property var modules: ({ workspaces: true, network: true, system: true, clock: true, launcher: true, control_center: true })
    property var stats: ({ cpu: 0, ram: 0, temp: null, rx: 0, tx: 0 })
    property var workspaces: []
    property var inputState: ({ caps: null, brightness: null })
    property var notifications: []
    property var sink: Pipewire.defaultAudioSink
    property string popover: ""
    property bool centerOpen: false
    property string osdMessage: ""
    property bool inputInitialized: false
    property bool volumeInitialized: false
    onSinkChanged: volumeInitialized = false
    function toggle(name) { popover = popover === name ? "" : name; centerOpen = false; }
    function bytes(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + "M" : (n / 1024).toFixed(0) + "K"; }
    function displayOsd(message) { osdMessage = message; osdTimer.restart(); }
    function showVolume() {
        if (volumeInitialized && sink && sink.ready && sink.audio)
            displayOsd(sink.audio.muted ? "Volume muted" : "Volume " + Math.round(sink.audio.volume * 100) + "%");
    }
    function showWorkspaces(items) {
        workspaces = items.slice().sort((a, b) => a.output === b.output
            ? a.idx - b.idx : a.output.localeCompare(b.output));
    }
    function openCenter() {
        popover = "";
        if (!centerOpen && launcherAction.running) launcherAction.running = false;
        centerOpen = !centerOpen;
    }

    Process {
        id: configPoll
        command: ["python3", Qt.resolvedUrl("chrome.py").toString().replace("file://", ""), "config"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const data = JSON.parse(this.text); root.theme = data.theme; root.modules = data.modules; }
                catch (e) { console.warn("Invalid shell configuration:", e); }
            }
        }
    }
    Process {
        id: statPoll
        command: ["python3", Qt.resolvedUrl("chrome.py").toString().replace("file://", ""), "stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.stats = JSON.parse(this.text);
                } catch (e) { console.warn("Invalid shell snapshot:", e); }
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: if (!statPoll.running) statPoll.running = true }
    Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: if (!configPoll.running) configPoll.running = true }
    Timer { id: osdTimer; interval: 1800; onTriggered: root.osdMessage = "" }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Process { id: workspaceAction }
    Process { id: launcherAction; command: ["fuzzel"]; }
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    Connections {
        target: root.sink && root.sink.ready ? root.sink.audio : null
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged() { root.showVolume(); }
    }
    // Let the sink finish binding before treating changes as user-initiated.
    Timer {
        interval: 250
        running: !root.volumeInitialized && root.sink && root.sink.ready && root.sink.audio !== null
        onTriggered: root.volumeInitialized = true
    }
    Process {
        id: niriEvents
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        onRunningChanged: if (!running) niriReconnect.restart()
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data);
                    if (event.WorkspacesChanged) root.showWorkspaces(event.WorkspacesChanged.workspaces);
                    else if (event.WorkspaceActivated) {
                        const change = event.WorkspaceActivated;
                        const target = root.workspaces.find(w => w.id === change.id);
                        if (!target) return;
                        root.showWorkspaces(root.workspaces.map(w => w.id === change.id
                            ? Object.assign({}, w, { is_active: true })
                            : (w.output === target.output ? Object.assign({}, w, { is_active: false }) : w)));
                    } else if (event.WorkspaceActiveWindowChanged) {
                        const change = event.WorkspaceActiveWindowChanged;
                        root.showWorkspaces(root.workspaces.map(w => w.id === change.workspace_id
                            ? Object.assign({}, w, { active_window_id: change.active_window_id }) : w));
                    }
                } catch (e) { console.warn("Invalid niri event:", e); }
            }
        }
    }
    Timer { id: niriReconnect; interval: 1000; onTriggered: if (!niriEvents.running) niriEvents.running = true }
    Process {
        id: inputEvents
        command: ["python3", Qt.resolvedUrl("chrome.py").toString().replace("file://", ""), "watch-input"]
        running: true
        onRunningChanged: if (!running) inputReconnect.restart()
        stdout: SplitParser {
            onRead: data => {
                try {
                    const next = JSON.parse(data);
                    if (root.inputInitialized && next.caps !== null && root.inputState.caps !== null && next.caps !== root.inputState.caps)
                        root.displayOsd(next.caps ? "Caps Lock on" : "Caps Lock off");
                    if (root.inputInitialized && next.brightness !== null && root.inputState.brightness !== null && next.brightness !== root.inputState.brightness)
                        root.displayOsd("Brightness " + next.brightness + "%");
                    root.inputState = next;
                    root.inputInitialized = true;
                } catch (e) { console.warn("Invalid input event:", e); }
            }
        }
    }
    Timer { id: inputReconnect; interval: 1000; onTriggered: if (!inputEvents.running) inputEvents.running = true }
    Process {
        id: historyPoll
        command: ["python3", Qt.resolvedUrl("chrome.py").toString().replace("file://", ""), "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.notifications = JSON.parse(this.text); }
                catch (e) { console.warn("Invalid notification history:", e); }
            }
        }
    }
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: if (!historyPoll.running) historyPoll.running = true }
    Process {
        id: notificationDismiss
        onExited: if (!historyPoll.running) historyPoll.running = true
    }
    Process {
        id: notificationAction
        onExited: if (!historyPoll.running) historyPoll.running = true
    }

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
        function volume(): string {
            if (!root.sink || !root.sink.ready || !root.sink.audio) return "unavailable";
            return (root.volumeInitialized ? "ready " : "initializing ")
                + Math.round(root.sink.audio.volume * 100) + "%";
        }
        function osd(): string { return root.osdMessage || "hidden"; }
        function caps(): string { return root.inputState.caps === null ? "unavailable" : String(root.inputState.caps); }
        function notifications(): string { return String(root.notifications.length); }
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
        color: root.theme.background
        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            Text { text: root.challengePrompt; color: root.theme.foreground; wrapMode: Text.Wrap }
            Rectangle {
                width: parent.width
                height: 36
                color: root.theme.surface
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: 8
                    color: root.theme.foreground
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
        color: root.theme.background

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.message : ""
                color: root.theme.foreground
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.actionId : ""
                color: root.theme.muted
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
                color: root.theme.foreground
                wrapMode: Text.Wrap
            }
            Rectangle {
                width: parent.width
                height: 36
                visible: polkit.flow && polkit.flow.isResponseRequired
                color: root.theme.surface
                TextInput {
                    id: polkitPassword
                    anchors.fill: parent
                    anchors.margins: 8
                    color: root.theme.foreground
                    echoMode: polkit.flow && polkit.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    onAccepted: polkitSubmit.clicked()
                }
            }
            Text {
                width: parent.width
                text: polkit.flow ? polkit.flow.supplementaryMessage : ""
                color: polkit.flow && polkit.flow.supplementaryIsError ? root.theme.warning : root.theme.muted
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
        id: bar
        WlrLayershell.namespace: "lumen:bar"
        anchors { top: true; left: true; right: true }
        implicitHeight: 56
        color: "transparent"
        Item {
            // A single surface includes the edge padding and the bar: no seam between them.
            anchors.fill: parent
            Shape {
                id: barBackground
                anchors.fill: parent
                property color baseColor: root.theme.background
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Qt.rgba(barBackground.baseColor.r, barBackground.baseColor.g,
                                       barBackground.baseColor.b, root.theme.background_opacity)
                    startX: 0; startY: 0
                    PathLine { x: bar.width; y: 0 }
                    PathLine { x: bar.width; y: bar.height - root.theme.radius }
                    PathQuad { x: bar.width - root.theme.radius; y: bar.height; controlX: bar.width; controlY: bar.height }
                    PathLine { x: root.theme.radius; y: bar.height }
                    PathQuad { x: 0; y: bar.height - root.theme.radius; controlX: 0; controlY: bar.height }
                    PathLine { x: 0; y: 0 }
                }
            }
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: root.theme.edge + 12 }
                spacing: root.theme.spacing
                Rectangle {
                    width: 42; height: 34; radius: root.theme.pill_radius
                    color: root.theme.surface; visible: root.modules.launcher
                    Text { anchors.centerIn: parent; text: "◇"; color: root.theme.accent; font.pixelSize: 22 }
                    MouseArea { anchors.fill: parent; onClicked: {
                        root.popover = "";
                        root.centerOpen = false;
                        if (!launcherAction.running) launcherAction.running = true;
                    } }
                }
                Rectangle {
                    width: 22; height: 34; radius: root.theme.pill_radius
                    color: root.theme.surface
                    Text { anchors.centerIn: parent; text: root.connected ? "●" : "○"; color: root.connected ? root.theme.accent : root.theme.warning }
                }
                Repeater {
                    model: root.modules.workspaces ? root.workspaces : []
                    Rectangle {
                        required property var modelData
                        width: modelData.is_active ? 52 : 34; height: 34
                        radius: root.theme.pill_radius
                        color: modelData.is_active ? root.theme.accent : root.theme.surface
                        Text { anchors.centerIn: parent; text: modelData.name || String(modelData.idx); color: modelData.is_active ? root.theme.background : root.theme.foreground }
                        MouseArea { anchors.fill: parent; onClicked: {
                            root.popover = "";
                            if (!workspaceAction.running) {
                                workspaceAction.command = ["niri", "msg", "action", "focus-workspace", modelData.name || String(modelData.idx)];
                                workspaceAction.running = true;
                            }
                        } }
                    }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: root.theme.edge + 12 }
                spacing: root.theme.spacing
                Rectangle {
                    visible: root.modules.network; width: 115; height: 34; radius: root.theme.pill_radius; color: root.theme.surface
                    Text { anchors.centerIn: parent; text: "↓" + root.bytes(root.stats.rx) + " ↑" + root.bytes(root.stats.tx); color: root.theme.foreground; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: root.toggle("network") }
                }
                Rectangle {
                    visible: root.modules.system; width: 105; height: 34; radius: root.theme.pill_radius; color: root.theme.surface
                    Text { anchors.centerIn: parent; text: "CPU " + root.stats.cpu + "%"; color: root.theme.foreground }
                    MouseArea { anchors.fill: parent; onClicked: root.toggle("system") }
                }
                Rectangle {
                    visible: root.modules.clock; width: 60; height: 34; radius: root.theme.pill_radius; color: root.theme.surface
                    Text { anchors.centerIn: parent; text: Qt.formatTime(clock.date, "hh:mm"); color: root.theme.foreground }
                    MouseArea { anchors.fill: parent; onClicked: root.popover = "" }
                }
                Rectangle {
                    visible: root.modules.control_center; width: 42; height: 34; radius: root.theme.pill_radius; color: root.theme.surface
                    Text { anchors.centerIn: parent; text: "☷"; color: root.theme.accent }
                    MouseArea { anchors.fill: parent; onClicked: root.openCenter() }
                }
            }
        }
    }

    PanelWindow {
        // Cover the desktop below the bar while open, so any outside click dismisses it.
        WlrLayershell.namespace: "lumen:popup"
        visible: root.popover !== "" || root.centerOpen
        anchors { top: true; bottom: true; left: true; right: true }
        margins { top: 56 }
        // The bar reserves 56px. Ignore that exclusion before applying our
        // 56px margin, otherwise the popover starts 56px too low.
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: { root.popover = ""; root.centerOpen = false; }
        }
        Rectangle {
            anchors { top: parent.top; right: parent.right; rightMargin: root.theme.edge }
            width: 320; height: root.centerOpen ? 440 : 160
            property color baseColor: root.theme.background
            color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, root.theme.background_opacity)
            radius: root.theme.radius
            // A Rectangle is visual only: without its own MouseArea, clicks
            // inside it bubble to the full-screen outside-click dismiss area.
            MouseArea { anchors.fill: parent; onClicked: {} }
            Column {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                Text { text: root.centerOpen ? "Control Center" : root.popover === "network" ? "Network throughput" : "System stats"; color: root.theme.foreground; font.bold: true }
                Text { visible: root.centerOpen; text: root.inputState.caps === null ? "Caps Lock  unavailable" : root.inputState.caps ? "Caps Lock  ON" : "Caps Lock  off"; color: root.inputState.caps ? root.theme.accent : root.theme.muted }
                Rectangle {
                    visible: root.centerOpen; width: 155; height: 34; radius: root.theme.pill_radius; color: root.theme.surface
                    Text { anchors.centerIn: parent; text: root.sink && root.sink.audio && root.sink.audio.muted ? "Unmute" : "Mute"; color: root.theme.foreground }
                    MouseArea { anchors.fill: parent; onClicked: if (root.sink && root.sink.ready && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted }
                }
                Text { visible: root.centerOpen; text: "Volume: " + (root.sink && root.sink.ready && root.sink.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "n/a") + "   Brightness: " + (root.inputState.brightness === null ? "n/a" : root.inputState.brightness + "%"); color: root.theme.foreground; font.pixelSize: 12 }
                Text { visible: root.centerOpen; text: "Notifications"; color: root.theme.foreground; font.bold: true }
                Text { visible: root.centerOpen && root.notifications.length === 0; text: "No notifications"; color: root.theme.muted }
                ScrollView {
                    visible: root.centerOpen && root.notifications.length > 0
                    width: parent.width; height: 225
                    clip: true
                    Column {
                        width: 280; spacing: 8
                        Repeater {
                            model: root.notifications
                            Rectangle {
                                id: notificationCard
                                required property var modelData
                                width: 280
                                height: Math.max(70, notificationText.implicitHeight + 20)
                                    + (modelData.actions && modelData.actions.length ? 36 : 0)
                                radius: root.theme.radius; color: root.theme.surface
                                Text {
                                    id: notificationText
                                    anchors { left: parent.left; right: dismissButton.left; top: parent.top; margins: 10 }
                                    text: modelData.app + " · " + modelData.summary + (modelData.body ? "\n" + modelData.body : "")
                                    color: root.theme.foreground; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                                    font.pixelSize: 12
                                }
                                Rectangle {
                                    id: dismissButton
                                    anchors { top: parent.top; right: parent.right; margins: 8 }
                                    width: 28; height: 28; radius: 14; color: root.theme.background
                                    Text { anchors.centerIn: parent; text: "×"; color: root.theme.foreground }
                                    MouseArea { anchors.fill: parent; onClicked: {
                                        if (notificationDismiss.running) return;
                                        notificationDismiss.command = ["python3", Qt.resolvedUrl("chrome.py").toString().replace("file://", ""), "dismiss", String(modelData.id)];
                                        notificationDismiss.running = true;
                                    } }
                                }
                                Row {
                                    anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                                    spacing: 8
                                    Repeater {
                                        model: modelData.actions || []
                                        Rectangle {
                                            required property var modelData
                                            width: Math.min(110, actionLabel.implicitWidth + 16)
                                            height: 28; radius: root.theme.pill_radius; color: root.theme.background
                                            Text { id: actionLabel; anchors.centerIn: parent; text: modelData.label; color: root.theme.accent; font.pixelSize: 12; elide: Text.ElideRight; width: Math.min(94, implicitWidth) }
                                            MouseArea { anchors.fill: parent; onClicked: {
                                                if (notificationAction.running) return;
                                                notificationAction.command = ["python3", Qt.resolvedUrl("chrome.py").toString().replace("file://", ""), "action", String(notificationCard.modelData.id), modelData.key];
                                                notificationAction.running = true;
                                            } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Text { visible: !root.centerOpen && root.popover === "network"; text: "Download " + root.bytes(root.stats.rx) + "/s\nUpload " + root.bytes(root.stats.tx) + "/s"; color: root.theme.foreground }
                Text { visible: !root.centerOpen && root.popover === "system"; text: "CPU " + root.stats.cpu + "%   RAM " + root.stats.ram + "%\nTemperature " + (root.stats.temp === null ? "unavailable" : root.stats.temp + "°C"); color: root.theme.foreground }
                Rectangle {
                    width: 70; height: 32; radius: root.theme.pill_radius; color: root.theme.surface
                    Text { anchors.centerIn: parent; text: "Close"; color: root.theme.foreground }
                    MouseArea { anchors.fill: parent; onClicked: { root.popover = ""; root.centerOpen = false; } }
                }
            }
        }
    }
    PanelWindow {
        WlrLayershell.namespace: "lumen:osd"
        visible: root.osdMessage !== ""
        anchors { bottom: true; left: true; right: true }
        margins { bottom: 32 }
        implicitHeight: 48; exclusiveZone: 0; color: "transparent"
        Rectangle {
            anchors.centerIn: parent; width: 200; height: 44
            property color baseColor: root.theme.background
            radius: root.theme.pill_radius
            color: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, root.theme.background_opacity)
            Text { anchors.centerIn: parent; text: root.osdMessage; color: root.theme.foreground }
        }
    }
}
