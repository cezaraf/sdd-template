#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() { printf 'template inválido: %s\n' "$*" >&2; exit 1; }

# O guard/hook canônicos usam arrays associativos/mapfile e parsing JSON
# fail-closed. Em macOS com Bash 3, a dependência deve falhar explicitamente.
if [ "${BASH_VERSINFO[0]}" -lt 4 ] \
   || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
  fail "Bash >= 4.4 é obrigatório"
fi
for command_name in awk cmp comm cp cut git grep mktemp python3 sed sort uniq; do
  command -v "$command_name" >/dev/null 2>&1 \
    || fail "dependência obrigatória ausente: $command_name"
done

validation_tmp="$(mktemp -d)"
cleanup() { rm -rf "$validation_tmp"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

prompts=(
  00-iniciar-incremento-sdd
  01-criar-prd
  02-criar-techspec
  03-criar-tasks
  04-auditar-especificacao
  05-instalar-rules-skills
  06-executar-task
  07-revisar-implementacao
  08-executar-qa
  09-corrigir-bugs
  10-preparar-pr
  11-validar-pr-merge
  12-deploy-verificar
  13-consolidar-contrato-vivo
  14-promover-aprendizados
)

for prompt in "${prompts[@]}"; do
  test -s "$prompt.md" || fail "ausente: $prompt.md"
done

test -s _comum.md || fail "_comum.md ausente"
test -s governanca/policies.yaml.example || fail "policies ausentes"
test -x governanca/sdd-guard.sh || fail "guard ausente ou não executável"
test -x governanca/sdd-fluxo.sh || fail "driver de fluxo ausente ou não executável"
test -x governanca/sdd-metricas.sh || fail "script de métricas ausente ou não executável"
test -x governanca/sdd-hook-claude.sh || fail "hook do Claude ausente ou não executável"
test -s governanca/sdd-watch.sh.example || fail "detector operacional ausente"
test -s governanca/watch.yaml.example || fail "config do detector ausente"
test -s evals/cases/core-contracts.yaml || fail "catálogo de evals ausente"
test -x evals/run-evals.sh || fail "runner de evals ausente ou não executável"
test -s .github/workflows/sdd-guard.yml || fail "workflow do guard ausente"
test -s .github/workflows/template-evals.yml || fail "workflow de validação ausente"
test -s .github/workflows/sdd-watch.yml.example || fail "workflow do watch ausente"
test -x install.sh || fail "install.sh não executável"
awk '
  /^src_is_complete\(\)/ { inside=1 }
  inside && /governanca\/policies.yaml.example/ { found=1 }
  inside && /\.github\/workflows\/sdd-guard.yml/ { workflow=1 }
  inside && /^}/ { exit(found && workflow ? 0 : 1) }
  END { if (!inside || !found || !workflow) exit 1 }
' install.sh || fail "src_is_complete não exige policy e workflow canônicos"

for script in install.sh governanca/sdd-guard.sh governanca/sdd-fluxo.sh \
  governanca/sdd-metricas.sh governanca/sdd-hook-claude.sh \
  governanca/sdd-watch.sh.example evals/run-evals.sh scripts/validate-template.sh; do
  bash -n "$script" || fail "sintaxe inválida: $script"
done

# Workflows: valida os eventos e, principalmente, que ausência de controles
# não seja transformada em sucesso silencioso.
guard_workflow=.github/workflows/sdd-guard.yml
template_workflow=.github/workflows/template-evals.yml
watch_workflow=.github/workflows/sdd-watch.yml.example
grep -q '^on:' "$guard_workflow" || fail "workflow do guard sem eventos"
grep -q 'pull_request_target:' "$guard_workflow" || fail "workflow do guard sem pull_request_target confiável"
grep -q 'fetch-depth:[[:space:]]*0' "$guard_workflow" || fail "workflow sem histórico para diff"
grep -q 'persist-credentials:[[:space:]]*false' "$guard_workflow" \
  || fail "checkout privilegiado persiste credenciais no worktree candidato"
grep -q -- '--tier1' "$guard_workflow" || fail "workflow não executa Tier 1"
grep -q 'scan-secrets' "$guard_workflow" || fail "workflow não varre segredos"
grep -q 'protect-ci' "$guard_workflow" || fail "workflow não valida paths protegidos/contratos no CI"
grep -q 'SDD_TRUSTED_POLICIES' "$guard_workflow" \
  || fail "workflow não ancora autoridade na policy da base"
grep -q 'trusted_guard' "$guard_workflow" \
  || fail "workflow não executa guard extraído da base"
grep -Fq 'git archive --format=tar "$base"' "$guard_workflow" \
  || fail "workflow não materializa o snapshot completo da base confiável"
grep -Fq 'commits/$HEAD_SHA/pulls' "$guard_workflow" \
  || fail "workflow não resolve a proveniência do push por SHA"
