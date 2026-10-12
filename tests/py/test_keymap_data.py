"""Tests for scripts/keymap-data.py (items 144/145). Run: python3 -m unittest discover tests/py

Fixtures are excerpts of real `xkbcli compile-keymap` output (us altgr-intl, fr)
and of the en_US.UTF-8 Compose table, so no xkbcli / X11 files are needed."""
import importlib.util
import pathlib
import unittest

_p = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "keymap-data.py"
_spec = importlib.util.spec_from_file_location("keymap_data", _p)
km = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(km)

US_INTL = """xkb_keymap {
xkb_keycodes "evdev" { <AD03> = 26; };
xkb_symbols "pc_us(altgr-intl)_inet(evdev)" {
	name[1]="English (intl., with AltGr dead keys)";
	key <TLDE>               {	[           grave,      asciitilde,      dead_grave,      dead_tilde ] };
	key <AE05>               {	[               5,         percent,        EuroSign,    dead_cedilla ] };
	key <AE06>               {	[               6,     asciicircum, dead_circumflex,      onequarter ] };
	key <AD03>               {	[               e,               E,          eacute,          Eacute ] };
	key <AC01>               {	[               a,               A,          aacute,          Aacute ] };
	key <AC11>               {	[      apostrophe,        quotedbl,      dead_acute,  dead_diaeresis ] };
	key <AB03>               {	[               c,               C,       copyright,            cent ] };
	key <AC04>               {	[               f,               F,               f,               F ] };
	key <AB08>               {	[           comma,            less,        ccedilla,        Ccedilla ] };
	key <SPCE>               {	[           space ] };
	key <I172>               {	[        EuroSign ] };
	key <RALT>               {
		type= "ONE_LEVEL",
		symbols[1]= [ ISO_Level3_Shift ]
	};
};
};
"""

FR = """xkb_symbols "pc_fr_inet(evdev)" {
	name[1]="French";
	key <AE02>               {	[          eacute,               2,      asciitilde,       oneeighth ] };
	key <AE07>               {	[          egrave,               7,           grave,     dead_grave ] };
	key <AD03>               {	[               e,               E,        EuroSign,            cent ] };
	key <AD11>               {	[ dead_circumflex,  dead_diaeresis,      dead_tilde,      dead_caron ] };
	key <AB03>               {	[               c,               C,       copyright,            cent ] };
	key <LSGT>               {	[            less,         greater,             bar,       brokenbar ] };
	key <SPCE>               {	[           space ] };
};
"""

COMPOSE = r'''# en_US.UTF-8 excerpt
<dead_grave> <space>			: "`"	grave # GRAVE ACCENT
<dead_circumflex> <space>		: "^"	asciicircum # CIRCUMFLEX ACCENT
<dead_acute> <space>			: "'"	apostrophe # APOSTROPHE
<dead_grave> <e>			: "è"	egrave # LATIN SMALL LETTER E WITH GRAVE
<dead_grave> <E>			: "È"	Egrave # LATIN CAPITAL LETTER E WITH GRAVE
<dead_acute> <e>			: "é"	eacute # LATIN SMALL LETTER E WITH ACUTE
<dead_circumflex> <e>			: "ê"	ecircumflex # LATIN SMALL LETTER E WITH CIRCUMFLEX
<dead_circumflex> <E>			: "Ê"	Ecircumflex # LATIN CAPITAL LETTER E WITH CIRCUMFLEX
<dead_diaeresis> <e>			: "ë"	ediaeresis # LATIN SMALL LETTER E WITH DIAERESIS
<dead_cedilla> <c>			: "ç"	ccedilla # LATIN SMALL LETTER C WITH CEDILLA
<dead_grave> <a>			: "à"	agrave # LATIN SMALL LETTER A WITH GRAVE
<dead_ogonek> <e>			: "ę"	eogonek # not typable here: no dead_ogonek key
<Multi_key> <e> <e>			: "ə"	schwa # not a dead-key sequence
'''

# keysymdef.h stand-in: what the module would read from the header.
TABLE = km.compose_names(COMPOSE)
TABLE.update({"eacute": "é", "Eacute": "É", "egrave": "è", "EuroSign": "€", "copyright": "©",
              "ccedilla": "ç", "Ccedilla": "Ç", "aacute": "á", "Aacute": "Á", "asciitilde": "~",
              "asciicircum": "^", "percent": "%", "quotedbl": '"', "less": "<", "greater": ">",
              "comma": ",", "onequarter": "¼", "cent": "¢", "oneeighth": "⅛", "bar": "|",
              "brokenbar": "¦"})


def fmt(combo):
    return " then ".join(" + ".join(chord) for chord in combo)


def index(text):
    keys, label = km.parse_keymap(text)
    m = km.build_map(keys, label, km.parse_compose(COMPOSE), TABLE)
    return m, {c["ch"]: [fmt(x) for x in c["combos"]] for c in m["chars"]}


