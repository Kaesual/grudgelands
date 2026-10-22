"""A minimal Chrome DevTools Protocol client (Python standard library): starts
a headless Chromium with its own profile, and talks to its page over a
WebSocket (RFC 6455: masked client frames, text messages, ping/pong).

    with Browser(width, height) as b:
        b.go("http://127.0.0.1:8756/")
        b.wait("window.__editor && window.__editor.ready")
        b.click(x, y); b.key("KeyW", hold=0.5); b.shot("/tmp/a.png")
"""

import base64
import json
import os
import select
import shutil
import socket
import struct
import subprocess
import tempfile
import time
import urllib.request

CHROME = os.environ.get("CHROME_BIN") or shutil.which("chromium-browser") or shutil.which("chromium")


class WebSocket(object):
    def __init__(self, url):
        assert url.startswith("ws://")
        hostport, _, path = url[5:].partition("/")
        host, _, port = hostport.partition(":")
        self.sock = socket.create_connection((host, int(port)), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall(("GET /%s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\n"
                           "Connection: Upgrade\r\nSec-WebSocket-Key: %s\r\n"
                           "Sec-WebSocket-Version: 13\r\n\r\n" % (path, hostport, key)).encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.sock.recv(1)
            if not chunk:
                raise IOError("websocket handshake failed")
            head += chunk
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise IOError("websocket handshake refused: %r" % head[:80])
        self.buf = b""

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(1 << 16)
            if not chunk:
                raise IOError("websocket closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self, opcode, payload):
        head = bytes([0x80 | opcode])
        n = len(payload)
        if n < 126:
            head += bytes([0x80 | n])
        elif n < 1 << 16:
            head += bytes([0x80 | 126]) + struct.pack(">H", n)
        else:
            head += bytes([0x80 | 127]) + struct.pack(">Q", n)
        mask = os.urandom(4)
        body = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(head + mask + body)

    def pending(self, timeout):
        """Is a message (or part of one) waiting within `timeout` seconds?"""
        return bool(self.buf) or bool(select.select([self.sock], [], [], timeout)[0])

    def send(self, text):
        self._frame(1, text.encode("utf-8"))

    def recv(self):
        message = b""
        while True:
            b0, b1 = self._read(2)
            opcode, n = b0 & 0x0F, b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            mask = self._read(4) if b1 & 0x80 else None
            data = self._read(n)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if opcode == 9:
                self._frame(10, data)
                continue
            if opcode == 8:
                raise IOError("websocket closed by the browser")
            message += data
            if b0 & 0x80:
                return message.decode("utf-8")

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


class Browser(object):
    def __init__(self, width=1600, height=1000):
        if not CHROME:
            raise SystemExit("no chromium-browser found (CHROME_BIN)")
        self.profile = tempfile.mkdtemp(prefix="r56-editor-chrome-")
        self.proc = subprocess.Popen(
            [CHROME, "--headless=new", "--no-first-run", "--no-default-browser-check",
             "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--remote-debugging-port=0",
             "--user-data-dir=" + self.profile, "--window-size=%d,%d" % (width, height),
             "--hide-scrollbars", "about:blank"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        port = None
        for _ in range(200):
            try:
                with open(os.path.join(self.profile, "DevToolsActivePort")) as fh:
                    port = int(fh.readline())
                break
            except (OSError, ValueError):
                time.sleep(0.05)
        if not port:
            self.close()
            raise SystemExit("chromium did not start")
        targets = json.load(urllib.request.urlopen("http://127.0.0.1:%d/json" % port))
        page = next(t for t in targets if t["type"] == "page")
        self.ws = WebSocket(page["webSocketDebuggerUrl"])
        self.serial = 0
        self.events = []
        self.call("Runtime.enable")
        self.call("Page.enable")
        self.call("Emulation.setDeviceMetricsOverride", width=width, height=height,
                  deviceScaleFactor=1, mobile=False)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def close(self):
        if getattr(self, "ws", None):
            self.ws.close()
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        shutil.rmtree(self.profile, ignore_errors=True)

    def call(self, method, **params):
        self.serial += 1
        mine = self.serial
        self.ws.send(json.dumps({"id": mine, "method": method, "params": params}))
        while True:
            message = json.loads(self.ws.recv())
            if message.get("id") == mine:
                if "error" in message:
                    raise RuntimeError("%s: %s" % (method, message["error"]))
                return message.get("result", {})
            if "method" in message:
                self.events.append(message)

    def js(self, expression):
        """Evaluate in the page (promises awaited); the value as JSON."""
        r = self.call("Runtime.evaluate", expression=expression, awaitPromise=True,
                      returnByValue=True)
        if "exceptionDetails" in r:
            raise RuntimeError("page error: %s" % json.dumps(r["exceptionDetails"])[:600])
        return r.get("result", {}).get("value")

    def errors(self):
        """Exceptions and console errors the page reported so far."""
        out = []
        for e in self.events:
            if e["method"] == "Runtime.exceptionThrown":
                out.append(json.dumps(e["params"]["exceptionDetails"])[:400])
            elif e["method"] == "Runtime.consoleAPICalled" and e["params"]["type"] == "error":
                out.append(" ".join(str(a.get("value", a.get("description", ""))) for a in e["params"]["args"]))
        return out

    def go(self, url):
        self.call("Page.navigate", url=url)

    def reload(self):
        """Reload the page, accepting a "leave the page?" question."""
        self.call("Page.reload")
        end = time.time() + 10
        while time.time() < end:
            if any(e["method"] == "Page.javascriptDialogOpening" for e in self.events):
                self.events = [e for e in self.events if e["method"] != "Page.javascriptDialogOpening"]
                self.call("Page.handleJavaScriptDialog", accept=True)
                return
            if any(e["method"] == "Page.loadEventFired" for e in self.events):
                return
            while self.ws.pending(0.1):
                message = json.loads(self.ws.recv())
                if "method" in message:
                    self.events.append(message)

    def wait(self, expression, timeout=60):
        end = time.time() + timeout
        while time.time() < end:
            if self.js("!!(%s)" % expression):
                return
            time.sleep(0.1)
        raise RuntimeError("timed out waiting for %s" % expression)

    def click(self, x, y, modifiers=0):
        for kind in ("mouseMoved", "mousePressed", "mouseReleased"):
            self.call("Input.dispatchMouseEvent", type=kind, x=x, y=y, button="left",
                      clickCount=1, modifiers=modifiers)

    def drag(self, points):
        x, y = points[0]
        self.call("Input.dispatchMouseEvent", type="mouseMoved", x=x, y=y)
        self.call("Input.dispatchMouseEvent", type="mousePressed", x=x, y=y, button="left", clickCount=1)
        for x, y in points[1:]:
            self.call("Input.dispatchMouseEvent", type="mouseMoved", x=x, y=y, button="left", buttons=1)
        self.call("Input.dispatchMouseEvent", type="mouseReleased", x=x, y=y, button="left", clickCount=1)

    def click_selector(self, selector):
        box = self.js("(() => { const r = document.querySelector(%s).getBoundingClientRect();"
                      " return [r.left + r.width / 2, r.top + r.height / 2]; })()" % json.dumps(selector))
        self.click(*box)

    def key(self, code, key=None, hold=0.0, modifiers=0):
        key = key or (code[3:].lower() if code.startswith("Key") else code)
        self.call("Input.dispatchKeyEvent", type="keyDown", code=code, key=key, modifiers=modifiers,
                  windowsVirtualKeyCode=ord(key.upper()) if len(key) == 1 else 0)
        if hold:
            time.sleep(hold)
        self.call("Input.dispatchKeyEvent", type="keyUp", code=code, key=key, modifiers=modifiers,
                  windowsVirtualKeyCode=ord(key.upper()) if len(key) == 1 else 0)

    def shot(self, path):
        data = self.call("Page.captureScreenshot", format="png")["data"]
        with open(path, "wb") as fh:
            fh.write(base64.b64decode(data))
