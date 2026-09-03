#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-install}"

if (( EUID != 0 )); then
    echo "root 권한이 필요합니다: sudo $0 ${ACTION}" >&2
    exit 1
fi

install_fix() {
    install -d -m 0755 /etc/zotac-sleep-fix
    install -m 0755 "$SCRIPT_DIR/zotac-sleep-fix" /etc/zotac-sleep-fix/apply
    install -m 0755 "$SCRIPT_DIR/zotac-iommu-persist" \
        /etc/zotac-sleep-fix/iommu
    install -m 0644 "$SCRIPT_DIR/99-zotac-zone-sleep.rules" \
        /etc/udev/rules.d/99-zotac-zone-sleep.rules
    install -m 0644 "$SCRIPT_DIR/zotac-wakeup-fix.service" \
        /etc/systemd/system/zotac-wakeup-fix.service
    install -m 0644 "$SCRIPT_DIR/zotac-sleep-measure.service" \
        /etc/systemd/system/zotac-sleep-measure.service

    systemctl daemon-reload
    udevadm control --reload-rules
    udevadm trigger --subsystem-match=usb --action=add
    systemctl enable --now zotac-wakeup-fix.service
    systemctl enable zotac-sleep-measure.service
    /etc/zotac-sleep-fix/iommu install

    echo
    echo "ZOTAC ZONE sleep fix가 설치되었습니다."
    /etc/zotac-sleep-fix/apply status
    echo
    echo "배터리 전원에서 10분 이상 대기모드를 시험한 뒤 다음 명령으로 결과를 확인하세요:"
    echo "  journalctl -b -t zotac-sleep-fix --no-pager"
}

uninstall_fix() {
    systemctl disable --now zotac-sleep-measure.service 2>/dev/null || true
    systemctl disable --now zotac-wakeup-fix.service 2>/dev/null || true

    if [[ -x /etc/zotac-sleep-fix/apply ]]; then
        /etc/zotac-sleep-fix/apply restore || true
    fi
    if [[ -x /etc/zotac-sleep-fix/iommu ]]; then
        /etc/zotac-sleep-fix/iommu uninstall
    fi

    rm -f \
        /etc/udev/rules.d/99-zotac-zone-sleep.rules \
        /etc/systemd/system/zotac-wakeup-fix.service \
        /etc/systemd/system/zotac-sleep-measure.service
    rm -f /etc/zotac-sleep-fix/apply
    rm -f /etc/zotac-sleep-fix/iommu
    rmdir /etc/zotac-sleep-fix 2>/dev/null || true

    systemctl daemon-reload
    udevadm control --reload-rules
    echo "ZOTAC ZONE sleep fix를 제거하고 기존 wake 설정을 복원했습니다."
}

case "$ACTION" in
    install)
        install_fix
        ;;
    uninstall)
        uninstall_fix
        ;;
    status)
        if [[ -x /etc/zotac-sleep-fix/apply ]]; then
            /etc/zotac-sleep-fix/apply status
            /etc/zotac-sleep-fix/iommu status
        else
            "$SCRIPT_DIR/zotac-sleep-fix" status
            "$SCRIPT_DIR/zotac-iommu-persist" status
        fi
        ;;
    *)
        echo "사용법: $0 [install|uninstall|status]" >&2
        exit 2
        ;;
esac
