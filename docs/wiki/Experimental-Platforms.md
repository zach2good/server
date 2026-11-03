# Experimental Platforms

These platforms should work, but the development team doesn't use or test them, and may not be able to help you debug them. Read the [Quick Start Guide](Quick-Start-Guide) first. Apart from the notes below, the Ubuntu steps apply.

_(click a section to expand it)_

<details>
<summary><b>macOS (bare metal)</b></summary>

Use [Docker](https://github.com/LandSandBoat/server/blob/base/docker/README.md) if you can. On bare metal you'll be debugging any Homebrew, linker or LuaJIT problem yourself.

```sh
brew install git pkg-config cmake ninja openssl mariadb zeromq luajit
git clone --recursive https://github.com/LandSandBoat/server.git
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements.txt
python3 ./tools/build.py
```

Build with Apple Clang from the Xcode command line tools. Set up the database as in the Ubuntu section.

</details>

<details>
<summary><b>Linux (WSL)</b></summary>

The Ubuntu steps work under WSL. [Working with WSL](Working-with-WSL) covers the extra points.

</details>

<details>
<summary><b>Linux (Arch)</b></summary>

Nobody has tried this in a long time. It's probably out of date.

```sh
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git python python-pip gcc cmake ninja pkgconf luajit zeromq openssl zlib zstd libdwarf mariadb binutils
sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
sudo systemctl enable --now mariadb
```

Arch marks its system Python as externally managed, so use a virtual environment as on Ubuntu.

</details>

<details>
<summary><b>Linux (Raspberry Pi)</b></summary>

Nobody has tried this in a long time. It's probably out of date.

* **Power:** use a supply of at least 2.5 A. A yellow lightning bolt in the corner of the display means the Pi is throttling, and the build may take far longer or never finish.
* **RAM:** start the server processes one at a time if the Pi runs out of memory.
* **LuaJIT:** your distribution's package may lack ARM fixes. If LuaJIT gives you trouble, build it from source:

  ```sh
  git clone https://github.com/LuaJIT/LuaJIT.git
  cd LuaJIT
  sudo make install -j $(nproc)
  ```

  Check that `/usr/local/bin/luajit` exists afterwards, and create the symlink yourself if it doesn't.

</details>

<details>
<summary><b>Linux (Gentoo OpenRC)</b></summary>

Nobody has tried this in a long time. It's probably out of date.

```sh
sudo emerge --sync && sudo emerge -avuDU @world
sudo emerge -a dev-build/cmake dev-build/ninja dev-db/mariadb dev-lang/luajit dev-vcs/git net-libs/zeromq
sudo emerge --config dev-db/mariadb
sudo rc-update add mysql default
sudo rc-service mysql start
```

For systemd, or if MariaDB gives you trouble, see the [Gentoo Wiki](https://wiki.gentoo.org/wiki/MariaDB).

Installing the Python requirements with `pip` outside a virtual environment can break a Gentoo system. Either use a venv as on Ubuntu, or emerge a `dev-python/*` atom for every package in `tools/requirements.txt`. Some atoms are only in the [claytabase](https://github.com/claybie/claytabase) overlay:

```sh
sudo eselect repository add claytabase git https://github.com/claybie/claytabase.git
sudo emaint sync -r claytabase
```

Portage names don't always match PyPI names, so search with `emerge -s` when a guess fails.

</details>
