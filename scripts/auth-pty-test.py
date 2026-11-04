#!/usr/bin/env python3
"""Exercise askpass with a real controlling PTY; run inside dbus-run-session with lumen."""
import fcntl
import json
import os
import pty
import select
import subprocess
import sys
import termios
import time

bin_dir = sys.argv[1]
helper = f"{bin_dir}/lumen-auth-gui"
askpass = f"{bin_dir}/lumen-askpass"


def receive(fd, ending, seconds=10):
    data = b""
    until = time.monotonic() + seconds
    while ending not in data:
        remaining = until - time.monotonic()
        assert remaining > 0, f"timed out waiting for {ending!r}: {data!r}"
        if select.select([fd], [], [], remaining)[0]:
            data += os.read(fd, 4096)
    return data


def launch():
    master, slave = pty.openpty()
    pid = os.fork()
    if pid == 0:
        os.close(master)
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        for fd in (0, 1, 2):
            os.dup2(slave, fd)
        os.close(slave)
        os.execv(askpass, [askpass, "Test:"])
    return pid, master, slave


subprocess.run([helper, "next"], check=True, capture_output=True)

# GUI wins while the TTY reader is still waiting: newline and ECHO restoration.
pid, master, slave = launch()
assert receive(master, b"Test: ").endswith(b"Test: ")
assert not termios.tcgetattr(slave)[3] & termios.ECHO
challenge = json.loads(subprocess.check_output([helper, "next"]))["id"]
assert challenge
subprocess.run([helper, "submit", challenge], input=b"gui-pass\n", check=True)
output = receive(master, b"gui-pass\r\n")
assert output.startswith(b"\r\n"), output
assert os.waitpid(pid, 0)[1] == 0
assert termios.tcgetattr(slave)[3] & termios.ECHO
os.close(master)
os.close(slave)

# TTY wins with a password entered after the hidden prompt.
pid, master, slave = launch()
receive(master, b"Test: ")
os.write(master, b"tty-pass\n")
output = receive(master, b"tty-pass\r\n")
assert output.startswith(b"\r\n"), output
assert os.waitpid(pid, 0)[1] == 0
assert termios.tcgetattr(slave)[3] & termios.ECHO
os.close(master)
os.close(slave)
print("PTY GUI/TTY race and terminal cleanup passed")
