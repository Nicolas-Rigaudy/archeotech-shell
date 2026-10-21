#!/usr/bin/env python3
"""A fake StatusNotifierItem with a DBusMenu, for headless tray renders.

Registers one tray item on the session bus (the shell's SystemTray service is the
watcher) so `shot.sh --exec` can show the tray menu without a real app:

  shot.sh --exec 'python3 tests/tools/fake-sni.py & sleep 3
                  qs ipc --pid "$QSPID" call popup open tray; sleep 2' out.png

Needs python-dbus and PyGObject (the Arch `python-dbus`, `python-gobject`).
Menu: plain entries, separators, a disabled one, a checkbox, a radio pair and a submenu. Entry clicks print to stdout.
"""
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

SNI_PATH, MENU_PATH = "/StatusNotifierItem", "/MenuBar"


def entry(i, label, **props):
    p = {"label": label, "enabled": True, "visible": True}
    p.update(props)
    return i, p


# id, properties, children ids
ITEMS = [
    entry(1, "Open window"),
    entry(2, "Pause syncing"),
    entry(3, "", type="separator"),
    entry(4, "Start at login", **{"toggle-type": "checkmark", "toggle-state": 1}),
    entry(5, "Mute notifications", **{"toggle-type": "checkmark", "toggle-state": 0}),
    entry(6, "Status: Online", **{"toggle-type": "radio", "toggle-state": 1}),
    entry(7, "Status: Away", **{"toggle-type": "radio", "toggle-state": 0}),
    entry(8, "", type="separator"),
    entry(9, "Settings", **{"children-display": "submenu"}),
    entry(10, "Unavailable action", enabled=False),
    entry(11, "Quit"),
]
CHILDREN = {9: [entry(91, "Account"), entry(92, "Notifications"), entry(93, "Advanced")]}


def node(i, props, kids):
    kid_vars = [dbus.Struct(k, signature="ia{sv}av", variant_level=1) for k in kids]
    return (dbus.Int32(i), dbus.Dictionary(props, signature="sv"), dbus.Array(kid_vars, signature="v"))


class Menu(dbus.service.Object):
    @dbus.service.method("com.canonical.dbusmenu", in_signature="iias", out_signature="u(ia{sv}av)")
    def GetLayout(self, parent, depth, names):
        def build(i, props):
            return node(i, props, [build(*c) for c in CHILDREN.get(i, [])])
        if parent == 0:
            root = node(0, {"children-display": "submenu"}, [build(*e) for e in ITEMS])
        else:
            props = dict(ITEMS + [c for cs in CHILDREN.values() for c in cs]).get(parent, {})
            root = build(parent, props)
        return dbus.UInt32(1), dbus.Struct(root, signature="ia{sv}av")

    @dbus.service.method("com.canonical.dbusmenu", in_signature="isvu")
    def Event(self, i, event_id, data, ts):
        print("event", i, event_id, flush=True)

    @dbus.service.method("com.canonical.dbusmenu", in_signature="i", out_signature="b")
    def AboutToShow(self, i):
        return False

    @dbus.service.method("com.canonical.dbusmenu", in_signature="aias", out_signature="a(ia{sv})")
    def GetGroupProperties(self, ids, names):
        everything = ITEMS + [c for cs in CHILDREN.values() for c in cs]
        return [(dbus.Int32(i), dbus.Dictionary(p, signature="sv"))
                for i, p in everything if not ids or i in ids]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self.GetAll(iface)[prop]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return {"Version": dbus.UInt32(3), "TextDirection": "ltr", "Status": "normal",
                "IconThemePath": dbus.Array([], signature="s")}


def pixmap(n=22):
    """A round violet badge, ARGB32 big-endian as the SNI spec wants."""
    data = bytearray()
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            inside = (x - c) ** 2 + (y - c) ** 2 <= (c - 1) ** 2
            data += bytes((255, 150, 110, 230) if inside else (0, 0, 0, 0))
    return dbus.Array([dbus.Struct((dbus.Int32(n), dbus.Int32(n), dbus.Array([dbus.Byte(b) for b in data], signature="y")),
                                   signature="iiay")], signature="(iiay)")


class Item(dbus.service.Object):
    PROPS = {
        "Category": "ApplicationStatus", "Id": "fake-sni", "Title": "Fake tray app",
        "Status": "Active", "IconName": "", "IconPixmap": pixmap(),
        "Menu": dbus.ObjectPath(MENU_PATH), "ItemIsMenu": False,
        "ToolTip": dbus.Struct(("", dbus.Array([], signature="(iiay)"), "Fake tray app", "Right-click for the menu"),
                               signature="sa(iiay)ss"),
    }

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self.PROPS[prop]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return dbus.Dictionary(self.PROPS, signature="sv")

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii")
    def Activate(self, x, y): print("activate", flush=True)

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii")
    def SecondaryActivate(self, x, y): print("secondary", flush=True)

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="ii")
    def ContextMenu(self, x, y): print("contextmenu", flush=True)

    @dbus.service.method("org.kde.StatusNotifierItem", in_signature="is")
    def Scroll(self, d, o): print("scroll", d, flush=True)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = "org.kde.StatusNotifierItem-%d-1" % __import__("os").getpid()
    bus_name = dbus.service.BusName(name, bus)
    Item(bus, SNI_PATH)
    Menu(bus, MENU_PATH)
    watcher = bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
    watcher.RegisterStatusNotifierItem(name, dbus_interface="org.kde.StatusNotifierWatcher")
    print("registered", name, flush=True)
    GLib.MainLoop().run()


if __name__ == "__main__":
    sys.exit(main())
