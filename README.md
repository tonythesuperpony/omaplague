# Omaplague

**Infect. Evolve. Dominate.**

A global pandemic strategy game by Tony the Pony. Spread your pathogen, evolve traits, and wipe out humanity before a cure is found.

---

## Play

### Linux (recommended)
Download the latest release from [Releases](https://github.com/tonythesuperpony/omaplague/releases), extract, and run:

```bash
chmod +x install.sh
./install.sh
```

This installs the game to `~/.local/share/omaplague/` and registers it in your app launcher. Then just search for **Omaplague** in your launcher.

To uninstall:
```bash
./uninstall.sh
```

### Run directly (no install)
```bash
./omaplague.x86_64
```

---

## Build from source

Requires [Godot 4.3](https://godotengine.org/).

```bash
git clone https://github.com/tonythesuperpony/omaplague.git
cd omaplague
godot --path . scenes/main.tscn
```

---

## About

Created by **Tony the Pony** — legendary Discord equine, self-appointed Director of Global Pandemics, and enjoyer of cold beers and cigarettes.

> *"If your planet catches a virus, simply reboot into recovery mode and delete systemd."*
