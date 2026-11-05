#!/usr/bin/env python3
"""Small read-only snapshot adapter for the shell; all output is JSON."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib


DEFAULT_THEME = {
    "background": "#202631", "surface": "#384252", "foreground": "#f4f6fa",
    "muted": "#aeb9c9", "accent": "#9de2b1", "warning": "#f0acac",
    "radius": 18, "pill_radius": 24, "spacing": 10, "edge": 8,
    "background_opacity": 0.88,
}
DEFAULT_MODULES = {"workspaces": True, "network": True, "system": True,
                   "clock": True, "launcher": True, "control_center": True}


def config():
    directory = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "lumen"
    theme = DEFAULT_THEME.copy()
    modules = DEFAULT_MODULES.copy()
    for name, destination, section in (("theme.toml", theme, "theme"),
                                       ("shell.toml", modules, "modules")):
        try:
            data = tomllib.loads((directory / name).read_text()).get(section, {})
            for key, old in destination.items():
                value = data.get(key)
                if type(value) is type(old) and (key != "background_opacity" or 0 <= value <= 1):
                    destination[key] = value
        except (OSError, ValueError):
            pass
    return {"theme": theme, "modules": modules}


def read(path):
    try:
        return Path(path).read_text()
    except OSError:
        return ""


def snapshot():
    result = {"cpu": 0, "ram": 0, "temp": None, "rx": 0, "tx": 0}
    mem = dict(line.split(":", 1) for line in read("/proc/meminfo").splitlines() if ":" in line)
    try:
        total = int(mem["MemTotal"].split()[0])
        result["ram"] = round(100 * (1 - int(mem["MemAvailable"].split()[0]) / total))
    except (KeyError, ValueError, ZeroDivisionError):
        pass
    for path in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
        try:
            value = int(read(path)) / 1000
            if 0 < value < 120:
                result["temp"] = round(value)
                break
        except ValueError:
            pass
    # Aggregate non-loopback interfaces; counters are rates only after the first snapshot.
    net = [line.split() for line in read("/proc/net/dev").splitlines()[2:] if ":" in line]
    rx = tx = 0
    for fields in net:
        if fields[0].rstrip(":") != "lo":
            rx += int(fields[1]); tx += int(fields[9])
    cpu = read("/proc/stat").splitlines()[0].split()
    try:
        busy = sum(map(int, cpu[1:4])) + sum(map(int, cpu[6:9]))
        total = sum(map(int, cpu[1:]))
        state = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "lumen-chrome-counters.json"
        previous = json.loads(read(state) or "{}")
        import time
        now = time.monotonic()
        elapsed = now - previous.get("time", now)
        if elapsed > 0:
            result["rx"] = round(max(0, rx - previous.get("rx", rx)) / elapsed)
            result["tx"] = round(max(0, tx - previous.get("tx", tx)) / elapsed)
        delta = total - previous.get("total", total)
        if delta > 0:
            result["cpu"] = round(100 * (busy - previous.get("busy", busy)) / delta)
        state.write_text(json.dumps({"rx": rx, "tx": tx, "time": now,
                                     "busy": busy, "total": total}))
    except (OSError, ValueError, IndexError):
        pass
    return result


def input_state():
    caps = bus_value("/org/lumen/Input", "org.lumen.Input", "GetCapsLock")
    brightness = None
    for backlight in Path("/sys/class/backlight").glob("*"):
        try:
            maximum = int(read(backlight / "max_brightness"))
            if maximum > 0:
                brightness = round(100 * int(read(backlight / "actual_brightness")) / maximum)
                break
        except ValueError:
            pass
    return {"caps": caps, "brightness": brightness}


def bus_value(path, interface, method, *args):
    try:
        result = subprocess.run(
            ["busctl", "--user", "--json=short", "--timeout=1", "call", "org.lumen",
             path, interface, method, *args], capture_output=True, check=True, timeout=2)
        return json.loads(result.stdout)["data"][0]
    except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError):
        return None


def history():
    value = bus_value("/org/lumen/Notifications", "org.lumen.Notifications", "GetHistory")
    try:
        return json.loads(value) if value is not None else []
    except (TypeError, ValueError):
        return []


def dismiss(notification_id):
    return bus_value("/org/lumen/Notifications", "org.lumen.Notifications",
                     "Dismiss", "u", str(notification_id)) is True


def invoke_action(notification_id, key):
    return bus_value("/org/lumen/Notifications", "org.lumen.Notifications",
                     "InvokeAction", "us", str(notification_id), key) is True


def watch_input():
    import time
    previous = None
    while True:
        state = input_state()
        if state != previous:
            print(json.dumps(state), flush=True)
            previous = state
        time.sleep(0.15)


if __name__ == "__main__":
    if sys.argv[1:] == ["watch-input"]:
        watch_input()
    elif sys.argv[1:] == ["history"]:
        print(json.dumps(history()))
    elif len(sys.argv) == 3 and sys.argv[1] == "dismiss" and sys.argv[2].isdigit():
        sys.exit(0 if dismiss(int(sys.argv[2])) else 1)
    elif len(sys.argv) == 4 and sys.argv[1] == "action" and sys.argv[2].isdigit():
        sys.exit(0 if invoke_action(int(sys.argv[2]), sys.argv[3]) else 1)
    else:
        print(json.dumps(config() if sys.argv[1:] == ["config"] else snapshot()))
