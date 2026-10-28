#!/usr/bin/env python3
"""Spustí hru lokálně: malý webový server nad složkou docs/ a otevře prohlížeč.

Dvojklik na spustit.bat (Windows), spustit.command (macOS) nebo spustit.sh (Linux),
případně:  python3 spustit.py
Ukončení: zavřít okno terminálu nebo stisknout Ctrl+C.
"""
import http.server
import os
import socketserver
import sys
import threading
import webbrowser

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs")
PORT_START = 8765


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        # Pro případ vícevláknové verze enginu; neškodí ani jednovláknové.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass


def main():
    if not os.path.exists(os.path.join(ROOT, "index.html")):
        print("Chybí docs/index.html – hra ještě nebyla sestavena (viz README.md).")
        sys.exit(1)
    os.chdir(ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    port = PORT_START
    while True:
        try:
            httpd = socketserver.ThreadingTCPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            port += 1
            if port > PORT_START + 50:
                print("Nepodařilo se najít volný port.")
                sys.exit(1)
    url = "http://localhost:%d/index.html" % port
    print("Hra běží na adrese:", url)
    print("Tuto adresu otevři v prohlížeči (Chrome, Edge, Firefox). Ukončení: Ctrl+C nebo zavři toto okno.")
    threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nKonec.")


if __name__ == "__main__":
    main()
