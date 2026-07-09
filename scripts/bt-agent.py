#!/usr/bin/env python3
"""BlueZ NoInputNoOutput pairing agent + discovery helper for the Quickshell
settings panel.

Both discovery and the pairing handshake must be driven by a *persistent* D-Bus
connection: BlueZ ties the discovery session and the agent callbacks to the
owning connection, so a one-shot `busctl StartDiscovery`/`Pair` would be torn
down the instant the caller exits. This helper holds that connection open.

Modes:
  bt-agent.py --scan <seconds>   register agent + StartDiscovery, hold open,
                                 then StopDiscovery and exit (or on SIGTERM).
  bt-agent.py --pair <MAC>       register agent, Pair + Trust + Connect a device.

Capability NoInputNoOutput auto-accepts "just-works" pairings (headphones, most
audio gear). PIN/passkey devices (keyboards, car kits) may still need blueman.
"""
import signal
import sys
import warnings

warnings.filterwarnings("ignore")  # quiet PyGI deprecation notices

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BUS_NAME = "org.bluez"
ADAPTER_PATH = "/org/bluez/hci0"
AGENT_PATH = "/archeotech/btagent"
CAPABILITY = "NoInputNoOutput"
AGENT_IFACE = "org.bluez.Agent1"


class Agent(dbus.service.Object):
    """Auto-accept agent: no input available, so confirm/authorize everything."""

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        return

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        return "0000"

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        return dbus.UInt32(0)

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        return  # auto-confirm

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        return  # auto-authorize

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        pass


def register_agent(bus):
    mgr = dbus.Interface(bus.get_object(BUS_NAME, "/org/bluez"),
                         "org.bluez.AgentManager1")
    mgr.RegisterAgent(AGENT_PATH, CAPABILITY)
    try:
        mgr.RequestDefaultAgent(AGENT_PATH)
    except dbus.DBusException:
        # Another agent (e.g. blueman) owns the default slot — our registered
        # agent still services requests for the pairings we initiate.
        pass


def run_scan(bus, loop, adapter, seconds):
    try:
        adapter.StartDiscovery()
    except dbus.DBusException as exc:
        print("StartDiscovery failed:", exc, file=sys.stderr)

    def stop(*_):
        try:
            adapter.StopDiscovery()
        except dbus.DBusException:
            pass
        loop.quit()
        return False

    GLib.timeout_add_seconds(seconds, stop)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
    loop.run()
    return 0


def run_pair(bus, loop, mac):
    dev_path = "%s/dev_%s" % (ADAPTER_PATH, mac.upper().replace(":", "_"))
    dev = dbus.Interface(bus.get_object(BUS_NAME, dev_path), "org.bluez.Device1")
    props = dbus.Interface(bus.get_object(BUS_NAME, dev_path),
                           "org.freedesktop.DBus.Properties")
    rc = {"code": 0}

    def finish():
        loop.quit()
        return False

    def on_paired():
        try:
            props.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
        except dbus.DBusException:
            pass
        try:
            dev.Connect()
        except dbus.DBusException as exc:
            print("Connect failed:", exc, file=sys.stderr)
        finish()

    def on_error(exc):
        print("Pair failed:", exc, file=sys.stderr)
        rc["code"] = 1
        finish()

    def do_pair():
        try:
            dev.Pair(reply_handler=on_paired, error_handler=on_error)
        except dbus.DBusException as exc:
            print("Pair call failed:", exc, file=sys.stderr)
            rc["code"] = 1
            finish()
        return False

    GLib.idle_add(do_pair)
    loop.run()
    return rc["code"]


def main():
    if len(sys.argv) < 3:
        print("usage: bt-agent.py --scan <secs> | --pair <MAC>", file=sys.stderr)
        return 2
    mode, arg = sys.argv[1], sys.argv[2]

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    Agent(bus, AGENT_PATH)
    register_agent(bus)
    loop = GLib.MainLoop()
    adapter = dbus.Interface(bus.get_object(BUS_NAME, ADAPTER_PATH),
                             "org.bluez.Adapter1")

    if mode == "--scan":
        return run_scan(bus, loop, adapter, int(arg))
    if mode == "--pair":
        return run_pair(bus, loop, arg)
    print("unknown mode:", mode, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
