#!/usr/bin/env python3
"""Checks the String Catalog (Sources/Maramao/Resources/Localizable.xcstrings).

Italian is the source language, so the keys are the Italian strings. Fails when:
- an entry has no English translation (or an empty one, or a plural without "one"/"other");
- a translation uses different format specifiers than its key (e.g. %lld vs %@);
- a `String(localized: "...")` literal in Sources/ has no entry in the catalog;
- an App Shortcut phrase in Intents.swift has no line in en.lproj/AppShortcuts.strings;
- a SwiftUI literal (Text("..."), Button("..."), Toggle, Label, Section, Picker, .help, ...)
  has no entry. SwiftUI looks these up automatically, so without an entry they stay Italian.
  Literals without letters (e.g. "\\(a) · \\(b)") and the names in UNTRANSLATED are skipped.

Usage: scripts/check-strings.py [path/to/Localizable.xcstrings]
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "Sources/Maramao/Resources/Localizable.xcstrings")
REQUIRED = ["en"]
# SwiftUI calls whose first string literal is a LocalizedStringKey.
SWIFTUI = re.compile(
    r'(?:\b(?:Text|Button|Toggle|Label|Section|Picker|TextField|SecureField|DatePicker|Menu|Stepper'
    r'|LabeledContent|Link|GroupBox)\(|\.(?:help|navigationTitle|accessibilityLabel|accessibilityHint'
    r'|alert|confirmationDialog)\()\s*"((?:[^"\\]|\\.)*)"'
)
# Literals that read the same in every language.
UNTRANSLATED = {"Maramao"}
SPEC = re.compile(r"%(?:\d+\$)?(lld|ld|d|lf|f|@)|%%")


def specifiers(text):
    """Format specifiers in a string, ignoring positions, as a sorted list."""
    return sorted(m.group(1) for m in SPEC.finditer(text) if m.group(1))


def units(localization):
    """Yields (label, value) for every string unit of a localization."""
    if "stringUnit" in localization:
        yield "", localization["stringUnit"].get("value", "")
    plural = localization.get("variations", {}).get("plural")
    if plural is not None:
        for form in ("one", "other"):
            if form not in plural:
                yield f" [{form}]", None
        for form, entry in plural.items():
            yield f" [{form}]", entry.get("stringUnit", {}).get("value", "")


def strip_interpolations(literal):
    """The literal without its \\(...) interpolations."""
    return re.sub(r"\\\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)", "", literal)


def swift_key_pattern(literal, swiftui=False):
    """Regex matching the catalog key of a Swift `String(localized: "...")` literal.
    Each interpolation \\(...) becomes any format specifier. A SwiftUI literal without
    interpolations keeps a literal % as is, so either spelling matches there."""
    plain_percent = swiftui and "\\(" not in literal
    out, i = "", 0
    while i < len(literal):
        if literal.startswith("\\(", i):
            depth, j = 1, i + 2
            while depth and j < len(literal):
                depth += {"(": 1, ")": -1}.get(literal[j], 0)
                j += 1
            out += r"%(?:lld|@|lf|d)"
            i = j
        elif literal[i] == "\\" and i + 1 < len(literal):
            out += re.escape({"n": "\n", "t": "\t"}.get(literal[i + 1], literal[i + 1]))
            i += 2
        elif literal[i] == "%":
            out += "%%?" if plain_percent else "%%"
            i += 1
        else:
            out += re.escape(literal[i])
            i += 1
    return re.compile(out + r"\Z")


def main():
    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f)
    errors = []
    keys = catalog.get("strings", {})
    for key, entry in keys.items():
        if entry.get("shouldTranslate") is False:
            continue
        locs = entry.get("localizations", {})
        for lang in REQUIRED:
            if lang not in locs:
                errors.append(f"missing {lang}: {key!r}")
                continue
            for label, value in units(locs[lang]):
                if not value:
                    errors.append(f"empty {lang}{label}: {key!r}")
                elif specifiers(value) != specifiers(key) and "variations" not in locs[lang]:
                    errors.append(f"format mismatch {lang}{label}: {key!r} -> {value!r}")
                elif "variations" in locs[lang] and set(specifiers(value)) - set(specifiers(key)):
                    errors.append(f"format mismatch {lang}{label}: {key!r} -> {value!r}")

    # App Shortcut phrases live in en.lproj/AppShortcuts.strings (macOS 13 has no
    # AppShortcuts.xcstrings); every phrase in Intents.swift needs an English line.
    resources = os.path.dirname(CATALOG)
    table = os.path.join(resources, "en.lproj", "AppShortcuts.strings")
    phrases = set()
    if os.path.exists(table):
        with open(table, encoding="utf-8") as f:
            phrases = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"(?:[^"\\]|\\.)+";', f.read(), re.M))
    intents = os.path.join(ROOT, "Sources/Maramao/App/Intents.swift")
    if os.path.exists(intents):
        with open(intents, encoding="utf-8") as f:
            for phrase in re.findall(r'"((?:[^"\\]|\\.)*\\\(\.applicationName\)(?:[^"\\]|\\.)*)"', f.read()):
                key = phrase.replace("\\(.applicationName)", "${applicationName}")
                if key not in phrases:
                    errors.append(f"App Shortcut phrase missing from en.lproj/AppShortcuts.strings: {key!r}")

    literal = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')
    for folder, _, files in os.walk(os.path.join(ROOT, "Sources")):
        for name in files:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(folder, name)
            rel = os.path.relpath(path, ROOT)
            with open(path, encoding="utf-8") as f:
                for number, line in enumerate(f, 1):
                    if line.lstrip().startswith("//"):
                        continue
                    for match in literal.finditer(line):
                        pattern = swift_key_pattern(match.group(1))
                        if not any(pattern.match(k) for k in keys):
                            errors.append(f"not in the catalog: {rel}:{number} {match.group(1)!r}")
                    for match in SWIFTUI.finditer(line):
                        text = match.group(1)
                        if text in UNTRANSLATED or not re.search(r"[^\W\d_]", strip_interpolations(text)):
                            continue
                        pattern = swift_key_pattern(text, swiftui=True)
                        if not any(pattern.match(k) for k in keys):
                            errors.append(f"SwiftUI literal not in the catalog: {rel}:{number} {text!r}")

    for error in errors:
        print(f"error: {error}")
    if errors:
        print(f"{len(errors)} problem(s) in the String Catalog. New UI strings need an English entry.")
        return 1
    print(f"String Catalog OK: {len(keys)} keys, all translated to {', '.join(REQUIRED)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
