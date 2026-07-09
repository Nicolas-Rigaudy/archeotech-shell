pragma Singleton
import QtQuick
import QtCore

QtObject {
    readonly property string home:         StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string cache:        home + "/.cache"
    readonly property string config:       home + "/.config"
    readonly property string localBin:     home + "/.local/bin"
    readonly property string wallpaperSet: localBin + "/wallpaper-set.sh"
    readonly property string wallpaperPicker: localBin + "/wallpaper-picker.sh"
    readonly property string hyprlockLaunch: localBin + "/hyprlock-launch.sh"
    readonly property string wlogoutLaunch:  localBin + "/wlogout-launch.sh"
    readonly property string listDesktopApps: localBin + "/list-desktop-apps.sh"
    readonly property string wifiScan:        localBin + "/wifi-scan.sh"
    readonly property string themeSwitch:     localBin + "/theme-switch.sh"
}
