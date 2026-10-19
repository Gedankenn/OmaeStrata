import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root = fileURLToPath(new URL('..', import.meta.url))
const installer = path.join(root, 'install.sh')

test('installer exists, is executable, and never uses sudo', () => {
  const src = fs.readFileSync(installer, 'utf8')
  const stat = fs.statSync(installer)
  assert.ok((stat.mode & 0o111) !== 0, 'install.sh should be executable')
  assert.doesNotMatch(src, /\bsudo\b/)
  assert.doesNotMatch(src, /\bpkexec\b/)
  assert.match(src, /omarchy plugin add/)
  assert.match(src, /omaestrata\.env/)
  assert.match(src, /no arguments/)
})

test('installer prints a dotenv for local mode without adding the plugin', () => {
  const result = spawnSync('bash', [
    installer,
    '--print-env',
    '--mode', 'local',
    '--strata-root', '/opt/strata',
    '--start-script', '/opt/strata/run.sh',
    '--disk-path', '/'
  ], { encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /^MODE=local$/m)
  assert.match(result.stdout, /^STRATA_ROOT=\/opt\/strata$/m)
  assert.match(result.stdout, /^START_SCRIPT=\/opt\/strata\/run\.sh$/m)
  assert.doesNotMatch(result.stdout, /akira@192\.168\.1\.168/)
})

test('installer with no args outside a terminal tells you to run it interactively', () => {
  const result = spawnSync('bash', [installer], { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] })
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /terminal/i)
  assert.match(result.stderr, /ask/i)
})

test('installer prints a dotenv for ssh mode', () => {
  const result = spawnSync('bash', [
    installer,
    '--print-env',
    '--mode', 'ssh',
    '--ssh-target', 'sam@10.0.0.8',
    '--strata-root', '/home/sam/Strata',
    '--start-script', '/home/sam/Strata/run.sh'
  ], { encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /^MODE=ssh$/m)
  assert.match(result.stdout, /^SSH_TARGET=sam@10\.0\.0\.8$/m)
  assert.match(result.stdout, /^STRATA_ROOT=\/home\/sam\/Strata$/m)
})
