function clean(value, maxLength) {
  var s = String(value === undefined || value === null ? "" : value)
  s = s.replace(/[\x00-\x1f\x7f]/g, " ").replace(/[<>]/g, "")
  s = s.replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "")
  return s.slice(0, maxLength || 160)
}

function parseSnapshot(raw) {
  try {
    var d = JSON.parse(String(raw || ""))
    if (!d || d.ok !== true) return null
    var gpus = []
    var rows = d.gpus || []
    for (var i = 0; i < rows.length && i < 8; i++) {
      var g = rows[i] || {}
      gpus.push({
        name: clean(g.name || "GPU", 48),
        utilization: numberOrNull(g.utilization),
        memoryUsed: numberOrNull(g.memoryUsed),
        memoryTotal: numberOrNull(g.memoryTotal)
      })
    }
    return {
      online: !!d.online,
      model: clean(d.model || "Model not reported", 112),
      cpu: numberOrNull(d.cpu),
      gpus: gpus,
      timestamp: clean(d.timestamp || "", 32),
      error: clean(d.error || "", 100)
    }
  } catch (e) { return null }
}

function numberOrNull(x) {
  var n = Number(x)
  return isFinite(n) ? n : null
}

function percent(x) { return x === null || x === undefined ? "—" : Math.max(0, Math.min(100, Math.round(x))) + "%" }
function memory(g) {
  if (g.memoryUsed === null || g.memoryTotal === null) return ""
  return Math.round(g.memoryUsed) + "/" + Math.round(g.memoryTotal) + " MiB"
}
function compact(s) {
  if (!s) return "Strata · …"
  if (!s.online) return "Strata · OFF"
  return "Strata · " + (s.model || "ON")
}
function tooltip(s, state) {
  if (state === "connecting") return "OmaeStrata: collecting remote status over SSH"
  if (!s) return "OmaeStrata: no successful SSH status check"
  var lines = ["Strata: " + (s.online ? "ON" : "OFF"), "Model: " + (s.online ? s.model : "—"), "CPU: " + percent(s.cpu)]
  for (var i = 0; i < s.gpus.length; i++) {
    var g = s.gpus[i]
    lines.push(g.name + ": " + percent(g.utilization) + (memory(g) ? " · " + memory(g) : ""))
  }
  if (s.error) lines.push("GPU metrics: " + s.error)
  return lines.join("\n")
}

// Remote collector uses /proc for process/model and CPU counters, plus
// nvidia-smi for GPU utilization and memory. Every value is emitted as JSON.
// Keep this string static: configuration is passed as separate argv values.
var REMOTE_PYTHON = "import json,os,re,subprocess,time; pattern=os.environ.get('OMAE_STRATA_PATTERN','strata').lower(); procs=[]; "
  + "forbidden=('bash -c','sh -c','python -c','pgrep -af'); "
  + "\nfor p in os.listdir('/proc'):\n if not p.isdigit(): continue\n try:\n  cmd=open('/proc/'+p+'/cmdline','rb').read().replace(b'\\0',b' ').decode(errors='replace').strip()\n  if pattern in cmd.lower() and not any(x in cmd for x in forbidden): procs.append(cmd)\n except: pass\n"
  + "model='';\nif procs:\n for c in procs:\n  m=re.search(r'(?:--model(?:=|\\s+)|-m\\s+)([^\\s]+)',c)\n  if m: model=os.path.basename(m.group(1)); break\n if not model:\n  m=re.search(r'([^\\s]+\\.(?:gguf|safetensors|bin))',procs[0],re.I); model=os.path.basename(m.group(1)) if m else 'Running (model not parsed)'\n"
  + "cpu=None\ntry:\n vals=open('/proc/stat').readline().split()[1:]; vals=list(map(int,vals)); idle=vals[3]+(vals[4] if len(vals)>4 else 0); total=sum(vals); time.sleep(.18); vals2=list(map(int,open('/proc/stat').readline().split()[1:])); idle2=vals2[3]+(vals2[4] if len(vals2)>4 else 0); total2=sum(vals2); cpu=round(100*(1-(idle2-idle)/max(1,total2-total)),1)\nexcept: pass\ngpus=[]; err=''\ntry:\n out=subprocess.check_output(['nvidia-smi','--query-gpu=name,utilization.gpu,memory.used,memory.total','--format=csv,noheader,nounits'],stderr=subprocess.STDOUT,text=True,timeout=3)\n for line in out.strip().splitlines():\n  parts=[x.strip() for x in line.split(',')]; gpus.append({'name':parts[0],'utilization':float(parts[1]),'memoryUsed':float(parts[2]),'memoryTotal':float(parts[3])})\nexcept Exception as e: err=str(e)[:100]\nprint(json.dumps({'ok':True,'online':bool(procs),'model':model,'cpu':cpu,'gpus':gpus,'error':err,'timestamp':time.strftime('%H:%M:%S')}))"

function command(target, pattern) {
  var remote = "OMAE_STRATA_PATTERN='" + String(pattern || "strata").replace(/[^A-Za-z0-9_.-]/g, "") + "' python3 -c " + shellQuote(REMOTE_PYTHON)
  return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", "-o", "ServerAliveInterval=4", "-o", "ServerAliveCountMax=1", "--", String(target || "akira@192.168.1.168"), remote]
}

function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
