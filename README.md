# ZOTAC GAMING ZONE · SteamOS Deep Sleep Fix

[한국어](#한국어) · [English](#english)

## 한국어

ZOTAC GAMING ZONE에서 SteamOS 대기모드가 수 초 만에 끝나거나 배터리를
과도하게 소모하는 문제를 위한, 검증된 수정과 측정 도구입니다.

이 저장소에서 확인한 원인은 SteamOS 공통 GRUB 설정의 `amd_iommu=off`였습니다.
이 옵션을 제거해 IOMMU를 활성화하면 AMD PMC가 S0i3(깊은 절전)에 진입할 수
있었습니다. 충전 케이블 연결·분리가 기기를 깨우는 문제도 AC 어댑터·내장
ZOTAC USB/XHC0 wake source를 차단하여 해결합니다.

### 검증 환경과 결과

- 기기: ZOTAC GAMING ZONE (Ryzen 7 8840U)
- SteamOS 3.8.24 / Neptune 6.16.12 계열에서 검증
- 기본 설정: 약 13분 절전 중 S0i3 체류 `0초`, `Last S0i3 Status: Fail`
- `amd_iommu=off`만 제거: 683초 중 680.19초 S0i3 체류, `Success`
- 재부팅 후 검증: 791초 중 788.31초 S0i3 체류, 실패 `0회`

다른 SteamOS 버전·BIOS·하드웨어에서는 결과가 다를 수 있습니다. 이 스크립트는
SteamOS GRUB 설정과 wake source를 수정하므로, 아래 내용을 이해한 뒤 사용하세요.

### 설치

Desktop Mode 터미널에서 저장소 디렉터리로 이동해 실행합니다.

```bash
chmod +x install.sh zotac-sleep-fix zotac-iommu-persist
sudo ./install.sh install
sudo reboot
```

설치 프로그램은 다음을 수행합니다.

- `/etc/default/grub-steamos`에서 독립된 `amd_iommu=off` 행만 제거
- SteamOS의 `update-grub`로 `/efi/EFI/steamos/grub.cfg` 재생성
- 원본 설정을 `/var/lib/zotac-sleep-fix/`에 백업
- 작업 중에만 SteamOS read-only 보호와 EFI 파티션을 쓰기 가능하게 전환하고,
  성공·실패와 관계없이 원래 상태로 복구
- 내장 ZOTAC USB (`1ee9:1590`), XHC0, 충전기 wake source 비활성화

충전은 계속 동작하지만, 충전 케이블의 연결·분리만으로는 절전이 풀리지
않습니다. 물리 전원 버튼 wake는 유지됩니다.

### 상태 확인과 검증

```bash
sudo ./install.sh status
journalctl -b -u zotac-sleep-measure.service --no-pager
cat /sys/power/suspend_stats/total_hw_sleep
```

배터리 전원에서 10분 이상 절전한 후 전원 버튼으로 깨우세요. 다음이 보이면
정상입니다.

- `Last S0i3 Status: Success`
- `Time (in us) in S0i3`가 실제 절전 시간에 가까움
- `total_hw_sleep`가 0보다 큼
- `fail: 0`

`USB4_0`에 매우 큰 음수 값이 보일 수 있는데, 이 기기의 AMD PMC 펌웨어가
보고하는 비정상적인 통계값입니다. S0i3 성공 여부는 `Last S0i3 Status`와
`Time in S0i3`로 판단하세요.

### HueSync 관련

HueSync가 켜진 상태에서도 S0i3 진입은 성공했습니다. 다만 커널의
`zotac_zone_hid`와 RGB 명령이 충돌하여 절전 복귀 시 timeout/warning이 생길 수
있습니다. RGB 오작동이나 복귀 지연이 있으면 HueSync를 비활성화해 보세요.

### SteamOS 업데이트

SteamOS의 A/B 이미지 업데이트는 `/etc/default/grub-steamos` 설정을 되돌릴 수
있습니다. 업데이트 후 절전 문제가 재발하면 다음을 다시 실행하고 재부팅하세요.

```bash
sudo ./install.sh install
sudo reboot
```

### 제거 및 원복

```bash
sudo ./install.sh uninstall
sudo reboot
```

제거는 백업한 GRUB 설정을 해시 검증 후 복원하고, GRUB를 재생성하며, 설치한
systemd/udev 설정 및 wake source 변경을 되돌립니다. 설치 후 사용자가
`/etc/default/grub-steamos`를 직접 수정한 경우에는 안전을 위해 자동 덮어쓰기를
거부합니다.

## English

This repository fixes excessive suspend drain and immediate wakeups on the
ZOTAC GAMING ZONE running stock SteamOS.

On the tested unit, SteamOS' global `amd_iommu=off` kernel argument prevented
S0i3 deep sleep. Removing that argument enabled IOMMU and changed a 13-minute
suspend from zero S0i3 residency to 680.19 seconds in S0i3. The script also
disables noisy charger, built-in ZOTAC USB, and XHC0 wake sources; the physical
power button remains able to wake the handheld.

Install from Desktop Mode:

```bash
chmod +x install.sh zotac-sleep-fix zotac-iommu-persist
sudo ./install.sh install
sudo reboot
```

The installer backs up `/etc/default/grub-steamos`, removes only its standalone
`amd_iommu=off` line, regenerates the SteamOS GRUB configuration, and restores
the original read-only and EFI mount states. Verify a 10-minute battery-powered
suspend with:

```bash
sudo ./install.sh status
journalctl -b -u zotac-sleep-measure.service --no-pager
```

Expected results are `Last S0i3 Status: Success`, S0i3 residency close to the
suspend duration, and no suspend failures. SteamOS A/B updates can restore the
vendor GRUB settings; rerun the installer and reboot if the issue returns.

Remove and restore the backed-up settings with:

```bash
sudo ./install.sh uninstall
sudo reboot
```

Use at your own risk: this is tested on one ZOTAC GAMING ZONE with SteamOS
3.8.24 / Neptune 6.16.12. Firmware, SteamOS, and hardware revisions may behave
differently.

## Files

- `install.sh` — installer, status, and safe uninstall entry point
- `zotac-iommu-persist` — backed-up persistent GRUB/IOMMU adjustment
- `zotac-sleep-fix` — wake-source handling and AMD PMC suspend measurement
- `99-zotac-zone-sleep.rules` — reapplies USB and charger wake settings on udev events
- `zotac-*-fix.service` — systemd units for boot and suspend/resume handling

## License

MIT. See [LICENSE](LICENSE).