grep -q 'SDD_PUSH_FROM_MERGED_PR' "$guard_workflow" \
  || fail "workflow não distingue push direto de merge de PR"
grep -Fq '[ "${SDD_PUSH_FROM_MERGED_PR:-0}" = 1 ]' "$guard_workflow" \
  || fail "workflow não preserva protect-ci em push direto"
if grep -q 'SDD_CANDIDATE_EVALS' "$guard_workflow"; then
  fail "workflow privilegiado executa eval candidata do PR"
fi
grep -q 'pre-merge' "$guard_workflow" || fail "workflow não executa pre-merge"
grep -q 'set -euo pipefail' "$guard_workflow" || fail "workflow do guard não é fail-closed"
if grep -q 'continue-on-error:[[:space:]]*true' "$guard_workflow"; then
  fail "workflow do guard permite continue-on-error"
fi
grep -q 'bubblewrap' "$template_workflow" \
  || fail "workflow de validação não instala a sandbox Tier 2"
grep -q 'apparmor-profiles' "$template_workflow" \
  || fail "workflow de validação não configura o profile AppArmor do bwrap"
grep -q 'bwrap --version' "$template_workflow" \
  || fail "workflow de validação não comprova a sandbox Tier 2"
grep -Fq 'bwrap --ro-bind / /' "$template_workflow" \
  || fail "workflow de validação não exercita user namespace do bwrap"
pinned_uses_re='^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]+(\./[^[:space:]#]+|[^[:space:]#]+@[0-9a-f]{40})[[:space:]]*(#.*)?$'
while IFS= read -r uses_line; do
  [[ "$uses_line" =~ $pinned_uses_re ]] \
    || fail "workflow usa action externa sem commit SHA de 40 hex: $uses_line"
done < <(grep -REh '^[[:space:]]*(-[[:space:]]*)?uses:' .github/workflows || true)
grep -Rq 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' .github/workflows \
  || fail "actions/checkout não está pinada no SHA aprovado"
grep -Fq 'actions/cache/restore@5a3ec84eff668545956fd18022155c47e93e2684' "$watch_workflow" \
  || fail "actions/cache/restore não está pinada no SHA aprovado"
grep -Fq 'actions/cache/save@5a3ec84eff668545956fd18022155c47e93e2684' "$watch_workflow" \
  || fail "actions/cache/save não está pinada no SHA aprovado"
grep -q 'schedule:' "$watch_workflow" || fail "workflow watch sem agenda"
grep -q 'PIPESTATUS' "$watch_workflow" || fail "workflow watch perde status do detector no pipe"
grep -q 'GITHUB_OUTPUT' "$watch_workflow" || fail "workflow watch não publica banda"
grep -q 'gh issue create' "$watch_workflow" || fail "workflow watch não abre incidente"
if command -v actionlint >/dev/null 2>&1; then
  actionlint "$guard_workflow" || fail "actionlint rejeitou workflow do guard"
fi
if python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 - "$guard_workflow" "$watch_workflow" <<'PY' \
    || fail "parser YAML rejeitou workflow"
import sys
import yaml

for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict):
        raise SystemExit(f"workflow sem objeto raiz: {path}")
PY
fi

# Referências canônicas essenciais.
if grep -n '10-consolidar-contrato-vivo' _comum.md 0*.md 1*.md 2*.md 2>/dev/null; then
  fail "referência legada encontrada em artefato ativo"
fi
grep -q '10-preparar-pr' install.sh || fail "passo 10 ausente do instalador"
grep -q '14-promover-aprendizados' install.sh || fail "passo 14 ausente do instalador"
grep -q 'Contrato vivo só muda no passo `13`' README.md \
  || fail "regra de consolidação ausente do README"
grep -q 'pre-production' governanca/sdd-guard.sh || fail "gate de produção ausente"
grep -q 'sdd-guard.sh pre-consolidate' 13-consolidar-contrato-vivo.md \
  || fail "passo 13 não invoca gate determinístico"
grep -q 'sdd-metricas.sh' 13-consolidar-contrato-vivo.md \
  || fail "passo 13 não consolida métricas"
grep -q 'incidente' 00-iniciar-incremento-sdd.md || fail "passo 00 sem rota de incidente"

# Paridade exata id+modo em ambos os sentidos. O próprio runner também faz
# este check; a comparação independente impede que catálogo e listagem sejam
# alterados de modo unilateral.
catalog_registration="$validation_tmp/catalog.registration"
runner_registration="$validation_tmp/runner.registration"
awk '
  /^[[:space:]]*- id:[[:space:]]*/ { id=$3; next }
  /^[[:space:]]*mode:[[:space:]]*/ {
    if (id != "") { print id "|" $2; id="" }
  }
