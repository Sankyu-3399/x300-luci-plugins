# SPDX-License-Identifier: Apache-2.0

include $(TOPDIR)/rules.mk

PKG_NAME:=modem-dashboard
PKG_VERSION:=1.0.1
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Codex

LUCI_TITLE:=Modem Dashboard
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all
LUCI_MINIFY_CSS:=0
LUCI_SUBMENU_FORCED:=none

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
