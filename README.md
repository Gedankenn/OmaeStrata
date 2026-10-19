# OmaeStrata

An Omarchy third-party `bar-widget` modeled on the Omaweather plugin structure. It shows whether Strata is running, the model identity from the newest modified `strata-*.log`, aggregate host CPU utilization, and NVIDIA GPU utilization/VRAM. The status panel also shows token-generation and prompt-prefill rates parsed from that log.

## Data collection

Status is gathered over SSH from the configured `sshTarget` (default `akira@192.168.1.168`). The read-only Python collector reads `/proc` for process/CPU information, invokes `nvidia-smi` for GPU metrics, and selects the newest `/home/akira/Strata/strata-*.log` by modification time for the active model name. The panel can start Strata over SSH; when it is offline, the bar widget displays **▶ START**. While online, a second SSH process checks the newest model log once per second and sends only its filename/model plus numeric prefill and generation rates to the panel. It never forwards or stores raw log lines, prompts, or generated text. Generation and prefill are the latest completed-request rates available in the log, not a live token-by-token estimate.

Set up key-based SSH from the Omarchy desktop account first; `BatchMode=yes` means no password prompt can block the bar. The start action keeps its SSH stream open while the server script runs so progress can be read. The remote host needs Python 3, and NVIDIA metrics require `nvidia-smi`. Process detection looks for `serve/server.py --engine strata` (or a process whose comm/basename is the configured match). Helper SSH jobs are tagged `OMAESTRATA_HELPER=1` and python `-c` payloads are ignored, so the widget does not treat its own collector as the server. The displayed model name is the uppercase model identifier parsed from the newest `strata-*.log` filename (for example, `strata-iq3_s.log` displays as `IQ3_S`).

## Tests

Run the pure-JavaScript and widget-contract regression tests with Node.js:

```sh
node --test tests/*.test.mjs
```

## Install

The Omarchy CLI installs third-party plugins from a Git URL. After publishing this folder to a repository, install it with:

```sh
omarchy plugin add <git-url> --enable
```

For local development, use `omarchy plugin validate /home/akira/Projects/OmaeStrata` to check the manifest, then copy or link the folder into Omarchy's plugin discovery directory according to the installed Omarchy version. Configure `sshTarget` and `refreshSeconds` using the Omarchy bar plugin settings UI. Left-click the visible **▶ START** widget when offline; right-click opens the status panel, middle-click refreshes immediately, and `R` refreshes while the panel is open.

## Remove

```sh
omarchy plugin remove io.github.akira.omaestrata
```

This removes the installed plugin. It does not delete this source checkout in `~/Projects/OmaeStrata`.

## Metrics caveats

CPU is a short host-wide `/proc/stat` sample, not process-specific CPU. GPU utilization and memory come from each NVIDIA GPU. If `nvidia-smi` is unavailable or fails, the panel reports that GPU metrics could not be collected. SSH and collector failures leave the last successful snapshot visible and mark the connection state as an error.

## License

MIT
