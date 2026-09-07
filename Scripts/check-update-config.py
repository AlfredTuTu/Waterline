#!/usr/bin/env python3
"""Read-only release gate; encoding checks do not prove key ownership or a signed update."""
import base64
import binascii
import plistlib
import sys
from pathlib import Path


def validate(info):
    if info.get('SUFeedURL') != 'https://github.com/AlfredTuTu/Waterline/releases/latest/download/appcast.xml':
        raise ValueError('release feed URL is missing or unsupported')
    key = info.get('SUPublicEDKey')
    try:
        if not isinstance(key, str) or len(base64.b64decode(key, validate=True)) != 32:
            raise ValueError('release public key must encode 32 bytes')
    except (binascii.Error, UnicodeEncodeError) as error:
        raise ValueError('release public key encoding is invalid') from error
    for name, expected in {
        'SURequireSignedFeed': True, 'SUVerifyUpdateBeforeExtraction': True,
        'SUEnableAutomaticChecks': False, 'SUAllowsAutomaticUpdates': False,
        'SUEnableSystemProfiling': False, 'SUShowReleaseNotes': False,
    }.items():
        if info.get(name) is not expected:
            raise ValueError(f'{name} does not match the release policy')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('usage: check-update-config.py APP')
        with (Path(sys.argv[1]) / 'Contents/Info.plist').open('rb') as source:
            validate(plistlib.load(source))
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        print(f'FAIL: update configuration: {error}', file=sys.stderr)
        sys.exit(1)
    print('PASS: update configuration (signed delivery still requires live acceptance)')
