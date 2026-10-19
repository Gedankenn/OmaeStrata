# OmaeStrata

An Omarchy third-party `bar-widget` modeled on the Omaweather plugin structure. It shows whether Strata is running, the model identity from the newest modified `strata-*.log`, aggregate host CPU utilization, and NVIDIA GPU utilization/VRAM. The status panel also shows token-generation and prompt-prefill rates parsed from that log.

## Data collection

Status is gathered over SSH from the configured `sshTarget` (default `akira@192.168.1.168`). The read-only Python collector reads `/proc` for process/CPU information, invokes `nvidia-smi` for NVIDIA GPUs (then `rocm-smi` / amdgpu sysfs for AMD), and selects the newest `/home/akira/Strata/strata-*.log` by modification time for the active model name. The panel can start Strata over SSH; when it is offline, the bar widget displays **▶ START**. While online, a second SSH process checks the newest model log once per second and sends only its filename/model plus numeric prefill and generation rates to the panel. It never forwards or stores raw log lines, prompts, or generated text. Generation and prefill are the latest completed-request rates available in the log, not a live token-by-token estimate.

Set up key-based SSH from the Omarchy desktop account first; `BatchMode=yes` means no password prompt can block the bar. The start action keeps its SSH stream open while the server script runs so progress can be read. The remote host needs Python 3. GPU metrics try `nvidia-smi`, then `rocm-smi`, then amdgpu sysfs. Process detection looks for `serve/server.py --engine strata` (or a process whose comm/basename is the configured match). Helper SSH jobs are tagged `OMAESTRATA_HELPER=1` and python `-c` payloads are ignored, so the widget does not treat its own collector as the server. The displayed model name is the uppercase model identifier parsed from the newest `strata-*.log` filename (for example, `strata-iq3_s.log` displays as `IQ3_S`).

## Machine paths (.env)

Hardcoded host paths can live in `~/.config/omarchy/omaestrata.env` (preferred) or a plugin-local `.env`. See `.env.example`. Keys: `MODE` (`ssh` or `local`), `SSH_TARGET`, `STRATA_ROOT`, `START_SCRIPT`, `DISK_PATH`, `PROCESS_PATTERN`, `REFRESH_SECONDS`. Widget settings override connection/SSH/refresh/process-match when they differ from the plugin defaults. Paths must be absolute and cannot contain `..`. Local mode ignores `SSH_TARGET` and runs the collector plus start script on this machine. GPU metrics try `nvidia-smi`, then `rocm-smi`, then amdgpu sysfs.

## Tests

Run the pure-JavaScript and widget-contract regression tests with Node.js:

```sh
node --test tests/*.test.mjs
```

## Install

On Omarchy 4, clone and run the installer. It asks for SSH vs local, host, and Strata paths:

```sh
git clone https://github.com/chrisakira/OmaeStrata.git
cd OmaeStrata
./install.sh
```

That runs `omarchy plugin add` and writes `~/.config/omarchy/omaestrata.env` (backs up an existing file). Place the OmaeStrata widget on the bar if it is not visible, then `omarchy-restart-shell`.

Flags are optional (`--mode`, `--ssh-target`, `--yes`, `--print-env`). Needs: Omarchy 4, Python 3 on the Strata host, key-based SSH for `ssh` mode, `nvidia-smi` or `rocm-smi` for GPU stats.

## Update

```sh
omarchy plugin update io.github.akira.omaestrata
```

## Remove

```sh
omarchy plugin remove io.github.akira.omaestrata
```

This removes the installed plugin. It does not delete `~/.config/omarchy/omaestrata.env`.

## Metrics caveats

CPU is a short host-wide `/proc/stat` sample, not process-specific CPU. GPU utilization and memory come from NVIDIA (`nvidia-smi`) or AMD (`rocm-smi` / amdgpu sysfs). If both fail, the panel reports that GPU metrics could not be collected. SSH and collector failures leave the last successful snapshot visible and mark the connection state as an error.

## License

MIT
