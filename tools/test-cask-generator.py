#!/usr/bin/env python3
import importlib.util
import pathlib
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("cask_generator", pathlib.Path(__file__).with_name("generate-cask.py"))
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CaskGeneratorTests(unittest.TestCase):
    def test_generated_cask_is_ruby_and_matches_actual_architecture(self):
        url = "https://github.com/AlfredTuTu/Waterline/releases/download/v1.2.3/Waterline-1.2.3-arm64.dmg"
        text = generator.render("1.2.3", "a" * 64, url, ["arm64"])
        self.assertIn("depends_on arch: :arm64", text)
        self.assertNotIn("auto_updates", text)
        self.assertIn('binary "#{appdir}/Waterline.app/Contents/MacOS/waterline"', text)
        with tempfile.NamedTemporaryFile(suffix=".rb", mode="w") as output:
            output.write(text)
            output.flush()
            subprocess.run(["ruby", "-c", output.name], check=True, capture_output=True)

    def test_invalid_versions_urls_and_architectures_are_rejected(self):
        valid = "https://github.com/AlfredTuTu/Waterline/releases/download/v1.2.3/Waterline-1.2.3.dmg"
        for url in [valid.replace("https:", "http:"), valid.replace("AlfredTuTu", "Other"), valid + "#fragment", valid + '?q=1', valid.replace("1.2.3/", "1.2.4/")]:
            with self.assertRaises(ValueError):
                generator.render("1.2.3", "a" * 64, url, ["arm64"])
        for version in ["0.1.0-dev", "latest", '1.2.3"']:
            with self.assertRaises(ValueError):
                generator.render(version, "a" * 64, valid, ["arm64"])
        with self.assertRaises(ValueError):
            generator.render("1.2.3", "no_check", valid, ["arm64"])
        with self.assertRaises(ValueError):
            generator.render("1.2.3", "a" * 64, valid, ["unknown"])


if __name__ == "__main__":
    unittest.main()
