# ROCm Retry Checkpoint 2026-03-13

## Status

- Archived
- Historical record; ROCm runtime was later reinstated 2026-06-07 (Tier A library stack active, framework lane still NO-GO) — see [`ROCM_WORKLOG_20260607-113702.md`](./ROCM_WORKLOG_20260607-113702.md)

## Summary

This file records the March 13, 2026 ROCm rollback state and retry notes for `Think14GRyzen`.

The body stays in Vietnamese because it is the original working note. Read it as historical context, not as the current default workflow.

## Historical details

Muc tieu tai lieu nay:
- Giu lai day du tri thuc tu cac vong thu ROCm tren Think14GRyzen.
- Ghi ro ly do rollback ve trang thai on dinh hien tai.
- Cung cap runbook fast-track de cai dat lai ROCm sau nay theo gate an toan.

Trang thai hien tai (checkpoint nay):
- ROCm da duoc go khoi cau hinh NixOS active de uu tien do on dinh desktop/session.
- He thong dang giu baseline ky thuat de benchmark tai: `/var/tmp/amd-perf-suite/baselines/current-safe`.
- `power-profiles-daemon` la power manager duy nhat.
- CPU policy baseline: `amd_pstate=active`, `amd-pstate-epp`, governor `performance`, EPP `performance`.

## 1) Tom tat su co quan trong (root-cause evidence)

Su co lon nhat trong campaign ROCm xay ra luc 2026-03-12 17:07 +07 (Phase 4 framework canary):
- GPU hang trong workload Torch ROCm canary.
- Kernel ghi nhan `MES failed ...`, `GPU reset begin`, `VRAM is lost`.
- Hyprland/Xwayland abort => user bi logout ve man hinh dang nhap.

Evidence chinh:
- `/var/tmp/rocm-incident-20260312-1707.md`
- `/var/tmp/rocm-full-20260312-164507/summary.tsv`
- `/var/tmp/rocm-stable-cycle1-20260312-224453/4/torch-rocm-canary.attempt1.log`

Danh gia:
- Day la **GPU reset + session crash do canary framework ROCm**, khong phai user force reset chu dong.
- Runtime detect (`rocminfo`, `clinfo`, `vulkaninfo`) co the PASS, nhung van khong dam bao workload framework nong se on dinh tren iGPU nay.

## 2) Cac thay doi da tung ap dung trong campaign ROCm

### 2.1 NixOS side (da thu)
- Them pin ROCm rieng trong flake (`nixpkgs-rocm`) de canary reproducible.
- Them package quan sat/an toan cao:
  - `cpupower-gui`
  - `ryzen-monitor-ng`
  - `nvtopPackages.amd`
  - `btop-rocm`
  - `vulkan-caps-viewer`
  - `rocmPackages.rocm-smi`

### 2.2 CPDA side (da thu)
- Da co giai doan pin Torch ROCm (`2.9.1+rocm6.4`) de test framework lane.
- Da dung canary script de canary trong CPDA env.
- Da gap tinh huong model/bench CPDA khong on dinh khi backend tu dong chon GPU (PyOD AutoEncoder).

## 3) Nhung yeu to quan trong can nho

1. Runtime detect PASS != framework stable PASS.
- `rocminfo/clinfo/vulkaninfo` PASS chi xac nhan duong runtime nhin thay device.
- Khong dong nghia workload Torch ROCm dai/severe se khong reset GPU.

2. Session logout da tung xay ra do GPU reset, khong chi la warning nhe.
- Neu thay signature `MES failed`, `ring timeout`, `GPU reset`, phai stop ngay rollout framework.

3. Benchmark KPI phai compare dung baseline va dung metric noi bo.
- Khong hardcode baseline theo duong dan cu.
- CPDA KPI uu tien internal timing, wall-time chi fallback co gan nhan WARN.

4. Guardrail power policy la bat buoc.
- Khong bat song song `tlp`/`lactd` voi `power-profiles-daemon`.
- Khong doi governor/pstate policy trong luc so sanh A/B, neu doi thi baseline vo hieu.

