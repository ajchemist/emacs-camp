"""Activation steps of the Home Manager module, run against a scratch HOME.

python3 ci/test_activation.py   (needs nix; evaluates the module via basecamp)
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

FLAKE = Path(__file__).resolve().parents[1]


def activation(name):
    expr = (f'let f = builtins.getFlake "path:{FLAKE}"; '
            f'c = (f.inputs.basecamp.lib.mkHome {{ user = "fixture"; emacs = "nox"; system = builtins.currentSystem; '
            f'modules = [ f.homeModules.default ]; }}).config; '
            f'in c.home.activation.{name}.data')
    text = subprocess.run(['nix', 'eval', '--impure', '--raw', '--expr', expr],
                          check=True, capture_output=True, text=True).stdout
    for path in {w for w in text.split() if w.startswith('/nix/store/')}:
        subprocess.run(['nix-store', '--realise', path.split('/bin/')[0]],
                       check=True, capture_output=True)
    return text


def bash(script, home):
    subprocess.run(['bash', '-euo', 'pipefail', '-c', 'run() { "$@"; }\n' + script],
                   check=True, env=dict(os.environ, HOME=str(home)), capture_output=True)


class Legacy(unittest.TestCase):
    def test_recurring_files_directories_and_symlinks(self):
        script = activation('emacsCampLegacy')
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            legacy, legacy_dir = home / '.emacs', home / '.emacs.d'
            for version in ('first', 'second'):
                legacy.write_text(version)
                legacy_dir.mkdir()
                (legacy_dir / 'init.el').write_text(version)
                bash(script, home)
                self.assertFalse(legacy.exists())
                self.assertFalse(legacy_dir.exists())
            self.assertEqual((home / '.emacs.before-emacs-camp').read_text(), 'second')
            self.assertEqual((home / '.emacs.before-emacs-camp.~1~').read_text(), 'first')
            self.assertEqual((home / '.emacs.d.before-emacs-camp/init.el').read_text(), 'second')
            self.assertEqual((home / '.emacs.d.before-emacs-camp.~1~/init.el').read_text(), 'first')
            target = home / 'unmanaged.el'
            target.write_text('keep')
            legacy.symlink_to(target)
            legacy_dir.symlink_to(home / 'missing')
            bash(script, home)
            self.assertFalse(legacy.is_symlink())
            self.assertFalse(legacy_dir.is_symlink())
            self.assertEqual(target.read_text(), 'keep')
            self.assertTrue((home / '.emacs.before-emacs-camp').is_symlink())
            bash(script, home)  # nothing left to move: a no-op


if __name__ == '__main__':
    unittest.main()
