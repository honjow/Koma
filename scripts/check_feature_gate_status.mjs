#!/usr/bin/env node
import { existsSync, readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const root = resolve(scriptDir, '..')
const gatePath = resolve(root, 'docs/FEATURE_GATES.md')
const activeGatePath = resolve(root, '.hermes-artifacts/active-feature-gate.json')
const allowedStatuses = new Set(['TODO', 'IN_PROGRESS', 'CODE_READY_UNVERIFIED', 'ACCEPTED', 'REOPENED', 'DEFERRED'])

function fail(message) {
  console.error(`BLOCKED: ${message}`)
  process.exit(1)
}

function git(args, options = {}) {
  return execFileSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    ...options,
  })
}

function readStagedOrWorking(path) {
  try {
    return git(['show', `:${path}`])
  } catch {
    return readFileSync(resolve(root, path), 'utf8')
  }
}

function parseGateTable(markdown) {
  const gates = new Map()
  for (const line of markdown.split(/\r?\n/)) {
    if (!line.startsWith('| KG-')) continue
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim())
    if (cells.length < 6) continue
    const [id, status, scope, protectedPaths, evidence, proof] = cells
    if (!allowedStatuses.has(status)) {
      fail(`${id} has invalid feature gate status "${status}"`)
    }
    gates.set(id, {
      id,
      status,
      scope,
      protectedPaths: protectedPaths
        .split(/<br>|,/)
        .map((item) => item.replace(/`/g, '').trim())
        .filter(Boolean),
      evidence,
      proof,
    })
  }
  return gates
}

function parseActiveGate() {
  if (process.env.KOMA_ACTIVE_GATE !== undefined && process.env.KOMA_ACTIVE_GATE.trim().length > 0) {
    return {
      gateId: process.env.KOMA_ACTIVE_GATE.trim(),
      intent: process.env.KOMA_ACTIVE_GATE_INTENT ?? 'advance',
      summary: process.env.KOMA_ACTIVE_GATE_SUMMARY ?? 'env-specified gate',
      evidence: [],
    }
  }
  if (!existsSync(activeGatePath)) return undefined
  try {
    return JSON.parse(readFileSync(activeGatePath, 'utf8'))
  } catch (error) {
    fail(`cannot parse .hermes-artifacts/active-feature-gate.json: ${error.message}`)
  }
}

function stagedFiles() {
  const output = git(['diff', '--cached', '--name-only', '--diff-filter=ACMR'])
  return output.split(/\r?\n/).map((line) => line.trim()).filter(Boolean)
}

function pathMatches(pattern, file) {
  const normalized = pattern.replace(/^\.\//, '')
  if (normalized.endsWith('*')) {
    return file.startsWith(normalized.slice(0, -1))
  }
  if (normalized.endsWith('/')) {
    return file.startsWith(normalized)
  }
  return file === normalized || file.startsWith(`${normalized}/`)
}

function isUserVisibleAppFile(file) {
  if (file === 'docs/FEATURE_GATES.md') return false
  if (file === 'docs/agent-guides/koma-rules.md') return false
  if (file === 'scripts/check_feature_gate_status.mjs') return false
  if (file === '.githooks/pre-commit') return false
  return (
    file.startsWith('entry/src/main/ets/') ||
    file.startsWith('entry/src/main/resources/') ||
    file.startsWith('AppScope/') ||
    file === 'oh-package.json5' ||
    file === 'hvigorfile.ts' ||
    file === 'hvigorconfig.ts' ||
    file === 'build-profile.json5' ||
    file.startsWith('scripts/run_')
  )
}

function evidenceLooksMissing(evidence) {
  const value = evidence.replace(/`/g, '').trim().toLowerCase()
  return value.length === 0 || value === '-' || value === 'none' || value.includes('pending')
}

function validateAcceptedEvidence(gates) {
  for (const gate of gates.values()) {
    if (gate.status !== 'ACCEPTED') continue
    if (evidenceLooksMissing(gate.evidence)) {
      fail(`${gate.id} is ACCEPTED but has no concrete evidence path`)
    }
  }
}

function validateActiveGate(activeGate, gates, staged) {
  const appFiles = staged.filter(isUserVisibleAppFile)
  if (appFiles.length === 0) return
  if (activeGate === undefined) {
    fail('user-visible app changes require .hermes-artifacts/active-feature-gate.json or KOMA_ACTIVE_GATE')
  }
  if (typeof activeGate.gateId !== 'string' || activeGate.gateId.trim().length === 0) {
    fail('active feature gate artifact is missing gateId')
  }
  const gate = gates.get(activeGate.gateId)
  if (gate === undefined) {
    fail(`active feature gate ${activeGate.gateId} is not listed in docs/FEATURE_GATES.md`)
  }
  if (gate.status === 'DEFERRED' && activeGate.intent !== 'reopen') {
    fail(`${gate.id} is DEFERRED; do not spend mainline work there without reopening it`)
  }
  if (gate.status === 'ACCEPTED' && activeGate.intent !== 'reopen') {
    fail(`${gate.id} is ACCEPTED; use intent=reopen with a real reason before changing it`)
  }
  const outOfScopeFiles = appFiles.filter((file) => !gate.protectedPaths.some((pattern) => pathMatches(pattern, file)))
  if (outOfScopeFiles.length > 0) {
    fail(`${gate.id} does not cover these staged user-visible files: ${outOfScopeFiles.join(', ')}`)
  }
  if (activeGate.intent === 'reopen') {
    const reason = `${activeGate.reopenReason ?? ''}`.trim()
    if (reason.length < 20) {
      fail('reopening an accepted/deferred gate requires a concrete reopenReason')
    }
    if (!staged.includes('docs/FEATURE_GATES.md')) {
      fail('reopening a gate requires staging docs/FEATURE_GATES.md with the new state/evidence')
    }
  }
  if (!Array.isArray(activeGate.evidence) || activeGate.evidence.length === 0) {
    fail('user-visible app changes require current simulator/device evidence paths in active gate evidence')
  }
  const evidencePaths = activeGate.evidence
    .filter((evidencePath) => typeof evidencePath === 'string')
    .map((evidencePath) => evidencePath.trim())
    .filter(Boolean)
  if (evidencePaths.length === 0) {
    fail('active gate evidence must include at least one screenshot and one layout artifact')
  }
  for (const evidencePath of evidencePaths) {
    if (!existsSync(resolve(root, evidencePath))) {
      fail(`active gate evidence path does not exist: ${evidencePath}`)
    }
  }
  const hasScreenshot = evidencePaths.some((evidencePath) => /\.(png|jpg|jpeg)$/i.test(evidencePath))
  const hasLayout = evidencePaths.some((evidencePath) => /layout.*\.json$/i.test(evidencePath) || /\.layout\.json$/i.test(evidencePath))
  if (!hasScreenshot || !hasLayout) {
    fail('active gate evidence must include both a simulator/device screenshot and layout JSON')
  }
  if (typeof activeGate.userPathTest !== 'string' || activeGate.userPathTest.trim().length < 20) {
    fail('active gate requires userPathTest describing the exercised user path')
  }
}

function validateAcceptedProtection(activeGate, gates, staged) {
  const activeGateId = activeGate?.gateId
  for (const gate of gates.values()) {
    if (gate.status !== 'ACCEPTED') continue
    const touched = staged.filter((file) => gate.protectedPaths.some((pattern) => pathMatches(pattern, file)))
    if (touched.length === 0) continue
    if (activeGateId === gate.id && activeGate?.intent === 'reopen') continue
    fail(`${gate.id} is ACCEPTED; protected files changed without reopen: ${touched.join(', ')}`)
  }
}

const staged = stagedFiles()
const gateMarkdown = readStagedOrWorking('docs/FEATURE_GATES.md')
const gates = parseGateTable(gateMarkdown)
if (gates.size === 0) {
  fail('docs/FEATURE_GATES.md has no KG-* gate rows')
}

const activeGate = parseActiveGate()
validateAcceptedEvidence(gates)
validateActiveGate(activeGate, gates, staged)
validateAcceptedProtection(activeGate, gates, staged)

console.log('feature gate status check PASS')