' evals/cases/core-contracts.yaml | LC_ALL=C sort >"$catalog_registration"
./evals/run-evals.sh --list | LC_ALL=C sort >"$runner_registration" \
  || fail "runner recusou catálogo"
test -s "$catalog_registration" || fail "catálogo de evals vazio"
duplicates="$(cut -d'|' -f1 "$catalog_registration" | uniq -d)"
[ -z "$duplicates" ] || fail "IDs duplicados no catálogo: $duplicates"
duplicates="$(cut -d'|' -f1 "$runner_registration" | uniq -d)"
[ -z "$duplicates" ] || fail "IDs duplicados no runner: $duplicates"
missing="$(comm -23 "$catalog_registration" "$runner_registration")"
extra="$(comm -13 "$catalog_registration" "$runner_registration")"
[ -z "$missing" ] || fail "catálogo sem caso no runner: $missing"
[ -z "$extra" ] || fail "runner com caso fora do catálogo: $extra"
grep -q '^EVAL-012|agente$' "$runner_registration" || fail "EVAL-012 ausente do Tier 2"

# Tier 1 normal e teste de mutação usam somente cópias. O arquivo real nunca é
# escrito, nem temporariamente.
guard_copy="$validation_tmp/sdd-guard.original.sh"
mutated_guard="$validation_tmp/sdd-guard.mutated.sh"
cp -p governanca/sdd-guard.sh "$guard_copy"
chmod 0755 "$guard_copy"
SDD_GUARD="$guard_copy" ./evals/run-evals.sh --tier1 >/dev/null \
  || fail "evals Tier 1 falharam"

anchor_count="$(grep -cF 'authorize_contract_path "$rel"' governanca/sdd-guard.sh || true)"
[ "$anchor_count" -ge 2 ] || fail "âncora da mutação de proteção mudou"
sed 's/authorize_contract_path "$rel"/:/' governanca/sdd-guard.sh >"$mutated_guard"
chmod 0755 "$mutated_guard"
bash -n "$mutated_guard" || fail "mutação gerou guard inválido"
if SDD_GUARD="$mutated_guard" ./evals/run-evals.sh --tier1 >/dev/null 2>&1; then
  fail "evals não detectaram remoção da proteção de contratos"
fi
cmp -s governanca/sdd-guard.sh "$guard_copy" \
  || fail "autoteste alterou o guard real"

# Tier 2: SKIP em --all é não zero, e evidência não vazia sem verdict
# estruturado do judge não pode virar PASS.
if SDD_GUARD="$guard_copy" SDD_EVAL_AGENT= SDD_EVAL_JUDGE= \
  ./evals/run-evals.sh --all --filter EVAL-001 >/dev/null 2>&1; then
  fail "--all aceitou SKIP como sucesso"
fi
if ./evals/run-evals.sh --tier1 --filter EVAL-001 >/dev/null 2>&1; then
  fail "Tier 1 aceitou filtro de caso agêntico sem executar nada"
fi
mock_bin="$validation_tmp/mock-bin"
tier2_host_home="$validation_tmp/tier2-host-home"
mkdir -p "$mock_bin" "$tier2_host_home"
printf 'credencial host sintética\n' >"$tier2_host_home/host-secret"
mock_agent="$mock_bin/mock-agent.sh"
empty_judge="$mock_bin/empty-judge.sh"
incomplete_judge="$mock_bin/incomplete-judge.sh"
valid_judge="$mock_bin/valid-judge.sh"
cat >"$mock_agent" <<'SH'
#!/usr/bin/env bash
set -eu
test -z "${SDD_EVAL_CRITERIA+x}"
test -n "${SDD_EVAL_EXECUTOR_CATALOG:-}"
test -f "$SDD_EVAL_EXECUTOR_CATALOG"
! grep -Eq '^    (criteria|expect|forbid):' "$SDD_EVAL_EXECUTOR_CATALOG"
test -z "${SDD_EVAL_HOST_SENTINEL+x}"
test ! -e "$HOME/host-secret"
if { printf 'critério forjado pelo executor\n' >../criteria.txt; } 2>/dev/null; then
  exit 90
fi
printf 'mutação confinada ao workspace descartável\n' >AGENT_MUTATED
printf 'evidência propositalmente não vazia\n' >"$SDD_EVAL_EVIDENCE"
SH
cat >"$empty_judge" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$incomplete_judge" <<'SH'
#!/usr/bin/env bash
set -eu
criterion="$(sed -n '1p' "$SDD_EVAL_CRITERIA")"
printf '{"schema_version":1,"case_id":"%s","verdict":"PASS","reason":"cobertura propositalmente incompleta","checks":[{"criterion_id":"%s","criterion":"somente um critério","passed":true,"evidence":"fixture"}]}\n' \
  "$SDD_EVAL_CASE_ID" "$criterion"
