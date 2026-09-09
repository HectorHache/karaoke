#!/usr/bin/env python3
import sys
import os
import json
import importlib.metadata

# 1. Custom file-backed keyring to bypass D-Bus while persisting credentials
import keyring
from keyring.backend import KeyringBackend

class SimpleFileKeyring(KeyringBackend):
    priority = 10

    def __init__(self):
        self.filepath = os.path.expanduser("~/.config/usdb_syncer/credentials.json")
        os.makedirs(os.path.dirname(self.filepath), exist_ok=True)

    def _read(self):
        if os.path.isfile(self.filepath):
            try:
                with open(self.filepath, "r") as f:
                    return json.load(f)
            except Exception:
                return {}
        return {}

    def _write(self, data):
        # Enforce strict 0600 read/write permissions for user only
        flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
        mode = 0o600
        with open(os.open(self.filepath, flags, mode), "w") as f:
            json.dump(data, f)

    def get_password(self, service, username):
        key = f"{service}::{username}"
        return self._read().get(key)

    def set_password(self, service, username, password):
        data = self._read()
        key = f"{service}::{username}"
        data[key] = password
        self._write(data)

    def delete_password(self, service, username):
        data = self._read()
        key = f"{service}::{username}"
        if key in data:
            del data[key]
            self._write(data)

keyring.set_keyring(SimpleFileKeyring())

# 2. Mock QtMultimedia to neutralize FFmpeg device probing deadlocks
from PySide6 import QtCore, QtMultimedia

class MockSignal:
    def connect(self, *args, **kwargs): return None
    def disconnect(self, *args, **kwargs): return None
    def emit(self, *args, **kwargs): return None
    def __call__(self, *args, **kwargs): return None

class MockMediaBase(QtCore.QObject):
    def __init__(self, parent=None, *args, **kwargs):
        super().__init__(parent)
    def __getattr__(self, name):
        return MockSignal()

class MockMediaPlayer(MockMediaBase):
    if hasattr(QtMultimedia.QMediaPlayer, "PlaybackState"):
        PlaybackState = QtMultimedia.QMediaPlayer.PlaybackState

    def playbackState(self):
        if hasattr(self, "PlaybackState") and hasattr(self.PlaybackState, "StoppedState"):
            return self.PlaybackState.StoppedState
        return 0

    def position(self): return 0
    def duration(self): return 0
    def setAudioOutput(self, *args, **kwargs): pass
    def setSource(self, *args, **kwargs): pass
    def play(self, *args, **kwargs): pass
    def pause(self, *args, **kwargs): pass
    def stop(self, *args, **kwargs): pass
    def setPosition(self, *args, **kwargs): pass

class MockAudioOutput(MockMediaBase):
    def volume(self): return 1.0
    def isMuted(self): return False
    def setVolume(self, *args, **kwargs): pass
    def setMuted(self, *args, **kwargs): pass

QtMultimedia.QMediaPlayer = MockMediaPlayer
QtMultimedia.QAudioOutput = MockAudioOutput
QtMultimedia.QMediaDevices = MockMediaBase

# 3. Resolve entrypoint dynamically
entry_func = None
try:
    eps = importlib.metadata.entry_points()
    if hasattr(eps, "select"):
        scripts = eps.select(group="console_scripts")
    elif isinstance(eps, dict):
        scripts = eps.get("console_scripts", [])
    else:
        scripts = [e for e in eps if getattr(e, "group", None) == "console_scripts"]

    for ep in scripts:
        if ep.name == "usdb_syncer":
            entry_func = ep.load()
            break
except Exception:
    pass

if not entry_func:
    try:
        from usdb_syncer.gui import main as entry_func
    except ImportError:
        from usdb_syncer.main import main as entry_func

if __name__ == "__main__":
    sys.exit(entry_func())