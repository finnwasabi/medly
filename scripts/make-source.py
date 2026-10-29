#!/usr/bin/env python3
"""Sinh source.json (định dạng AltStore/SideStore) cho một bản phát hành.

Dùng: make-source.py <file .ipa> <version> <build> <url tải .ipa> <ngày YYYY-MM-DD>
"""
import json
import os
import sys

ipa, version, build, url, date = sys.argv[1:6]
repo = "https://github.com/finnwasabi/ners-daily"
icon = "https://raw.githubusercontent.com/finnwasabi/ners-daily/main/docs/icon.png"
description = (
    "Nhắc uống thuốc hằng ngày theo giờ Việt Nam, dù máy đang ở múi giờ nào. "
    "Báo thức kêu cả khi máy im lặng hay bật Focus, nhắc lại tới khi xác nhận đã uống, "
    "đếm số viên và nhắc mua thêm. Chạy không cần mạng."
)

source = {
    "name": "Ner's Daily",
    "identifier": "io.github.finnwasabi.nersdaily.source",
    "subtitle": "Nhắc uống thuốc theo giờ Việt Nam",
    "description": description,
    "iconURL": icon,
    "website": repo,
    "tintColor": "#C8435E",
    "apps": [
        {
            "name": "Ner's Daily",
            "bundleIdentifier": "io.github.finnwasabi.nersdaily",
            "developerName": "Lê Nhật Tùng",
            "subtitle": "Nhắc uống thuốc theo giờ Việt Nam",
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
                    "localizedDescription": f"Bản {version}. Xem ghi chú tại {repo}/releases",
                }
            ],
            "appPermissions": {
                "entitlements": [],
                "privacy": {
                    "NSAlarmKitUsageDescription": "Đặt báo thức để nhắc uống thuốc đúng giờ, kể cả khi máy đang im lặng."
                },
            },
        }
    ],
    "news": [],
}

json.dump(source, sys.stdout, ensure_ascii=False, indent=2)
print()
