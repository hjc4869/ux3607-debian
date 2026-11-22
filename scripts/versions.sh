#!/usr/bin/env bash
# Pinned inputs and package versions shared by the build scripts.
# Sourced, not executed. Bump the matching package revision when an input changes.
# shellcheck disable=SC2034

# Linux stable release used as the patch base.
kernel_tag=v7.3.4
kernel_commit=7595a62d45ee1a2297eafa5f2ef5d0a45142d84d
kernel_git_url=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
kernel_release=7.3.4-ux3607oa
kernel_package_version=7.3.4-1+ux3607oa1

# Debian's own configuration for the same upstream release.
debian_config_package=linux-config-7.3_7.3.4-1_arm64.deb
debian_config_sha256=cac059543a40e3c0aa5a126676d00d82d92f7f8c2873ad2f6d3bddf831be25c3
debian_config_member=usr/src/linux-config-7.3/config.arm64_none_arm64.xz
debian_config_name=debian-arm64-7.3.4-1.config

support_package_version=1.0-7
firmware_package_version=1.312.4500.0-3
