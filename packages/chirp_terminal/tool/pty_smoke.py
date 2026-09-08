"""POSIX smoke test: python3 tool/pty_smoke.py [dart executable]."""

import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import struct
import subprocess
import sys
import termios
import time


PACKAGE = Path(__file__).resolve().parent.parent
DART = sys.argv[1] if len(sys.argv) > 1 else "dart"


def run(cancel=False):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    environment = {**os.environ, "TERM": "xterm-256color"}
    environment.pop("CI", None)
    environment.pop("NO_COLOR", None)

    def control_tty():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    command = [
        DART,
        "--enable-asserts",
        f"--packages={PACKAGE}/.dart_tool/package_config.json",
        str(PACKAGE / "test/fixtures/pty_app.dart"),
    ]
    if cancel:
        command.append("cancel")
    process = subprocess.Popen(
        command,
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=slave,
        env=environment,
        preexec_fn=control_tty,
    )
    transcript = bytearray()

    def read(timeout):
        if not select.select([master], [], [], timeout)[0]:
            return False
        try:
            chunk = os.read(master, 65536)
        except OSError as error:
            if error.errno != errno.EIO:
                raise
            chunk = b""
        transcript.extend(chunk)
        return bool(chunk)

    def until(needle):
        deadline = time.monotonic() + 5
        while needle not in transcript and time.monotonic() < deadline:
            read(0.1)
            if process.poll() is not None:
                break
        assert needle in transcript, (needle, transcript[-1500:])

    try:
        if cancel:
            until(b"Cancel me")
            os.write(master, b"\x03")
        else:
            until(b"Name")
            os.write(master, b"\x1b[Db")
            until(b"Background log")
            os.write(master, b"\r")
            until(b"Environment")
            os.write(master, b"prod\r")
            until(b"Continue?")
            os.write(master, b"y\r")
            until(b"Token")
            os.write(master, b"supersecret\r")

        deadline = time.monotonic() + 5
        while process.poll() is None and time.monotonic() < deadline:
            read(0.05)
        assert process.poll() == 0, (process.poll(), transcript[-1500:])
        while read(0):
            pass
        output = process.stdout.read().decode()
        # The Dart fixture asserts input modes are restored before closing stdin.
        assert b"supersecret" not in transcript, "Password was echoed"
        if cancel:
            assert output == "CANCELLED\n", output
        else:
            assert json.loads(output) == {
                "name": "abc",
                "choice": 2,
                "enabled": True,
                "passwordLength": 11,
            }, output
        print(json.dumps({
            "scenario": "cancel" if cancel else "interactive",
            "output": output.strip(),
            "terminal_restored": True,
            "secret_not_echoed": True,
        }))
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        process.stdout.close()
        os.close(master)
        os.close(slave)


if __name__ == "__main__":
    run()
    run(cancel=True)
