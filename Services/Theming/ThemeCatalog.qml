pragma Singleton
import QtQuick

// Sprint 25 — the curated theme catalogue: family → flavors (→ accents).
// The flavor axis carries the light/dark mode. `variant` is the on-disk
// themes/<variant>/ dir that theme-switch.py applies. Accents name palette
// colors the picker offers (item_091): every family shares the 14 palette names,
// so QML, kitty, rofi and mango take any of them; only Catppuccin also has
// per-accent GTK/cursor packages, and the others keep their GTK theme (the
// documented fallback). Monochrome has no hue by design: an empty list.
//
// Adding a theme = add its dir under themes/ + a flavor entry here (and, for
// full app coverage, the kitty .conf / GTK package / VSCode ext — see
// theme-switch.py coverage notes).
QtObject {
    id: root

    // The 14 palette color names (Catppuccin's accents: they match its per-accent
    // GTK packages). Every theme.json carries all of them.
    readonly property var _namedAccents: [
        "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
        "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"
    ]

    readonly property var families: [
        {
            id: "catppuccin", label: "Catppuccin",
            swatch: ["#c6a0f6", "#8aadf4", "#a6da95", "#eed49f"],
            accents: _namedAccents,
            flavors: [
                { id: "latte",     label: "Latte",     variant: "archeotech-latte",     mode: "light" },
                { id: "frappe",    label: "Frappé",    variant: "archeotech-frappe",    mode: "dark"  },
                { id: "macchiato", label: "Macchiato", variant: "archeotech-macchiato", mode: "dark"  },
                { id: "mocha",     label: "Mocha",     variant: "archeotech-mocha",     mode: "dark"  }
            ]
        },
        {
            id: "dracula", label: "Dracula", accents: _namedAccents,
            swatch: ["#bd93f9", "#8be9fd", "#50fa7b", "#ff79c6"],
            flavors: [
                { id: "alucard", label: "Alucard", variant: "dracula-alucard", mode: "light" },
                { id: "dracula", label: "Dracula", variant: "dracula",         mode: "dark"  }
            ]
        },
        {
            id: "tokyo-night", label: "Tokyo Night", accents: _namedAccents,
            swatch: ["#bb9af7", "#7aa2f7", "#9ece6a", "#e0af68"],
            flavors: [
                { id: "day",   label: "Day",   variant: "tokyo-night-day", mode: "light" },
                { id: "night", label: "Night", variant: "tokyo-night",     mode: "dark"  }
            ]
        },
        {
            id: "gruvbox", label: "Gruvbox", accents: _namedAccents,
            swatch: ["#fabd2f", "#83a598", "#b8bb26", "#fb4934"],
            flavors: [
                { id: "light", label: "Light", variant: "gruvbox-light", mode: "light" },
                { id: "dark",  label: "Dark",  variant: "gruvbox",       mode: "dark"  }
            ]
        },
        {
            id: "nord", label: "Nord", accents: _namedAccents,
            swatch: ["#88c0d0", "#5e81ac", "#a3be8c", "#ebcb8b"],
            flavors: [
                { id: "nord",  label: "Dark",  variant: "nord",       mode: "dark"  }
            ]
        },
        {
            id: "monochrome", label: "Monochrome", accents: [],
            swatch: ["#d8d8d8", "#c8c8c8", "#a8a8a8", "#888888"],
            flavors: [
                { id: "light", label: "Light", variant: "monochrome-light", mode: "light" },
                { id: "dark",  label: "Dark",  variant: "monochrome",       mode: "dark"  }
            ]
        }
    ]

    function familyById(id) {
        for (var i = 0; i < families.length; i++)
            if (families[i].id === id) return families[i]
        return families[0]
    }

    // Palette color names this family lets you pick as the accent (empty = not
    // accent-capable, so the picker hides the swatch row). Sprint 25 Phase 2.
    function accentsFor(familyId) {
        var fam = familyById(familyId)
        return fam.accents || []
    }

    // All flavors of a family matching a mode ("dark"/"light").
    function flavorsForMode(familyId, mode) {
        var fam = familyById(familyId)
        return fam.flavors.filter(function(f) { return f.mode === mode })
    }

    function hasLight(familyId) { return flavorsForMode(familyId, "light").length > 0 }

    function flavorById(familyId, flavorId) {
        var fam = familyById(familyId)
        for (var i = 0; i < fam.flavors.length; i++)
            if (fam.flavors[i].id === flavorId) return fam.flavors[i]
        return null
    }

    // First flavor of a family for a mode, or the first flavor overall.
    function defaultFlavor(familyId, mode) {
        var list = flavorsForMode(familyId, mode)
        if (list.length > 0) return list[0].id
        return familyById(familyId).flavors[0].id
    }

    function variantFor(familyId, flavorId) {
        var f = flavorById(familyId, flavorId)
        return f ? f.variant : ""
    }

    // Reverse lookups: seed config from the currently-applied theme.variant so
    // first boot doesn't switch themes out from under the user.
    function familyOfVariant(variant) {
        for (var i = 0; i < families.length; i++)
            for (var j = 0; j < families[i].flavors.length; j++)
                if (families[i].flavors[j].variant === variant) return families[i].id
        return "catppuccin"
    }
    function flavorOfVariant(variant) {
        for (var i = 0; i < families.length; i++)
            for (var j = 0; j < families[i].flavors.length; j++)
                if (families[i].flavors[j].variant === variant) return families[i].flavors[j].id
        return "macchiato"
    }
    function modeOfVariant(variant) {
        for (var i = 0; i < families.length; i++)
            for (var j = 0; j < families[i].flavors.length; j++)
                if (families[i].flavors[j].variant === variant) return families[i].flavors[j].mode
        return "dark"
    }
}
