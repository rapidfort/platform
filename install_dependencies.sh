#!/bin/bash -e
# shellcheck disable=SC1091

YQ_RELEASE=v4.44.3
KIND_RELEASE=v0.24.0
HELM_RELEASE=v3.15.4
KUBECTL_RELEASE=v1.35.1

source .pretty_print

get_os_str()
{
    # works on all posix shell
    local _os
    _os="$(uname)"
    echo -n "$(echo "${_os}" | tr '[:upper:]' '[:lower:]')"
}

get_architecture()
{
    local _arch
    _arch="$(uname -m)"
    if [ "${_arch}" = "aarch64" ] || [ "${_arch}" = "arm64" ]; then
        echo -n "arm64"
    elif [ "${_arch}" = "amd64" ] || [ "${_arch}" = "x86_64" ]; then
        echo -n "amd64"
    else
        print_bred "ERROR: $(get_os_str): ${_arch} not supported."
        exit 1
    fi
}

get_architecture_alt()
{
    if [ "$(get_architecture)" = "arm64" ]; then
        echo -n "aarch64"
    else
        echo -n "x86_64"
    fi
}

docker_install() {
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh

    print_bgreen "Enabling and starting Docker"

    # systemd-based distros (RHEL8, Ubuntu, etc.)
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || true
        systemctl enable --now docker || true
    fi

    # If running rootless or docker group usage is desired, uncomment:
    # if [ -n "${SUDO_USER:-}" ]; then
    #     usermod -aG docker "${SUDO_USER}" || true
    #     print_bgreen "Added ${SUDO_USER} to docker group (re-login required)"
    # fi
}

yq_install() {
    print_bgreen "Installing yq"
    URL=https://github.com/mikefarah/yq/releases/download/${YQ_RELEASE}/yq_"$(get_os_str)"_"$(get_architecture)"
    if ! curl --output /dev/null --silent --head --fail -L "$URL"; then
        URL=https://github.com/mikefarah/yq/releases/download/${YQ_RELEASE}/yq_"$(get_os_str)"_"$(get_architecture_alt)"
    fi

    curl -Lo /usr/local/bin/yq "${URL}"
    chmod +x /usr/local/bin/yq
}

kind_install() {
    print_bgreen "Installing kind"
    URL=https://kind.sigs.k8s.io/dl/${KIND_RELEASE}/kind-"$(get_os_str)"-"$(get_architecture)"
    if ! curl --output /dev/null --silent --head --fail -L "${URL}"; then
        URL=https://kind.sigs.k8s.io/dl/${KIND_RELEASE}/kind-"$(get_os_str)"-"$(get_architecture_alt)"
    fi
    curl -Lo /usr/local/bin/kind "${URL}"
    chmod +x /usr/local/bin/kind
}

helm_install() {
    print_bgreen "Installing helm"
    URL=https://get.helm.sh/helm-${HELM_RELEASE}-"$(get_os_str)"-"$(get_architecture)".tar.gz
    if ! curl --output /dev/null --silent --head --fail -L "$URL"; then
        URL=https://get.helm.sh/helm-${HELM_RELEASE}-"$(get_os_str)"-"$(get_architecture_alt)".tar.gz
    fi
    curl -Lo helm-${HELM_RELEASE}-"$(get_os_str)"-"$(get_architecture)".tar.gz "${URL}"
    tar zxvf helm-${HELM_RELEASE}-"$(get_os_str)"-"$(get_architecture)".tar.gz
    mv -vf "$(get_os_str)"-"$(get_architecture)"/helm /usr/local/bin
    rm -rf "$(get_os_str)"-"$(get_architecture)"
    rm -f helm-${HELM_RELEASE}-"$(get_os_str)"-"$(get_architecture)".tar.gz
}

kubectl_install() {
    print_bgreen "Installing kubectl (${KUBECTL_RELEASE})"

    local os arch url tmp
    os="$(get_os_str)"
    arch="$(get_architecture)"   # amd64|arm64
    url="https://dl.k8s.io/release/${KUBECTL_RELEASE}/bin/${os}/${arch}/kubectl"

    tmp="$(mktemp)"
    curl -fL --connect-timeout 10 --max-time 120 -o "${tmp}" "${url}"

    # Guard against downloading an error page
    if head -c 5 "${tmp}" | grep -q '^<?xml'; then
        print_bred "ERROR: Downloaded XML error instead of kubectl from ${url}"
        rm -f "${tmp}"
        exit 1
    fi

    install -m 0755 "${tmp}" /usr/local/bin/kubectl
    rm -f "${tmp}"
}

debian_init() {
    export TZ="/usr/share/zoneinfo/America/Los_Angeles"
    export LC_ALL="C"
    export DEBIAN_FRONTEND=noninteractive
    apt update
    # Please keep it sorted
    apt install -y curl jq python3
}

rhel_init() {
    export TZ="/usr/share/zoneinfo/America/Los_Angeles"
    export LC_ALL="C"

    # Update metadata/packages
    dnf -y makecache
    dnf -y update || true

    # EPEL is commonly required for jq on RHEL-family distros
    if ! rpm -q epel-release >/dev/null 2>&1; then
        dnf -y install epel-release || true
    fi

    # Please keep it sorted
    dnf -y install curl jq python3
}

is_rhel_like() {
    # Use os-release fields: ID, ID_LIKE (space-separated)
    # shellcheck disable=SC2154
    if [ "${ID}" = "rhel" ] || [ "${ID}" = "centos" ] || [ "${ID}" = "rocky" ] || [ "${ID}" = "almalinux" ] || [ "${ID}" = "fedora" ]; then
        return 0
    fi
    if echo " ${ID_LIKE:-} " | grep -qE ' rhel | fedora | centos '; then
        return 0
    fi
    return 1
}

init() {
    local update
    if [ "$1" = "update" ]; then
        update=true
    fi

    if [ "$(get_os_str)" = "linux" ]; then
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
                debian_init
            elif is_rhel_like; then
                # RHEL 8 support (and other RHEL-like distros)
                rhel_init
            else
                print_bred "NotSupported: $ID $(get_os_str) $(get_architecture) To Do"
                exit 1
            fi

            if [ $update ] || [ -z "$(command -v docker)" ]; then
                docker_install
            fi

            if [ $update ] || [ -z "$(command -v helm)" ]; then
                helm_install
            fi

            if [ $update ] || [ -z "$(command -v kind)" ]; then
                kind_install
            fi

            if [ $update ] || [ -z "$(command -v yq)" ]; then
                yq_install
            fi

            if [ $update ] || [ -z "$(command -v kubectl)" ]; then
                kubectl_install
            fi
        fi
    elif [ "$(get_os_str)" = "darwin" ]; then
        print_bred "MacOSX: To Do"
        exit 1
    else
        print_bred "NotSupported: $(get_os_str) $(get_architecture) To Do"
        exit 1
    fi

    # install aliases
    for f in .kubectl_aliases
    do
        cp -f $f ~
    done
}

init "${1}"

