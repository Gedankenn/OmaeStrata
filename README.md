# OmaeStrata

An Omarchy third-party `bar-widget` modeled on the Omaweather plugin structure. It shows whether Strata is running, the model name found in the server process command line, aggregate host CPU utilization, and NVIDIA GPU utilization/VRAM.

## Data collection

All server metrics are gathered over SSH from the configured `sshTarget` (default `akira@192.168.1.168`). The plugin runs a short, read-only Python collector on the remote host. It reads `/proc` for Strata process and CPU information and invokes `nvidia-smi` for GPU metrics. It does not call a Strata HTTP API and does not start, stop, or change the server.

Set up key-based SSH from the Omarchy desktop account first; `BatchMode=yes` means no password prompt can block the bar. The remote host needs Python 3, and NVIDIA metrics require `nvidia-smi`. Process detection defaults to a case-insensitive `strata` substring. Change the match string in the widget settings if the server process uses another name. The model name is inferred from `--model`/`-m` or a GGUF/safetensors/bin path in the process arguments; otherwise the widget reports that it could not parse it.

## Install

The Omarchy CLI installs third-party plugins from a Git URL. After publishing this folder to a repository, install it with:

```sh
omarchy plugin add <git-url> --enable
```

For local development, use `omarchy plugin validate /home/akira/Projects/OmaeStrata` to check the manifest, then copy or link the folder into Omarchy's plugin discovery directory according to the installed Omarchy version. Configure `sshTarget` and `refreshSeconds` using the Omarchy bar plugin settings UI. Middle-click refreshes immediately; click opens the status panel and `R` refreshes while open.

## Metrics caveats

CPU is a short host-wide `/proc/stat` sample, not process-specific CPU. GPU utilization and memory come from each NVIDIA GPU. If `nvidia-smi` is unavailable or fails, the panel reports that GPU metrics could not be collected. SSH and collector failures leave the last successful snapshot visible and mark the connection state as an error.

## License

MIT
