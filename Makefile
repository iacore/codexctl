.DEFAULT_GOAL := all
FW_VERSION := 2.15.1.1189
FW_DATA := wVbHkgKisg-
IMG_SHA := fc7d145e18f14a1a3f435f2fd5ca5924fe8dfe59bf45605dc540deed59551ae4
LS_DATA := ". .. lost+found bin boot dev etc home lib media mnt postinst proc run sbin sys tmp uboot-postinst uboot-version usr var "
CAT_DATA := 20221026104022
SHELL := /bin/bash

ifeq ($(VENV_BIN_ACTIVATE),)
VENV_BIN_ACTIVATE := .venv/bin/activate
endif

OBJ := $(shell find codexctl -type f | grep -v __pycache__)
OBJ += $(shell find data -type f)
OBJ += README.md

$(VENV_BIN_ACTIVATE): requirements.remote.txt requirements.txt
	@echo "[info] Setting up development virtual env in .venv"
	python -m venv .venv
	. $(VENV_BIN_ACTIVATE); \
	python -m pip install wheel
	@echo "[info] Installing dependencies"
	. $(VENV_BIN_ACTIVATE); \
	python -m pip install \
	    --extra-index-url=https://wheels.eeems.codes/ \
	    -r requirements.remote.txt

.venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed: $(VENV_BIN_ACTIVATE) $(OBJ)
	@echo "[info] Downloading remarkable update file"
	. $(VENV_BIN_ACTIVATE); \
	python -m codexctl download --out .venv ${FW_VERSION}

test: $(VENV_BIN_ACTIVATE) .venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed
	@echo "[info] Running test"
	. $(VENV_BIN_ACTIVATE); \
	python test.py
	if [ -d .venv/mnt ] && mountpoint -q .venv/mnt; then \
	    umount -ql .venv/mnt; \
	fi
	mkdir -p .venv/mnt
	. $(VENV_BIN_ACTIVATE); \
	if [[ "linux" == "$$(python -c 'import sys;print(sys.platform)')" ]]; then \
	  python -m codexctl mount --out .venv/mnt ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed"; \
	  mountpoint .venv/mnt; \
	  umount -ql .venv/mnt; \
	  python -m codexctl extract --out ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.img" ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed"; \
	  echo "${IMG_SHA}  .venv/${FW_VERSION}_reMarkable2-${FW_DATA}.img" | sha256sum --check; \
	  rm -f ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.img"; \
	fi; \
	if ! diff --color <(python -m codexctl ls ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed" /) <(echo ${LS_DATA}) | cat -te; then \
	  echo "codexctl ls failed test"; \
	  exit 1; \
	fi; \
	if ! diff --color <(python -m codexctl cat ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed" /etc/version) <(echo ${CAT_DATA}) | cat -te; then \
	  echo "codexctl cat failed test"; \
	  exit 1; \
	fi

test-executable: .venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed
	. $(VENV_BIN_ACTIVATE); \
	if [[ "linux" == "$$(python -c 'import sys;print(sys.platform)')" ]]; then \
	  dist/codexctl.* extract --out ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.img" ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed"; \
	  echo "${IMG_SHA}  .venv/${FW_VERSION}_reMarkable2-${FW_DATA}.img" | sha256sum --check; \
	  rm -f ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.img"; \
	fi
	if ! diff --color <(dist/codexctl.* ls ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed" /) <(echo ${LS_DATA}) | cat -te; then \
	  echo "codexctl ls failed test"; \
	  exit 1; \
	fi
	if ! diff --color <(dist/codexctl.* cat ".venv/${FW_VERSION}_reMarkable2-${FW_DATA}.signed" /etc/version) <(echo ${CAT_DATA}) | cat -te; then \
	  echo "codexctl cat failed test"; \
	  exit 1; \
	fi

clean:
	@echo "[info] Cleaning"
	if [ -d .venv/mnt ] && mountpoint -q .venv/mnt; then \
		umount -ql .venv/mnt; \
	fi
	git clean --force -dX

executable: $(VENV_BIN_ACTIVATE)
	@echo "[info] Installing Nuitka"
	. $(VENV_BIN_ACTIVATE); \
	python -m pip install --extra-index-url=https://wheels.eeems.codes/ nuitka
	@echo "[info] Building codexctl"
	. $(VENV_BIN_ACTIVATE); \
	NUITKA_CACHE_DIR="$(realpath .)/.nuitka" \
	python -m nuitka \
	    --assume-yes-for-downloads \
	    --remove-output \
	    --output-dir=dist \
	    --report=compilation-report.xml \
	    codexctl.py
	if [ -d dist/codexctl.build ]; then \
	    rm -r dist/codexctl.build; \
	fi
	@echo "[info] Sanity check"
	dist/codexctl.* --help

all: executable

.PHONY: \
	all \
	executable \
	clean \
	test \
	test-executable
