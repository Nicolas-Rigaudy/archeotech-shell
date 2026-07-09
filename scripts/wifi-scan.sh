#!/usr/bin/env python3
"""Output one JSON object per line for each WiFi network from nmcli.
Fields: ssid, security, signal, active (bool), saved (bool), autoconnect (bool), bssid"""
import subprocess, json

def run(*cmd):
    try:
        return subprocess.run(list(cmd), capture_output=True, text=True, timeout=15).stdout
    except Exception:
        return ""

def parse_nmcli(output):
    """Split nmcli -g lines handling \\: escaped colons."""
    rows = []
    for line in output.splitlines():
        if not line.strip():
            continue
        parts = line.replace('\\:', '\x00').split(':')
        rows.append([p.replace('\x00', ':') for p in parts])
    return rows

# Saved WiFi connection profiles → autoconnect state (ssid -> bool)
saved = {}
for row in parse_nmcli(run('nmcli', '-g', 'NAME,TYPE', 'connection', 'show')):
    if len(row) >= 2 and row[1] == '802-11-wireless':
        ac = run('nmcli', '-g', 'connection.autoconnect', 'connection', 'show', row[0]).strip()
        saved[row[0]] = (ac == 'yes')

# WiFi network list
for row in parse_nmcli(run('nmcli', '-g', 'SSID,SECURITY,SIGNAL,ACTIVE,BSSID', 'dev', 'wifi', 'list')):
    if len(row) < 5:
        continue
    ssid     = row[0]
    security = row[1]
    signal   = int(row[2]) if row[2].isdigit() else 0
    active   = row[3] == 'yes'
    bssid    = ':'.join(row[4:])  # already unescaped by parse_nmcli
    if not ssid:
        continue
    print(json.dumps({
        'ssid':     ssid,
        'security': security,
        'signal':   signal,
        'active':      active,
        'saved':       ssid in saved,
        'autoconnect': saved.get(ssid, True),
        'bssid':       bssid,
    }), flush=True)