SH
cat >"$valid_judge" <<'SH'
#!/usr/bin/env bash
set -eu
test -s "$SDD_EVAL_EVIDENCE"
test ! -e AGENT_MUTATED
python3 - "$SDD_EVAL_CASE_ID" "$SDD_EVAL_CRITERIA" <<'PY'
import json
import pathlib
import sys

case_id, criteria_path = sys.argv[1:]
criteria = pathlib.Path(criteria_path).read_text(encoding="utf-8").splitlines()
print(json.dumps({
    "schema_version": 1,
    "case_id": case_id,
    "verdict": "PASS",
    "reason": "oracle isolado aprovou todos os critérios da fixture de protocolo",
    "checks": [
        {
            "criterion_id": criterion,
            "criterion": f"critério obrigatório {criterion}",
            "passed": True,
            "evidence": "SDD_EVAL_EVIDENCE foi lida em processo separado",
        }
        for criterion in criteria
    ],
}, ensure_ascii=False))
PY
SH
chmod 0755 "$mock_agent" "$empty_judge" "$incomplete_judge" "$valid_judge"
if HOME="$tier2_host_home" SDD_EVAL_HOST_SENTINEL=nao-herdar SDD_GUARD="$guard_copy" ./evals/run-evals.sh --all --filter EVAL-001 \
  --agent-cmd "$mock_agent" --judge-cmd "$empty_judge" >/dev/null 2>&1; then
  fail "Tier 2 aceitou arquivo não vazio sem verdict JSON verificável"
fi
if HOME="$tier2_host_home" SDD_EVAL_HOST_SENTINEL=nao-herdar SDD_GUARD="$guard_copy" ./evals/run-evals.sh --all --filter EVAL-001 \
  --agent-cmd "$mock_agent" --judge-cmd "$incomplete_judge" >/dev/null 2>&1; then
  fail "Tier 2 aceitou judge sem cobertura de todos os criteria do catálogo"
fi
tier2_protocol_log="$validation_tmp/tier2-valid.log"
if ! HOME="$tier2_host_home" SDD_EVAL_HOST_SENTINEL=nao-herdar SDD_GUARD="$guard_copy" ./evals/run-evals.sh --all --filter EVAL-001 \
    --agent-cmd "$mock_agent" --judge-cmd "$valid_judge" >"$tier2_protocol_log" 2>&1; then
  command cat "$tier2_protocol_log" >&2
  fail "Tier 2 rejeitou executor+judge isolados com verdict estruturado válido"
fi
test ! -e "$root/AGENT_MUTATED" \
  || fail "executor Tier 2 alterou o worktree fonte"

# Nenhum ancestral gerenciado pode redirecionar a instalação para fora do
# projeto. O instalador deve falhar antes de escrever no destino do symlink.
symlink_project="$validation_tmp/symlink-project"
symlink_outside="$validation_tmp/symlink-outside"
mkdir -p "$symlink_project" "$symlink_outside"
ln -s "$symlink_outside" "$symlink_project/sdd"
if "$root/install.sh" --project "$symlink_project" --tools codex --skip-compozy \
    >"$validation_tmp/symlink-install.log" 2>&1; then
  fail "instalador aceitou ancestral sdd como symlink"
