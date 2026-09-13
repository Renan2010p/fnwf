#!/usr/bin/env python3
"""Persistent HTTP server for FNWF web build."""
import http.server
import socketserver
import os
import signal
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_web")

os.chdir(DIR)
signal.signal(signal.SIGHUP, signal.SIG_IGN)

Handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"FNWF server running on http://0.0.0.0:{PORT}")
    httpd.serve_forever()