class Keymap(unittest.TestCase):
    def test_parse_keymap(self):
        keys, label = km.parse_keymap(US_INTL)
        self.assertEqual(label, "English (intl., with AltGr dead keys)")
        self.assertEqual(keys["AD03"], ["e", "E", "eacute", "Eacute"])
        self.assertEqual(keys["RALT"], ["ISO_Level3_Shift"], "multi-line symbols[1] form")
        self.assertNotIn("AD03", km.parse_keymap("xkb_keycodes { <AD03> = 26; };")[0], "keycodes are not symbols")

    def test_keysym_char(self):
        self.assertEqual(km.keysym_char("U00E9", {}), "é")
        self.assertEqual(km.keysym_char("e", {}), "e")
        self.assertEqual(km.keysym_char("eacute", TABLE), "é")
        self.assertIsNone(km.keysym_char("ISO_Level3_Shift", TABLE))

    def test_us_intl_e_family(self):
        """AC1: the e family with the exact combos (the owner's Ajazz)."""
        _, ix = index(US_INTL)
        self.assertEqual(ix["é"], ["AltGr + E", "AltGr + ' then E"], "direct first, dead key second")
        self.assertEqual(ix["É"], ["AltGr + Shift + E"])
        self.assertEqual(ix["è"], ["AltGr + ` then E"])
        self.assertEqual(ix["È"], ["AltGr + ` then Shift + E"])
        self.assertEqual(ix["ê"], ["AltGr + 6 then E"])
        self.assertEqual(ix["ë"], ["AltGr + Shift + ' then E"])
        self.assertEqual(ix["ç"], ["AltGr + ,", "AltGr + Shift + 5 then C"])
        self.assertEqual(ix["€"], ["AltGr + 5"], "the <I172> media key is not on the board")
        self.assertNotIn("ę", ix, "no dead_ogonek key: not typable")
        self.assertNotIn("ə", ix, "Compose-key (Multi_key) sequences are not dead keys")
        self.assertNotIn("e", ix, "plain ASCII on base/Shift is not listed")
        self.assertNotIn("F", ix, "AltGr+Shift+F = F repeats the Shift level: not listed")

    def test_fr_labels_and_dead_base(self):
        m, ix = index(FR)
        self.assertEqual(ix["é"], ["é"], "a key of its own on AZERTY, label kept lower-case")
        self.assertEqual(ix["ê"], ["^ then E"], "dead key on the base level, labelled by its accent")
        self.assertEqual(ix["€"], ["AltGr + E"])
        self.assertEqual(ix["^"][0], "^ then Space")
        self.assertEqual([r[0]["code"] for r in m["rows"] if r], ["AE02", "AD03", "LSGT"],
                         "ISO rows: LSGT starts the bottom row")

    def test_rows_levels(self):
        m, _ = index(US_INTL)
        ae06 = [k for r in m["rows"] for k in r if k["code"] == "AE06"][0]
        self.assertEqual([l and l["ch"] for l in ae06["levels"]], ["6", "^", "^", "¼"])
        self.assertTrue(ae06["levels"][2]["dead"])
        self.assertFalse(ae06["levels"][0]["dead"])

    def test_search_fields(self):
        m, _ = index(US_INTL)
        e = [c for c in m["chars"] if c["ch"] == "é"][0]
        self.assertEqual(e["base"], "e")
        self.assertEqual(e["name"], "Latin Small Letter E With Acute")
        self.assertEqual([c for c in m["chars"] if c["ch"] == "€"][0]["base"], "")

    def test_keyboards(self):
        conf = {"input": {
            "keyboardLayouts": {"1:1:AT Translated Set 2 keyboard": "fr", "3141:65021": "us-intl",
                                "1133:50504": "us", "9:9": "default"},
            "keyboardNodes": {"3141:65021": ["3141:65021:2.4G Dongle Keyboard"]},
            "hiddenKeyboards": ["1133:50504"]}}
        kbs = km.keyboards(conf, "xkb_rules_layout=fr,us\nxkb_rules_variant=,\n")
        self.assertEqual([(k["id"], k["map"]) for k in kbs],
                         [("1:1", "fr"), ("3141:65021", "us(altgr-intl)"), ("system:1", "us")],
                         "system fr is already the built-in's map")
        self.assertEqual(kbs[0]["name"], "Built-in keyboard", "old full-identifier key, i8042 renamed")
        self.assertEqual(kbs[1]["name"], "2.4G Dongle Keyboard", "name from keyboardNodes")
        self.assertEqual(km.keyboards({}, "")[0]["map"], "us", "nothing configured: plain US")


    def test_iso_by_layout(self):
        gb = """xkb_symbols "pc_gb(evdev)" {
	name[1]="English (UK)";
	key <AE01>               {	[               1,          exclam ] };
	key <AB01>               {	[               z,               Z ] };
	key <LSGT>               {	[       backslash,             bar ] };
};"""
        keys, label = km.parse_keymap(gb)
        rows = km.build_map(keys, label, [], TABLE, "gb")["rows"]
        self.assertEqual(rows[3][0]["code"], "LSGT", "UK is an ISO board despite its English name")
        rows = km.build_map(keys, label, [], TABLE, "us")["rows"]
        self.assertEqual(rows[3][0]["code"], "AB01", "US boards have no key left of Z")

    def test_typed_key_body(self):
        keys, _ = km.parse_keymap("""xkb_symbols "x" {
	key <AD01> {
		type[Group1]= "FOUR_LEVEL",
		symbols[Group1]= [ q, Q, adiaeresis, Adiaeresis ]
	};
};""")
        self.assertEqual(keys["AD01"], ["q", "Q", "adiaeresis", "Adiaeresis"], "the type's [Group1] is not the symbols")

    def test_key_labels_by_keycode(self):
        """A `code:10` bind shows the key as printed on the selected keyboard."""
        codes = km.parse_keycodes("xkb_keycodes \"evdev\" {\n\t<AE02> = 11;\n\t<AD11> = 34;\n\t<SPCE> = 65;\n\talias <LatQ> = <AD01>;\n};\nxkb_types {};")
        self.assertEqual(codes, {"AE02": 11, "AD11": 34, "SPCE": 65})
        keys, label = km.parse_keymap(FR)
        labels = km.build_map(keys, label, km.parse_compose(COMPOSE), TABLE, "fr", codes)["labels"]
        self.assertEqual(labels, {"11": "é", "34": "^", "65": "Space"})

    def test_no_config(self):
        self.assertEqual(km.global_layouts(""), [("us", "")])


if __name__ == "__main__":
    unittest.main()
