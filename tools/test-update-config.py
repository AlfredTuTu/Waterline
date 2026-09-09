#!/usr/bin/env python3
import base64
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('update_config', Path(__file__).with_name('check-update-config.py'))
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class UpdateConfigTests(unittest.TestCase):
    def test_missing_or_weakened_release_config_is_rejected(self):
        # Synthetic bytes: structural validation cannot establish signing-key ownership.
        valid = {
            'SUFeedURL': 'https://github.com/AlfredTuTu/Waterline/releases/latest/download/appcast.xml',
            'SUPublicEDKey': base64.b64encode(bytes(range(32))).decode(),
            'SURequireSignedFeed': True, 'SUVerifyUpdateBeforeExtraction': True,
            'SUEnableAutomaticChecks': False, 'SUAllowsAutomaticUpdates': False,
            'SUEnableSystemProfiling': False, 'SUShowReleaseNotes': False,
        }
        policy.validate(valid)
        for key in valid:
            changed = dict(valid)
            del changed[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                policy.validate(changed)
            if isinstance(valid[key], bool):
                changed[key] = not valid[key]
                with self.subTest(changed=key), self.assertRaises(ValueError):
                    policy.validate(changed)
        for key in ['not-base64', base64.b64encode(bytes(31)).decode()]:
            with self.assertRaises(ValueError):
                policy.validate(dict(valid, SUPublicEDKey=key))
        with self.assertRaises(ValueError):
            policy.validate(dict(valid, SUFeedURL='https://example.test/appcast.xml'))


if __name__ == '__main__':
    unittest.main()
