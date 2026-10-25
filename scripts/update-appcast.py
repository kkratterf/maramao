#!/usr/bin/env python3
"""Adds a release to the Sparkle appcast (site/appcast.xml by default).

Usage:
  scripts/update-appcast.py --version 0.2.0 --url <zip url> \
      --signature '<output of sign_update>' [--appcast site/appcast.xml]

`--signature` takes the line Sparkle's sign_update prints for the zip:
  sparkle:edSignature="..." length="..."

The newest release goes first. An existing entry for the same version is
replaced, so re-running a release is safe. Only the newest --keep entries
are kept. Standard library only, so it runs on a bare macOS runner.
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from email.utils import formatdate

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"
REPO_URL = "https://github.com/kkratterf/maramao"

ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)


def sparkle(tag):
    return "{%s}%s" % (SPARKLE_NS, tag)


def parse_signature(text):
    """Returns (edSignature, length) from sign_update's output."""
    signature = re.search(r'sparkle:edSignature="([^"]+)"', text)
    length = re.search(r'length="(\d+)"', text)
    if not signature or not length:
        raise ValueError("unexpected sign_update output: %r" % text)
    return signature.group(1), length.group(1)


def new_feed():
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Maramao"
    ET.SubElement(channel, "link").text = REPO_URL
    ET.SubElement(channel, "description").text = "Aggiornamenti di Maramao"
    ET.SubElement(channel, "language").text = "it"
    return ET.ElementTree(rss)


def load_feed(path):
    try:
        tree = ET.parse(path)
    except FileNotFoundError:
        return new_feed()
    if tree.getroot().find("channel") is None:
        raise ValueError("%s has no <channel>" % path)
    return tree


def add_release(tree, version, url, signature, length, minimum_system, keep, pub_date=None):
    channel = tree.getroot().find("channel")
    # Drop an older entry for the same version.
    for item in channel.findall("item"):
        existing = item.find(sparkle("version"))
        if existing is not None and (existing.text or "").strip() == version:
            channel.remove(item)

    tag = "v" + version
    item = ET.Element("item")
    ET.SubElement(item, "title").text = "Maramao %s" % version
    ET.SubElement(item, "pubDate").text = pub_date or formatdate(usegmt=True)
    ET.SubElement(item, "link").text = "%s/releases/tag/%s" % (REPO_URL, tag)
    ET.SubElement(item, sparkle("version")).text = version
    ET.SubElement(item, sparkle("shortVersionString")).text = version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = minimum_system
    ET.SubElement(item, sparkle("fullReleaseNotesLink")).text = "%s/releases/tag/%s" % (REPO_URL, tag)
    ET.SubElement(item, "enclosure", {
        "url": url,
        "length": length,
        "type": "application/octet-stream",
        sparkle("edSignature"): signature,
    })

    # Insert before the first existing item, after the channel metadata.
    children = list(channel)
    position = len(children)
    for index, child in enumerate(children):
        if child.tag == "item":
            position = index
            break
    channel.insert(position, item)

    items = channel.findall("item")
    for old in items[keep:]:
        channel.remove(old)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--appcast", default="site/appcast.xml")
    parser.add_argument("--version", required=True, help="CFBundleShortVersionString, e.g. 0.2.0")
    parser.add_argument("--url", required=True, help="download URL of the signed zip")
    parser.add_argument("--signature", required=True, help="sign_update output for the zip")
    parser.add_argument("--minimum-system", default="13.0")
    parser.add_argument("--keep", type=int, default=10, help="entries to keep (default 10)")
    args = parser.parse_args(argv)

    signature, length = parse_signature(args.signature)
    tree = load_feed(args.appcast)
    add_release(tree, args.version, args.url, signature, length, args.minimum_system, max(1, args.keep))
    ET.indent(tree, space="  ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    with open(args.appcast, "a", encoding="utf-8") as handle:
        handle.write("\n")
    print("update-appcast: added Maramao %s to %s" % (args.version, args.appcast))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except ValueError as error:
        print("update-appcast: %s" % error, file=sys.stderr)
        sys.exit(1)
