#!/usr/bin/env python3
"""Generates source.json (AltStore/SideStore format) for a release.

Usage: make-source.py <ipa file> <version> <build> <ipa download url> <date YYYY-MM-DD>
"""
import json
import os
import sys

ipa, version, build, url, date = sys.argv[1:6]
repo = "https://github.com/finnwasabi/medly"
icon = "https://raw.githubusercontent.com/finnwasabi/medly/main/docs/icon.png"
description = (
    "A cute medication reminder that always runs on Vietnam time, whatever time zone the phone is in. "
    "Several medications, each with its own times, maximum gap, days off and pill count. "
    "Alarms ring on silent and in Focus and keep going until the dose is taken or skipped. "
    "Backups, a widget and a Shortcut. Works offline. Vietnamese and English."
)

source = {
    "name": "Medly",
    "identifier": "io.github.finnwasabi.nersdaily.source",
    "subtitle": "Medication reminders on Vietnam time",
    "description": description,
    "iconURL": icon,
    "website": repo,
    "tintColor": "#FF8FC0",
    "apps": [
        {
            "name": "Medly",
            "bundleIdentifier": "io.github.finnwasabi.nersdaily",
            "developerName": "Lê Nhật Tùng",
            "subtitle": "Medication reminders on Vietnam time",
            "localizedDescription": description,
            "iconURL": icon,
            "tintColor": "#FF8FC0",
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
                "entitlements": ["com.apple.security.application-groups"],
                "privacy": {
                    "NSAlarmKitUsageDescription": "Sets alarms to remind you to take your medication on time, even when your phone is on silent."
                },
            },
        }
    ],
    "news": [],
}

json.dump(source, sys.stdout, ensure_ascii=False, indent=2)
print()