5. ROCm voi CPDA/PyOD co rui ro hanh vi backend tu dong.
- `torch.cuda.is_available() = True` se khien mot so model auto chon thiet bi GPU.
- Neu model/framework khong thuong thich backend nay, co the fail correctness hoac fail runtime.

## 4) Canh bao (warning) can ghi ro cho lan sau

- Co the gap warning `amdgpu.ids missing` trong mot so tool; day thuong la soft warning telemetry, nhung van phai theo doi kernel hard-fail rieng.
- Co kha nang xuat hien divergence metric (KPI lech) neu compare run khong dong profile/rounds/threads.
- Canary framework ROCm tung gay crash session tren may nay; tat ca lan retry phai chay theo gate tung phase, co rollback san.

## 5) Vi sao rollback ROCm khoi active config

Quyet dinh rollback duoc chon vi uu tien:
- On dinh desktop khong logout.
- Bao toan workflow CPDA de nghien cuu chay CPU/Vulkan lane on dinh.
- Tach bai toan benchmark/perf khoi bai toan framework ROCm de tranh rui ro he thong.

Ket qua sau rollback:
- Safe lane (khong framework canary) chay on dinh hon.
- Khong ghi nhan hard-fail kernel moi trong lane an toan cua campaign cuoi.

## 6) Fast-track runbook de cai lai ROCm lan sau (neu can)

Chi mo lai khi ban chap nhan rui ro co the logout session.

### Phase F0 - Freeze
1. Chot generation hien tai + backup evidence root.
2. Xac nhan guardrail power manager/policy.
3. Chot baseline benchmark o `/var/lib/amd-perf-suite/baselines/current-safe`.

### Phase F1 - Runtime only
1. Them lai ROCm runtime toi thieu (khong framework all-in ngay).
2. Kiem tra `rocminfo`, `clinfo`, `vulkaninfo --summary`.
3. Neu kernel hard-fail signature xuat hien => rollback ngay.

### Phase F2 - Soak + benchmark safe
1. Chay precheck **khong framework** (`--run-soak` only).
2. Chay `amd-perf-suite.sh` profile safe (co kernel lane neu co sudo).
3. Can 2 run lien tiep khong hard-fail.

### Phase F3 - Framework canary 1-shot
1. Chay duy nhat 1 lan framework canary co gioi han thoi gian.
2. Theo doi kernel logs song song.
3. Neu xuat hien GPU reset/hang 1 lan nua => dong bang framework lane dai han.

### Phase F4 - Promote
1. Chi promote khi pass toan bo gate va khong logout.
2. Cap nhat checkpoint tai lieu + evidence index.

## 7) Rollback gate chuan

- Runtime rollback ngay:
  - `sudo nixos-rebuild switch --rollback`
- Neu boot issue:
  - chon generation truoc trong boot menu.
- Rollback logic CPDA:
  - `git -C <cpda-repo-root> switch <stable-branch>`
- Khong dung `git reset --hard` cho van hanh thuong ngay.

## 8) Evidence index quan trong

- Su co logout/reset:
  - `/var/tmp/rocm-incident-20260312-1707.md`
- Safe stabilization report:
  - `/var/tmp/amd-rocm-safe-stabilization-report-20260313-002404.md`
- Tong hop thay doi NixOS + CPDA:
  - `/var/tmp/nixos-cpda-change-report-20260313-004804.md`
- Baseline benchmark da promote:
  - `/var/tmp/amd-perf-suite/baselines/safe-r5-20260312-210826`
  - symlink ky thuat: `/var/tmp/amd-perf-suite/baselines/current-safe`

## 9) Ket luan checkpoint

- ROCm framework lane tren may nay da co tien su gay GPU reset/logout.
- Trang thai hien tai uu tien on dinh la dung huong.
- Toan bo thong tin de retry da duoc chot trong tai lieu nay de lan sau co the fast-track co kiem soat.

## References

- [`README.md`](./README.md)
