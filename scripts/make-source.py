#!/usr/bin/env python3
"""Generates source.json (AltStore/SideStore format) for a release.

Usage: make-source.py <ipa file> <version> <build> <ipa download url> <date YYYY-MM-DD>
"""
import json
import os
import sys

ipa, version, build, url, date = sys.argv[1:6]
repo = "https://github.com/finnwasabi/ners-daily"
icon = "https://raw.githubusercontent.com/finnwasabi/ners-daily/main/docs/icon.png"
description = (
    "A daily pill reminder that always runs on Vietnam time, whatever time zone the phone is in. "
    "Alarms ring on silent and in Focus and keep reminding until the dose is confirmed. "
    "Optional pill counting with refill reminders. Works offline. Vietnamese and English."
)

source = {
    "name": "Ner's Daily",
    "identifier": "io.github.finnwasabi.nersdaily.source",
    "subtitle": "Daily pill reminder on Vietnam time",
    "description": description,
    "iconURL": icon,
    "website": repo,
    "tintColor": "#C8435E",
    "apps": [
        {
            "name": "Ner's Daily",
            "bundleIdentifier": "io.github.finnwasabi.nersdaily",
            "developerName": "Lê Nhật Tùng",
            "subtitle": "Daily pill reminder on Vietnam time",
            "localizedDescription": description,
            "iconURL": icon,
            "tintColor": "#C8435E",
            "category": "utilities",
            "screenshots": [],
            "versions": [
                {
                    "version": version,
                    "buildVersion": build,
                    "date": date,
                    "size": os.path.getsize(ipa),
                    "downloadURL": url,
                    "minOSVersion": "26.0",
                    "localizedDescription": f"Version {version}. Release notes: {repo}/releases",
                }
            ],
            "appPermissions": {
                "entitlements": [],
                "privacy": {
                    "NSAlarmKitUsageDescription": "Sets alarms to remind you to take your pill on time, even when your phone is on silent."
                },
            },
        }
    ],
    "news": [],
}

json.dump(source, sys.stdout, ensure_ascii=False, indent=2)
print()