fi
shopt -s nullglob dotglob
symlink_entries=("$symlink_outside"/*)
shopt -u nullglob dotglob
[ "${#symlink_entries[@]}" -eq 0 ] \
  || fail "instalador escreveu fora do projeto através de symlink"

# Instalação em projeto preexistente: settings com substring enganosa, hooks e
# workflow do usuário, AGENTS sem newline e um núcleo sem manifest.
project="$validation_tmp/project"
mkdir -p "$project/.claude" "$project/.github/workflows" "$project/sdd/governanca"
git -C "$project" init -q
git -C "$project" config user.email sdd-template@example.invalid
git -C "$project" config user.name sdd-template
printf 'Diretrizes locais do projeto' >"$project/AGENTS.md"
chmod 0640 "$project/AGENTS.md"
cat >"$project/.claude/settings.json" <<'JSON'
{
  "custom": {
    "enabled": true,
    "note": "texto sdd-hook-claude.sh não é um hook"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {"type": "command", "command": "custom-read-hook"}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "custom-post-hook"}
        ]
      }
    ]
  }
}
JSON
cat >"$project/.github/workflows/user.yml" <<'YAML'
name: User workflow
on: workflow_dispatch
jobs:
  user:
    runs-on: ubuntu-latest
    steps:
      - run: printf 'user workflow\n'
YAML
printf '#!/usr/bin/env bash\nprintf "núcleo customizado anterior\\n"\n' \
  >"$project/sdd/governanca/sdd-guard.sh"
chmod 0755 "$project/sdd/governanca/sdd-guard.sh"
cp "$project/.github/workflows/user.yml" "$validation_tmp/user-workflow.before"

SDD_PREFIX=equipe-x "$root/install.sh" --project "$project" \
  --tools claude,codex,opencode --skip-compozy >"$validation_tmp/install-first.log"

expected_files=(
  .claude/skills/equipe-x-preparar-pr/SKILL.md
  .agents/skills/equipe-x-deploy-verificar/SKILL.md
  .opencode/command/equipe-x-promover-aprendizados.md
  .claude/agents/equipe-x-auditor-especificacao.md
  .claude/settings.json
  .github/workflows/sdd-guard.yml
  sdd/governanca/sdd-guard.sh
  sdd/governanca/sdd-fluxo.sh
  sdd/governanca/sdd-metricas.sh
  sdd/governanca/sdd-hook-claude.sh
  sdd/governanca/sdd-template.env
  sdd/evals/run-evals.sh
  sdd/evals/cases/core-contracts.yaml
  sdd/.sdd-template/manifest-v1.tsv
)
for expected in "${expected_files[@]}"; do
  test -s "$project/$expected" || fail "instalação não gerou $expected"
done
cmp -s "$validation_tmp/user-workflow.before" "$project/.github/workflows/user.yml" \
  || fail "instalação alterou workflow preexistente"
grep -qx 'SDD_PREFIX=equipe-x' "$project/sdd/governanca/sdd-template.env" \
  || fail "SDD_PREFIX não foi persistido"
python3 - "$project/AGENTS.md" <<'PY' \
  || fail "instalação alterou permissões preexistentes de AGENTS.md"
import os
import stat
import sys

assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o640
PY
grep -q 'feature.*explícito' "$project/.claude/agents/equipe-x-auditor-especificacao.md" \
  || fail "agent instalado não exige feature/escopo explícito"
grep -q 'registre lacunas' "$project/.claude/agents/equipe-x-auditor-especificacao.md" \
  || fail "agent instalado não registra lacunas"

python3 - "$project/.claude/settings.json" <<'PY' \
  || fail "merge estrutural dos hooks não preservou settings"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
assert data["custom"]["enabled"] is True
assert data["custom"]["note"].startswith("texto sdd-hook-claude.sh")
assert data["hooks"]["PostToolUse"][0]["hooks"][0]["command"] == "custom-post-hook"
pre = data["hooks"]["PreToolUse"]
assert any(item.get("matcher") == "Read" for item in pre)
for matcher in ("Edit|Write|MultiEdit|NotebookEdit", "Bash"):
    matches = [
        hook
        for item in pre if item.get("matcher") == matcher
        for hook in item.get("hooks", [])
        if hook.get("type") == "command"
        and hook.get("command") == "sdd/governanca/sdd-hook-claude.sh"
    ]
    assert len(matches) == 1, (matcher, matches)
PY

# A segunda instalação omite SDD_PREFIX: deve reutilizar a configuração
# persistida e ser byte-idempotente em AGENTS/settings/manifest.
cp "$project/AGENTS.md" "$validation_tmp/AGENTS.once"
cp "$project/.claude/settings.json" "$validation_tmp/settings.once"
cp "$project/sdd/.sdd-template/manifest-v1.tsv" "$validation_tmp/manifest.once"
"$root/install.sh" --project "$project" --tools claude,codex,opencode \
  --skip-compozy >"$validation_tmp/install-second.log"
cmp -s "$validation_tmp/AGENTS.once" "$project/AGENTS.md" \
  || fail "reinstalação não é byte-idempotente em AGENTS.md"
cmp -s "$validation_tmp/settings.once" "$project/.claude/settings.json" \
  || fail "reinstalação reescreveu settings sem mudança estrutural"
cmp -s "$validation_tmp/manifest.once" "$project/sdd/.sdd-template/manifest-v1.tsv" \
  || fail "reinstalação alterou manifest sem mudança"
test ! -e "$project/.claude/skills/cz-preparar-pr" \
  || fail "prefixo persistido foi perdido na reinstalação"

# Drift apenas de permissão também é reparado, mesmo com conteúdo idêntico.
chmod 0644 "$project/sdd/governanca/sdd-guard.sh"
"$root/install.sh" --project "$project" --tools claude,codex,opencode \
  --skip-compozy >"$validation_tmp/install-mode-repair.log"
test -x "$project/sdd/governanca/sdd-guard.sh" \
  || fail "reinstalação não restaurou modo executável do guard"

# O bundle deve registrar todos os componentes e preservar divergências antes
# de promover a versão canônica.
manifest_count="$(awk -F '\t' '$1 == "file" { n++ } END { print n + 0 }' \
  "$project/sdd/.sdd-template/manifest-v1.tsv")"
[ "$manifest_count" -eq 8 ] || fail "manifest não cobre bundle completo"
shopt -s nullglob
initial_backups=("$project"/sdd/.sdd-template/backups/sdd/governanca/sdd-guard.sh/*.bak)
shopt -u nullglob
[ "${#initial_backups[@]}" -ge 1 ] || fail "núcleo preexistente não recebeu backup"
grep -q 'núcleo customizado anterior' "${initial_backups[0]}" \
  || fail "backup não preservou conteúdo preexistente"

printf '\n# customização posterior ao manifest\n' >>"$project/sdd/governanca/sdd-guard.sh"
"$root/install.sh" --project "$project" --tools claude,codex,opencode \
  --skip-compozy >"$validation_tmp/install-customized.log"
if grep -q 'customização posterior' "$project/sdd/governanca/sdd-guard.sh"; then
  fail "bundle canônico não foi restaurado após backup"
fi
custom_backup_found=0
shopt -s nullglob
for backup in "$project"/sdd/.sdd-template/backups/sdd/governanca/sdd-guard.sh/*.bak; do
  if grep -q 'customização posterior' "$backup"; then custom_backup_found=1; fi
done
shopt -u nullglob
[ "$custom_backup_found" -eq 1 ] || fail "customização gerenciada não foi preservada em backup"

# Runner e catálogo instalados permanecem coerentes; o Tier 1 também exercita
# guard, fluxo, hook, traversal, placeholders e workflow no projeto destino.
"$project/sdd/evals/run-evals.sh" --list >/dev/null \
  || fail "runner/catálogo instalados divergiram"
installed_tier1_log="$validation_tmp/installed-tier1.log"
if ! "$project/sdd/evals/run-evals.sh" --tier1 >"$installed_tier1_log" 2>&1; then
  command cat "$installed_tier1_log" >&2
  fail "Tier 1 instalado falhou"
fi

# Prefixo persistido é consumido pelo fluxo instalado.
feature=prefix-smoke
inc="$project/sdd/incrementos/$feature"
mkdir -p "$inc"
cat >"$inc/incremento.yaml" <<'YAML'
id: prefix-smoke
status: consolidado
fase: fechamento
classificacao:
  alvo_contrato: local
rota:
  pr_merge: dispensada
YAML
flow_output="$(cd "$project" && sdd/governanca/sdd-fluxo.sh "$feature" --json)" \
  || fail "fluxo instalado falhou"
printf '%s' "$flow_output" | grep -q '/equipe-x-promover-aprendizados' \
  || fail "fluxo não consumiu SDD_PREFIX persistido"
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" >/dev/null) \
  || fail "métricas instaladas falharam"

# Métricas adversariais: whitelist, CSV upsert e relatório idempotente.
cp "$inc/incremento.yaml" "$validation_tmp/metrics-before.yaml"
metric_rc=0
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --marcar status >/dev/null 2>&1) \
  || metric_rc=$?
[ "$metric_rc" -eq 2 ] || fail "métricas aceitaram campo fora da whitelist (exit $metric_rc)"
cmp -s "$validation_tmp/metrics-before.yaml" "$inc/incremento.yaml" \
  || fail "--marcar inválido alterou incremento.yaml"
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --marcar data_merge >/dev/null)
cp "$inc/incremento.yaml" "$validation_tmp/metric-write-once.yaml"
sleep 1
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --marcar data_merge >/dev/null)
cmp -s "$validation_tmp/metric-write-once.yaml" "$inc/incremento.yaml" \
  || fail "marco de métrica existente foi sobrescrito"
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --csv >/dev/null)
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --csv >/dev/null)
[ "$(wc -l <"$project/sdd/metricas.csv" | tr -d ' ')" -eq 2 ] \
  || fail "CSV de métricas não faz upsert por incremento"
printf '# Relatório de fechamento\n' >"$inc/relatorio-fechamento.md"
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --atualizar-relatorio >/dev/null)
cp "$inc/relatorio-fechamento.md" "$validation_tmp/closure-report.once"
(cd "$project" && sdd/governanca/sdd-metricas.sh "$feature" --atualizar-relatorio >/dev/null)
cmp -s "$validation_tmp/closure-report.once" "$inc/relatorio-fechamento.md" \
  || fail "atualização do relatório de métricas não é idempotente"

# Watch avalia todos os checks mesmo quando o primeiro entra em 3 sigma.
cp "$project/sdd/governanca/sdd-watch.sh.example" "$project/sdd/governanca/sdd-watch.sh"
chmod 0755 "$project/sdd/governanca/sdd-watch.sh"
cat >"$project/sdd/governanca/watch.yaml" <<'YAML'
version: 1
checks:
  - name: primeira
    command: "printf 20"
    window: 5
    min_amostras: 2
    sigma_diagnostico: 2
    sigma_acao: 3
  - name: segunda
    command: "printf 30"
    window: 5
    min_amostras: 2
    sigma_diagnostico: 2
    sigma_acao: 3
YAML
mkdir -p "$project/.sdd-watch"
printf '10\n10\n' >"$project/.sdd-watch/primeira.samples"
printf '20\n20\n' >"$project/.sdd-watch/segunda.samples"
watch_rc=0
watch_output="$(cd "$project" && sdd/governanca/sdd-watch.sh)" || watch_rc=$?
[ "$watch_rc" -eq 3 ] || fail "watch deveria retornar a pior banda 3 (exit $watch_rc)"
printf '%s\n' "$watch_output" | grep -q 'sdd-watch \[primeira\]' \
  || fail "watch não avaliou o primeiro check"
printf '%s\n' "$watch_output" | grep -q 'sdd-watch \[segunda\]' \
  || fail "watch interrompeu antes do segundo check"
mv "$project/.sdd-watch" "$project/.sdd-watch.valid"
mkdir -p "$validation_tmp/watch-outside"
ln -s "$validation_tmp/watch-outside" "$project/.sdd-watch"
watch_rc=0
(cd "$project" && sdd/governanca/sdd-watch.sh >/dev/null 2>&1) || watch_rc=$?
[ "$watch_rc" -eq 4 ] || fail "watch aceitou diretório de estado via symlink (exit $watch_rc)"
rm "$project/.sdd-watch"
mv "$project/.sdd-watch.valid" "$project/.sdd-watch"

# Hook real: JSON válido de Edit em contrato deve bloquear com exit 2.
hook_rc=0
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"antes","new_string":"conteúdo seguro"}}' \
  "$project/sdd/contratos/demo/contrato.md" \
  | (cd "$project" && sdd/governanca/sdd-hook-claude.sh) >/dev/null 2>&1 || hook_rc=$?
[ "$hook_rc" -eq 2 ] || fail "hook deveria bloquear contrato vivo (exit $hook_rc)"

# Uninstall usa temporário imprevisível e nunca segue AGENTS.md.tmp preexistente.
uninstall_outside="$validation_tmp/uninstall-outside.txt"
printf 'conteúdo externo preservado\n' >"$uninstall_outside"
cp "$uninstall_outside" "$validation_tmp/uninstall-outside.before"
ln -s "$uninstall_outside" "$project/AGENTS.md.tmp"
"$root/install.sh" --project "$project" --tools claude,codex,opencode \
  --skip-compozy --uninstall >"$validation_tmp/uninstall.log"
cmp -s "$validation_tmp/uninstall-outside.before" "$uninstall_outside" \
  || fail "uninstall truncou arquivo externo via AGENTS.md.tmp"
test -L "$project/AGENTS.md.tmp" \
  || fail "uninstall consumiu symlink preexistente AGENTS.md.tmp"
grep -q 'Diretrizes locais do projeto' "$project/AGENTS.md" \
  || fail "uninstall removeu conteúdo local de AGENTS.md"
if grep -qF '<!-- sdd-template:begin -->' "$project/AGENTS.md"; then
  fail "uninstall preservou bloco gerenciado em AGENTS.md"
fi
python3 - "$project/.claude/settings.json" <<'PY' \
  || fail "uninstall não removeu apenas os hooks SDD"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
assert data["custom"]["enabled"] is True
assert data["hooks"]["PostToolUse"][0]["hooks"][0]["command"] == "custom-post-hook"
for entry in data.get("hooks", {}).get("PreToolUse", []):
    for hook in entry.get("hooks", []):
        assert hook.get("command") != "sdd/governanca/sdd-hook-claude.sh"
PY

# Slugs inválidos falham antes de qualquer instalação, inclusive traversal.
invalid_index=0
for invalid_prefix in '' '../escape' 'a/b' 'a--b' '-inicio' 'fim-' 'Maiusculo' '.'; do
  invalid_index=$((invalid_index + 1))
  invalid_project="$validation_tmp/invalid-prefix-$invalid_index"
  mkdir -p "$invalid_project"
  if SDD_PREFIX="$invalid_prefix" "$root/install.sh" --project "$invalid_project" \
    --tools codex --skip-compozy >"$validation_tmp/invalid-prefix-$invalid_index.log" 2>&1; then
    fail "instalador aceitou SDD_PREFIX inválido: $invalid_prefix"
  fi
  test ! -e "$invalid_project/sdd" \
    || fail "prefixo inválido produziu instalação parcial: $invalid_prefix"
done

# Policies antigas não recebem um guard incompatível silenciosamente.
legacy_policy_project="$validation_tmp/legacy-policy"
mkdir -p "$legacy_policy_project/sdd/governanca"
git -C "$legacy_policy_project" init -q
cat >"$legacy_policy_project/sdd/governanca/policies.yaml" <<'YAML'
version: 1
quality_commands:
  test: []
YAML
legacy_rc=0
"$root/install.sh" --project "$legacy_policy_project" --tools codex --skip-compozy \
  >"$validation_tmp/legacy-policy.log" 2>&1 || legacy_rc=$?
[ "$legacy_rc" -eq 3 ] || fail "policies v1 deveria exigir migração explícita (exit $legacy_rc)"
test -s "$legacy_policy_project/sdd/governanca/policies.yaml.v2.example" \
  || fail "instalador não forneceu referência de migração para policies v1"
test ! -e "$legacy_policy_project/sdd/.sdd-template/manifest-v1.tsv" \
  || fail "instalador atualizou núcleo antes da migração de policies"

# Variáveis SDD externas não podem fazer o instalador validar outra policy.
external_policy_project="$validation_tmp/external-policy-project"
mkdir -p "$external_policy_project/sdd/governanca"
git -C "$external_policy_project" init -q
printf 'version: 2\nproject:\n  language: pt-BR\n' \
  >"$external_policy_project/sdd/governanca/policies.yaml"
external_policy_rc=0
SDD_POLICIES_FILE="$root/governanca/policies.yaml.example" \
  SDD_TRUSTED_POLICIES="$root/governanca/policies.yaml.example" \
  "$root/install.sh" --project "$external_policy_project" --tools codex --skip-compozy \
  >"$validation_tmp/external-policy.log" 2>&1 || external_policy_rc=$?
[ "$external_policy_rc" -eq 3 ] \
  || fail "instalador validou policy externa em vez da policy malformada do projeto"

# Dry-run nunca materializa a referência de migração nem qualquer arquivo.
legacy_dry_project="$validation_tmp/legacy-policy-dry"
mkdir -p "$legacy_dry_project/sdd/governanca"
git -C "$legacy_dry_project" init -q
printf 'version: 1\n' >"$legacy_dry_project/sdd/governanca/policies.yaml"
legacy_dry_rc=0
"$root/install.sh" --project "$legacy_dry_project" --tools codex --skip-compozy --dry-run \
  >"$validation_tmp/legacy-policy-dry.log" 2>&1 || legacy_dry_rc=$?
[ "$legacy_dry_rc" -eq 3 ] || fail "dry-run com policy v1 deveria sinalizar migração (exit $legacy_dry_rc)"
test ! -e "$legacy_dry_project/sdd/governanca/policies.yaml.v2.example" \
  || fail "--dry-run escreveu referência de migração"
test ! -e "$legacy_dry_project/sdd/.sdd-template" \
  || fail "--dry-run alterou metadados do projeto"

# Dependências do núcleo são verificadas antes da primeira escrita, não apenas
# ao instalar o adaptador do Claude.
no_python_bin="$validation_tmp/no-python-bin"
no_python_project="$validation_tmp/no-python-project"
mkdir -p "$no_python_bin" "$no_python_project"
for required_command in awk cmp comm cp cut date dd dirname git grep mktemp sed sort tail tr uniq wc; do
  ln -s "$(command -v "$required_command")" "$no_python_bin/$required_command"
done
missing_dependency_rc=0
PATH="$no_python_bin" "$(command -v bash)" "$root/install.sh" \
  --project "$no_python_project" --tools codex --skip-compozy \
  >"$validation_tmp/no-python.log" 2>&1 || missing_dependency_rc=$?
[ "$missing_dependency_rc" -eq 1 ] || fail "instalador sem python3 deveria falhar no preflight"
grep -q 'python3' "$validation_tmp/no-python.log" \
  || fail "preflight não diagnosticou python3 ausente"
test ! -e "$no_python_project/sdd" \
  || fail "dependência ausente produziu instalação parcial"

# JSON preexistente inválido nunca é sobrescrito e a instalação termina
# explicitamente incompleta (exit 3).
invalid_json_project="$validation_tmp/invalid-json"
mkdir -p "$invalid_json_project/.claude"
git -C "$invalid_json_project" init -q
printf '{"hooks": [ inválido ]\n' >"$invalid_json_project/.claude/settings.json"
cp "$invalid_json_project/.claude/settings.json" "$validation_tmp/invalid-settings.before"
invalid_rc=0
"$root/install.sh" --project "$invalid_json_project" --tools claude --skip-compozy \
  >"$validation_tmp/invalid-json.log" 2>&1 || invalid_rc=$?
[ "$invalid_rc" -eq 3 ] || fail "settings inválido deveria terminar instalação com exit 3 (exit $invalid_rc)"
grep -q 'INCOMPLETA' "$validation_tmp/invalid-json.log" \
  || fail "falha de enforcement não foi marcada como INCOMPLETA"
cmp -s "$validation_tmp/invalid-settings.before" "$invalid_json_project/.claude/settings.json" \
  || fail "settings JSON inválido foi sobrescrito"

printf 'template válido\n'
