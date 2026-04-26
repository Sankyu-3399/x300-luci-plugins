# SPDX-License-Identifier: Apache-2.0

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-x300_status
PKG_VERSION:=1.0.1
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Codex

LUCI_TITLE:=X300 Status for Overview
LUCI_DEPENDS:=+luci-base +luci-mod-status
LUCI_PKGARCH:=all
LUCI_SUBMENU_FORCED:=none

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
