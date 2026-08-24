#!/usr/bin/env bash
#
# Instalador do SDD Template — contratos vivos e SDLC AI-native.
#
set -euo pipefail

REPO="${SDD_REPO:-cezaraf/sdd-template}"
REF="main"
SCOPE=""
PROJECT_DIR=""
TOOLS="claude,codex,opencode"
INSTALL_COMPOZY=1
UNINSTALL=0
DRY_RUN=0
PREFIX="${SDD_PREFIX-cz}"
PREFIX_EXPLICIT=0
[ "${SDD_PREFIX+x}" = "x" ] && PREFIX_EXPLICIT=1
MIGRATE_FROM_PREFIX=""

PROMPTS="00-iniciar-incremento-sdd 01-criar-prd 02-criar-techspec 03-criar-tasks \
04-auditar-especificacao 05-instalar-rules-skills 06-executar-task \
07-revisar-implementacao 08-executar-qa 09-corrigir-bugs 10-preparar-pr \
11-validar-pr-merge 12-deploy-verificar 13-consolidar-contrato-vivo \
14-promover-aprendizados"

AGENT_STEPS="04-auditar-especificacao 07-revisar-implementacao 08-executar-qa"

MARKER_BEGIN="<!-- sdd-template:begin -->"
MARKER_END="<!-- sdd-template:end -->"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok \033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mavis\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merro\033[0m %s\n' "$*" >&2; exit 1; }
incomplete() {
  printf '\033[1;31mINCOMPLETA\033[0m %s\n' "$*" >&2
  exit 3
}

if [ "${BASH_VERSINFO[0]}" -lt 4 ] \
   || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
  die "Bash >= 4.4 é obrigatório para o núcleo SDD"
fi

validate_prefix() {
  local value="$1"
  case "$value" in
    ""|*[!a-z0-9-]*|-*|*-|*--*)
      die "SDD_PREFIX inválido: use um slug minúsculo estrito (a-z, 0-9 e hífens simples)"
      ;;
  esac
  [ "${#value}" -le 63 ] \
    || die "SDD_PREFIX inválido: máximo de 63 caracteres"
}

read_persisted_prefix() {
  local file="$1"
  [ -f "$file" ] || return 1
  awk '
    /^SDD_PREFIX=/ {
      count++
      value=substr($0, index($0, "=") + 1)
      next
    }
    /^[[:space:]]*$/ { next }
    { invalid=1 }
    END {
      if (invalid || count != 1) exit 1
      print value
    }
  ' "$file"
}

file_digest() {
  local file="$1" value
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    value="$(openssl dgst -sha256 "$file")" || return 1
    printf '%s\n' "${value##* }"
  else
    value="$(cksum "$file")" || return 1
    set -- $value
    printf 'cksum-%s-%s\n' "$1" "$2"
  fi
}

assert_safe_destination() {
  local path="$1" relative current component parent
  local -a destination_parts=()
  [ "${SCOPE:-}" = project ] || return 0
  [ -n "${PROJECT_DIR:-}" ] || return 0
  case "$path" in
    "$PROJECT_DIR"|"$PROJECT_DIR"/*) ;;
    *) return 0 ;;
  esac
  relative="${path#"$PROJECT_DIR"}"
  relative="${relative#/}"
  current="$PROJECT_DIR"
  IFS='/' read -r -a destination_parts <<<"$relative"
  for component in "${destination_parts[@]}"; do
    case "$component" in ''|.) continue ;; ..) die "destino contém traversal: $path" ;; esac
    current="$current/$component"
    [ ! -L "$current" ] || die "destino gerenciado contém symlink: ${current#"$PROJECT_DIR"/}"
  done
  parent="$(dirname "$path")"
  while [ ! -e "$parent" ]; do parent="$(dirname "$parent")"; done
  [ ! -L "$parent" ] || die "ancestral de destino é symlink: ${parent#"$PROJECT_DIR"/}"
  case "$(cd "$parent" && pwd -P)" in
    "$PROJECT_DIR"|"$PROJECT_DIR"/*) ;;
    *) die "destino gerenciado escapa do projeto: $path" ;;
  esac
}

run() {
  local command_name target argument
  command_name="${1##*/}"
  case "$command_name" in
    mkdir)
      shift
      for argument in "$@"; do
        case "$argument" in -*) ;; *) assert_safe_destination "$argument" ;; esac
      done
      set -- mkdir "$@"
      ;;
    cp|mv)
      for argument in "$@"; do target="$argument"; done
      [ -z "${target:-}" ] || assert_safe_destination "$target"
      ;;
  esac
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

write_file() {
  local path="$1"
  assert_safe_destination "$path"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m escreveria %s\n' "$path"
    cat >/dev/null
  else
    mkdir -p "$(dirname "$path")"
    cat >"$path"
  fi
}

copy_if_absent() {
  local source="$1" target="$2" mode="${3:-}"
  assert_safe_destination "$target"
  if [ -e "$target" ]; then
    ok "preservado: $target"
    return
  fi
  run mkdir -p "$(dirname "$target")"
  run cp "$source" "$target"
  [ -z "$mode" ] || run chmod "$mode" "$target"
}

usage() {
  cat <<'EOF'
Instalador do SDD Template — contratos vivos e SDLC AI-native.

Uso:
  curl -fsSL https://raw.githubusercontent.com/cezaraf/sdd-template/main/install.sh | bash
  curl -fsSL .../install.sh | bash -s -- [flags]

Flags:
  --global                instala no home do usuário
  --project [dir]         instala no projeto (default: raiz git/cwd)
  --tools LISTA           claude,codex,opencode
  --skip-compozy          não instala o Compozy
  --ref REF               branch/tag do template
  --uninstall             remove adaptadores e prompts instalados
  --dry-run               mostra operações
  -h | --help             ajuda

Env:
  SDD_REPO=usuario/fork
  SDD_PREFIX=meu-prefixo
EOF
}

step_desc() {
  case "$1" in
    00-iniciar-incremento-sdd)   echo "SDD 00 — Brief e classificação de rigor, risco, autonomia e alvo" ;;
    01-criar-prd)                echo "SDD 01 — PRD observável e agnóstico de implementação" ;;
    02-criar-techspec)           echo "SDD 02 — TechSpec, contratos, riscos, testes e ADRs" ;;
    03-criar-tasks)              echo "SDD 03 — Plano persistido, tasks BDD e impactos contratuais" ;;
    04-auditar-especificacao)    echo "SDD 04 — Auditoria independente da especificação e do plano" ;;
    05-instalar-rules-skills)    echo "SDD 05 — Governança: rules, skills, policies, hooks e evals" ;;
    06-executar-task)            echo "SDD 06 — Execução de task dentro do plano aprovado" ;;
    07-revisar-implementacao)    echo "SDD 07 — Review independente de implementação e evidências" ;;
    08-executar-qa)              echo "SDD 08 — QA como consumidor, com PASSOU/FALHOU/NAO_VERIFICADO" ;;
    09-corrigir-bugs)            echo "SDD 09 — Bugfix por causa raiz e teste de regressão" ;;
    10-preparar-pr)              echo "SDD 10 — Pacote, commits e PR conforme autoridade" ;;
    11-validar-pr-merge)         echo "SDD 11 — Checks, reviews, revalidação e gate de merge" ;;
    12-deploy-verificar)         echo "SDD 12 — Deploy, health checks, verificação e rollback" ;;
    13-consolidar-contrato-vivo) echo "SDD 13 — Consolidação do contrato vivo no alvo confirmado" ;;
    14-promover-aprendizados)    echo "SDD 14 — Promoção de aprendizados para evals e governança" ;;
    *)                           echo "Etapa do fluxo SDD" ;;
  esac
}

skill_slug() {
  case "$1" in
    00-iniciar-incremento-sdd)   echo "$PREFIX-iniciar-incremento" ;;
    01-criar-prd)                echo "$PREFIX-criar-prd" ;;
    02-criar-techspec)           echo "$PREFIX-criar-techspec" ;;
    03-criar-tasks)              echo "$PREFIX-criar-tasks" ;;
    04-auditar-especificacao)    echo "$PREFIX-auditar-especificacao" ;;
    05-instalar-rules-skills)    echo "$PREFIX-instalar-rules-skills" ;;
    06-executar-task)            echo "$PREFIX-executar-task" ;;
    07-revisar-implementacao)    echo "$PREFIX-revisar-implementacao" ;;
    08-executar-qa)              echo "$PREFIX-executar-qa" ;;
    09-corrigir-bugs)            echo "$PREFIX-corrigir-bugs" ;;
    10-preparar-pr)              echo "$PREFIX-preparar-pr" ;;
    11-validar-pr-merge)         echo "$PREFIX-validar-pr-merge" ;;
    12-deploy-verificar)         echo "$PREFIX-deploy-verificar" ;;
    13-consolidar-contrato-vivo) echo "$PREFIX-consolidar-contrato-vivo" ;;
    14-promover-aprendizados)    echo "$PREFIX-promover-aprendizados" ;;
  esac
}

is_agent_step() {
  case " $AGENT_STEPS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

agent_name() {
  case "$1" in
    04-auditar-especificacao) echo "$PREFIX-auditor-especificacao" ;;
    07-revisar-implementacao) echo "$PREFIX-revisor-implementacao" ;;
    08-executar-qa)           echo "$PREFIX-qa" ;;
  esac
}

agent_desc() {
  case "$1" in
    04-auditar-especificacao) echo "Audita especificação, plano, riscos, gates e rastreabilidade antes da implementação" ;;
    07-revisar-implementacao) echo "Revisa diff, contratos, segurança, testes e aderência ao plano" ;;
    08-executar-qa)           echo "Valida a entrega como consumidor e registra bugs reproduzíveis" ;;
  esac
}

strip_agents_block() {
  local file="$1" begin_count end_count tmp
  [ -f "$file" ] || return 0
  assert_safe_destination "$file"
  begin_count="$(awk -v m="$MARKER_BEGIN" '$0 == m { n++ } END { print n + 0 }' "$file")"
  end_count="$(awk -v m="$MARKER_END" '$0 == m { n++ } END { print n + 0 }' "$file")"
  if [ "$begin_count" -eq 1 ] && [ "$end_count" -eq 1 ]; then
    tmp="$(mktemp "${file}.sdd-remove.XXXXXX")" || return 1
    cp -p "$file" "$tmp" || { rm -f "$tmp"; return 1; }
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b { if (seen || skip) bad=1; seen=1; skip=1; next }
      $0 == e { if (!skip) bad=1; skip=0; next }
      !skip { print }
      END { if (bad || skip) exit 1 }
    ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
    if cmp -s "$file" "$tmp"; then
      rm -f "$tmp"
    else
      mv "$tmp" "$file"
    fi
  elif [ "$begin_count" -ne 0 ] || [ "$end_count" -ne 0 ]; then
    warn "AGENTS.md tem marcadores incompletos, duplicados ou fora de ordem"
    return 1
  fi
}

install_agents_block() {
  local file="$1" block="$2" begin_count=0 end_count=0 tmp
  if [ -f "$file" ]; then
    begin_count="$(awk -v m="$MARKER_BEGIN" '$0 == m { n++ } END { print n + 0 }' "$file")"
    end_count="$(awk -v m="$MARKER_END" '$0 == m { n++ } END { print n + 0 }' "$file")"
  fi

  if [ "$begin_count" -ne "$end_count" ] || [ "$begin_count" -gt 1 ]; then
    die "AGENTS.md com marcadores SDD incompletos ou duplicados"
  fi

  assert_safe_destination "$file"
  tmp="$(mktemp "${file}.sdd.XXXXXX")"
  if [ -f "$file" ]; then
    cp -p "$file" "$tmp"
  else
    chmod 0644 "$tmp"
  fi
  if [ "$begin_count" -eq 1 ]; then
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b {
        if (seen || skip) { bad=1; next }
        seen=1
        while ((getline line < replacement) > 0) print line
        close(replacement)
        skip=1
        next
      }
      $0 == e { if (!skip) bad=1; skip=0; next }
      !skip { print }
      END { if (bad || skip || !seen) exit 1 }
    ' replacement="$block" "$file" >"$tmp" \
      || { rm -f "$tmp"; die "AGENTS.md com marcadores SDD fora de ordem"; }
  elif [ -f "$file" ] && grep -q '[^[:space:]]' "$file"; then
    { cat "$file"; printf '\n'; cat "$block"; } >"$tmp"
  else
    cat "$block" >"$tmp"
  fi

  if [ -f "$file" ] && cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
}

remove_claude_hooks_json() {
  local source="$1" output="$2" hook_command="$3"
  python3 - "$source" "$output" "$hook_command" <<'PY'
import json
import sys

source, output, hook_command = sys.argv[1:]

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("chave JSON duplicada: " + key)
        result[key] = value
    return result

try:
    with open(source, encoding="utf-8") as stream:
        data = json.load(stream, object_pairs_hook=unique_object)
except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
    print("settings.json inválido para uninstall seguro: " + str(exc), file=sys.stderr)
    raise SystemExit(2)

if not isinstance(data, dict):
    raise SystemExit(2)
hooks = data.get("hooks")
if hooks is None:
    raise SystemExit(10)
if not isinstance(hooks, dict):
    raise SystemExit(2)
pre = hooks.get("PreToolUse")
if pre is None:
    raise SystemExit(10)
if not isinstance(pre, list):
    raise SystemExit(2)

changed = False
new_pre = []
for entry in pre:
    if not isinstance(entry, dict):
        raise SystemExit(2)
    entry_hooks = entry.get("hooks", [])
    if not isinstance(entry_hooks, list):
        raise SystemExit(2)
    filtered = []
    entry_changed = False
    for hook in entry_hooks:
        if not isinstance(hook, dict):
            raise SystemExit(2)
        if hook.get("type") == "command" and hook.get("command") == hook_command:
            changed = True
            entry_changed = True
        else:
            filtered.append(hook)
    updated = dict(entry)
    if "hooks" in updated:
        updated["hooks"] = filtered
    if entry_changed and not filtered and set(updated).issubset({"matcher", "hooks"}) \
            and updated.get("matcher") in ("Edit|Write|MultiEdit|NotebookEdit", "Bash"):
        continue
    new_pre.append(updated)

if not changed:
    raise SystemExit(10)
if new_pre:
    hooks["PreToolUse"] = new_pre
else:
    hooks.pop("PreToolUse", None)
if not hooks:
    data.pop("hooks", None)
with open(output, "w", encoding="utf-8") as stream:
    json.dump(data, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
PY
}

uninstall_claude_hooks() {
  local settings="$1" hook_command="sdd/governanca/sdd-hook-claude.sh" tmp rc=0
  assert_safe_destination "$settings"
  [ -e "$settings" ] || return 0
  [ -f "$settings" ] && [ ! -L "$settings" ] \
    || incomplete ".claude/settings.json não é arquivo regular; hooks não removidos"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m removeria hooks SDD de %s\n' "$settings"
    return 0
  fi
  command -v python3 >/dev/null 2>&1 \
    || incomplete "python3 é obrigatório para remover hooks do Claude com segurança"
  tmp="$(mktemp "${settings}.sdd-remove.XXXXXX")" \
    || incomplete "não foi possível criar temporário para remover hooks do Claude"
  cp -p "$settings" "$tmp" || { rm -f "$tmp"; incomplete "não foi possível preservar settings"; }
  remove_claude_hooks_json "$settings" "$tmp" "$hook_command" || rc=$?
  case "$rc" in
    0) mv "$tmp" "$settings" || { rm -f "$tmp"; incomplete "hooks do Claude não removidos"; } ;;
    10) rm -f "$tmp" ;;
    *) rm -f "$tmp"; incomplete ".claude/settings.json inválido; hooks SDD não removidos" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --global) SCOPE="global" ;;
    --project)
      SCOPE="project"
      if [ $# -gt 1 ] && [ "${2#--}" = "$2" ]; then
        PROJECT_DIR="$2"
        shift
      fi
      ;;
    --tools)
      [ $# -gt 1 ] || die "--tools exige valor"
      TOOLS="$2"
      shift
      ;;
    --skip-compozy) INSTALL_COMPOZY=0 ;;
    --ref)
      [ $# -gt 1 ] || die "--ref exige valor"
      REF="$2"
      shift
      ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "flag desconhecida: $1" ;;
  esac
  shift
done

validate_prefix "$PREFIX"
[ -n "$TOOLS" ] || die "--tools não pode ser vazio"
for tool in $(printf '%s' "$TOOLS" | tr ',' ' '); do
  case "$tool" in claude|codex|opencode) : ;; *) die "ferramenta inválida: $tool" ;; esac
done
has_tool() { case ",$TOOLS," in *,"$1",*) return 0 ;; *) return 1 ;; esac; }

if [ -z "$SCOPE" ]; then
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    SCOPE="project"
  else
    SCOPE="global"
  fi
fi

if [ "$SCOPE" = "project" ]; then
  if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
  PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)" || die "diretório inválido"
fi

if [ "$SCOPE" = "global" ]; then
  CANON_DIR="$HOME/.sdd/prompts"
  CLAUDE_SKILLS="$HOME/.claude/skills"
  CLAUDE_AGENTS="$HOME/.claude/agents"
  CODEX_SKILLS="$HOME/.codex/skills"
  CODEX_AGENTS="$HOME/.codex/agents"
  OPENCODE_CMDS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/command"
  OPENCODE_AGENTS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agent"
  CANON_REF="$CANON_DIR"
else
  CANON_DIR="$PROJECT_DIR/sdd/prompts"
  CLAUDE_SKILLS="$PROJECT_DIR/.claude/skills"
  CLAUDE_AGENTS="$PROJECT_DIR/.claude/agents"
  CODEX_SKILLS="$PROJECT_DIR/.agents/skills"
  CODEX_AGENTS="$PROJECT_DIR/.codex/agents"
  OPENCODE_CMDS="$PROJECT_DIR/.opencode/command"
  OPENCODE_AGENTS="$PROJECT_DIR/.opencode/agent"
  CANON_REF="sdd/prompts"
fi

if [ "$SCOPE" = "project" ]; then
  prefix_config="$PROJECT_DIR/sdd/governanca/sdd-template.env"
else
  prefix_config="$HOME/.sdd/sdd-template.env"
fi
persisted_prefix=""
if [ -e "$prefix_config" ]; then
  [ -f "$prefix_config" ] && [ ! -L "$prefix_config" ] \
    || die "configuração persistida de SDD_PREFIX deve ser arquivo regular: $prefix_config"
  persisted_prefix="$(read_persisted_prefix "$prefix_config" 2>/dev/null)" \
    || die "configuração persistida de SDD_PREFIX inválida: $prefix_config"
  validate_prefix "$persisted_prefix"
fi
if [ "$PREFIX_EXPLICIT" -eq 0 ] && [ -n "$persisted_prefix" ]; then
  PREFIX="$persisted_prefix"
elif [ "$PREFIX_EXPLICIT" -eq 1 ] && [ -n "$persisted_prefix" ] \
     && [ "$persisted_prefix" != "$PREFIX" ]; then
  MIGRATE_FROM_PREFIX="$persisted_prefix"
fi

remove_adapters_for_prefix() {
  local remove_prefix="$1" active_prefix="$PREFIX" name slug aname
  [ -n "$remove_prefix" ] || return 0
  validate_prefix "$remove_prefix"
  PREFIX="$remove_prefix"
  for name in $PROMPTS; do
    slug="$(skill_slug "$name")"
    run rm -rf "$CLAUDE_SKILLS/$slug" "$CODEX_SKILLS/$slug"
    run rm -f "$OPENCODE_CMDS/$slug.md"
  done
  for name in $AGENT_STEPS; do
    aname="$(agent_name "$name")"
    run rm -f "$CLAUDE_AGENTS/$aname.md" "$CODEX_AGENTS/$aname.toml" \
      "$OPENCODE_AGENTS/$aname.md"
  done
  PREFIX="$active_prefix"
}

if [ "$UNINSTALL" -eq 1 ]; then
  if [ "$SCOPE" = project ]; then
    for destination in "$CANON_DIR" "$CLAUDE_SKILLS" "$CLAUDE_AGENTS" \
      "$CODEX_SKILLS" "$CODEX_AGENTS" "$OPENCODE_CMDS" "$OPENCODE_AGENTS" \
      "$PROJECT_DIR/AGENTS.md" "$PROJECT_DIR/.claude/settings.json"; do
      assert_safe_destination "$destination"
    done
  fi
  if [ "$SCOPE" = project ]; then
    uninstall_claude_hooks "$PROJECT_DIR/.claude/settings.json"
  fi
  info "Removendo adaptadores SDD"
  remove_adapters_for_prefix "$PREFIX"
  if [ -n "$persisted_prefix" ] && [ "$persisted_prefix" != "$PREFIX" ]; then
    remove_adapters_for_prefix "$persisted_prefix"
  fi
  run rm -rf "$CANON_DIR"
  if [ "$SCOPE" = "project" ] && [ "$DRY_RUN" -eq 0 ]; then
    strip_agents_block "$PROJECT_DIR/AGENTS.md" || true
  fi
  ok "Adaptadores removidos; dados SDD do projeto foram preservados"
  exit 0
fi

for required_command in awk cmp comm cp cut date dd dirname git grep mktemp \
  python3 sed sort tail tr uniq wc; do
  command -v "$required_command" >/dev/null 2>&1 \
    || die "dependência obrigatória ausente: $required_command"
done

SRC_DIR=""
TMP_DIR=""
WORK_DIR=""
PENDING_TEMPS=()
cleanup() {
  local path
  for path in "${PENDING_TEMPS[@]}"; do
    [ -z "$path" ] || rm -f "$path"
  done
  [ -z "${WORK_DIR:-}" ] || rm -rf "$WORK_DIR"
  [ -z "${TMP_DIR:-}" ] || rm -rf "$TMP_DIR"
}
trap cleanup EXIT

src_is_complete() {
  local dir="$1" name
  [ -f "$dir/_comum.md" ] || return 1
  for name in $PROMPTS; do
    [ -f "$dir/$name.md" ] || return 1
  done
  for name in \
    governanca/sdd-guard.sh \
    governanca/sdd-fluxo.sh \
    governanca/sdd-metricas.sh \
    governanca/sdd-hook-claude.sh \
    governanca/policies.yaml.example \
    evals/run-evals.sh \
    evals/cases/core-contracts.yaml \
    .github/workflows/sdd-guard.yml; do
    [ -f "$dir/$name" ] || return 1
  done
}

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if src_is_complete "$script_dir"; then
    SRC_DIR="$script_dir"
  fi
fi

if [ -z "$SRC_DIR" ]; then
  command -v curl >/dev/null 2>&1 || die "curl é necessário"
  command -v tar >/dev/null 2>&1 || die "tar é necessário"
  TMP_DIR="$(mktemp -d)"
  info "Baixando $REPO@$REF"
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" \
    -o "$TMP_DIR/sdd.tar.gz" \
    || curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/tags/$REF" \
      -o "$TMP_DIR/sdd.tar.gz" \
    || die "falha ao baixar template"
  tar -xzf "$TMP_DIR/sdd.tar.gz" -C "$TMP_DIR"
  SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [ -n "$SRC_DIR" ] && src_is_complete "$SRC_DIR" \
    || die "template incompleto"
fi

WORK_DIR="$(mktemp -d)"

manifest_digest() {
  local manifest="$1" rel="$2"
  [ -f "$manifest" ] || return 1
  awk -F '\t' -v rel="$rel" \
    '$1 == "file" && $2 == rel { print $3; exit }' "$manifest"
}

render_managed_file() {
  local source="$1" rel="$2" target="$3"
  mkdir -p "$(dirname "$target")"
  if [ "$source" = "@prefix" ]; then
    printf 'SDD_PREFIX=%s\n' "$PREFIX" >"$target"
    return 0
  fi
  cp "$source" "$target"
}

install_managed_bundle() {
  local manifest="$PROJECT_DIR/sdd/.sdd-template/manifest-v1.tsv"
  local backup_root="$PROJECT_DIR/sdd/.sdd-template/backups"
  local stage_root="$WORK_DIR/managed" manifest_stage="$WORK_DIR/manifest-v1.tsv"
  local rel source mode target stage desired current previous backup tmp index
  local -a rels sources modes staged digests targets temps
  assert_safe_destination "$manifest"
  assert_safe_destination "$backup_root"

  rels=(
    sdd/governanca/sdd-guard.sh
    sdd/governanca/sdd-fluxo.sh
    sdd/governanca/sdd-metricas.sh
    sdd/governanca/sdd-hook-claude.sh
    sdd/evals/run-evals.sh
    sdd/evals/cases/core-contracts.yaml
    sdd/governanca/sdd-template.env
  )
  sources=(
    "$SRC_DIR/governanca/sdd-guard.sh"
    "$SRC_DIR/governanca/sdd-fluxo.sh"
    "$SRC_DIR/governanca/sdd-metricas.sh"
    "$SRC_DIR/governanca/sdd-hook-claude.sh"
    "$SRC_DIR/evals/run-evals.sh"
    "$SRC_DIR/evals/cases/core-contracts.yaml"
    @prefix
  )
  modes=(0755 0755 0755 0755 0755 0644 0644)

  rels+=(.github/workflows/sdd-guard.yml)
  sources+=("$SRC_DIR/.github/workflows/sdd-guard.yml")
  modes+=(0644)

  mkdir -p "$stage_root"
  for index in "${!rels[@]}"; do
    rel="${rels[$index]}"
    source="${sources[$index]}"
    if [ "$source" != "@prefix" ] && [ ! -f "$source" ]; then
      incomplete "núcleo do template ausente: ${source#$SRC_DIR/}"
    fi
    stage="$stage_root/$rel"
    render_managed_file "$source" "$rel" "$stage"
    chmod "${modes[$index]}" "$stage"
    case "$rel" in *.sh) bash -n "$stage" \
      || incomplete "script gerenciado inválido: $rel" ;; esac
    staged[$index]="$stage"
    digests[$index]="$(file_digest "$stage")"
    targets[$index]="$PROJECT_DIR/$rel"
    temps[$index]=""
  done
  "$stage_root/sdd/evals/run-evals.sh" --list >/dev/null \
    || incomplete "runner e catálogo do bundle estão incoerentes"

  # Primeiro preparamos backups e temporários; só depois promovemos o bundle.
  for index in "${!rels[@]}"; do
    rel="${rels[$index]}"
    target="${targets[$index]}"
    assert_safe_destination "$target"
    stage="${staged[$index]}"
    desired="${digests[$index]}"
    if [ -e "$target" ] && [ ! -f "$target" ]; then
      incomplete "destino gerenciado não é arquivo regular: $rel"
    fi
    current=""
    [ ! -f "$target" ] || current="$(file_digest "$target")"
    previous="$(manifest_digest "$manifest" "$rel" 2>/dev/null || true)"

    if [ -n "$current" ] && [ "$current" != "$desired" ]; then
      if [ -z "$previous" ] || [ "$current" != "$previous" ]; then
        backup="$backup_root/$rel/$current.bak"
        assert_safe_destination "$backup"
        if [ "$DRY_RUN" -eq 1 ]; then
          printf '\033[2m[dry-run]\033[0m preservaria customização em %s\n' \
            "${backup#$PROJECT_DIR/}"
        else
          mkdir -p "$(dirname "$backup")"
          if [ ! -f "$backup" ]; then cp -p "$target" "$backup"; fi
          warn "customização preservada em ${backup#$PROJECT_DIR/}; núcleo canônico será atualizado"
        fi
      fi
    fi

    if [ "$current" != "$desired" ] && [ "$DRY_RUN" -eq 0 ]; then
      mkdir -p "$(dirname "$target")"
      tmp="$(mktemp "${target}.sdd-new.XXXXXX")"
      PENDING_TEMPS+=("$tmp")
      cp "$stage" "$tmp"
      chmod "${modes[$index]}" "$tmp"
      temps[$index]="$tmp"
    fi
  done

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m atualizaria bundle gerenciado e manifest em %s\n' \
      "${manifest#$PROJECT_DIR/}"
    return 0
  fi

  for index in "${!rels[@]}"; do
    tmp="${temps[$index]}"
    [ -z "$tmp" ] || mv "$tmp" "${targets[$index]}"
    chmod "${modes[$index]}" "${targets[$index]}" \
      || incomplete "não foi possível restaurar modo canônico de ${rels[$index]}"
  done

  {
    printf 'manifest\t1\n'
    printf 'ref\t%s\n' "$REF"
    printf 'prefix\t%s\n' "$PREFIX"
    printf 'capability\tprefix_migration\t1\n'
    printf 'capability\tmanaged_overwrite_documented\t1\n'
    printf 'capability\tsource_workflow_required\t1\n'
    for index in "${!rels[@]}"; do
      printf 'file\t%s\t%s\n' "${rels[$index]}" "${digests[$index]}"
    done
  } >"$manifest_stage"
  mkdir -p "$(dirname "$manifest")"
  if [ ! -f "$manifest" ] || ! cmp -s "$manifest" "$manifest_stage"; then
    tmp="$(mktemp "${manifest}.sdd-new.XXXXXX")"
    PENDING_TEMPS+=("$tmp")
    cp "$manifest_stage" "$tmp"
    chmod 0644 "$tmp"
    mv "$tmp" "$manifest"
  fi
  ok "núcleo SDD coerente e registrado em ${manifest#$PROJECT_DIR/}"
}

persist_global_prefix() {
  local target="$HOME/.sdd/sdd-template.env" tmp
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m persistiria SDD_PREFIX em %s\n' "$target"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  tmp="$(mktemp "${target}.sdd.XXXXXX")"
  printf 'SDD_PREFIX=%s\n' "$PREFIX" >"$tmp"
  if [ -f "$target" ] && cmp -s "$target" "$tmp"; then
    rm -f "$tmp"
  else
    mv "$tmp" "$target"
  fi
}

merge_claude_hooks_json() {
  local source="$1" output="$2" hook_command="$3"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$source" "$output" "$hook_command" <<'PY'
import json
import sys

source, output, hook_command = sys.argv[1:]

def invalid(message):
    print("settings.json inválido para merge seguro: " + message, file=sys.stderr)
    raise SystemExit(2)

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("chave JSON duplicada: " + key)
        result[key] = value
    return result

def reject_constant(value):
    raise ValueError("constante JSON inválida: " + value)

try:
    with open(source, encoding="utf-8") as stream:
        data = json.load(
            stream,
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
    invalid(str(exc))

if not isinstance(data, dict):
    invalid("a raiz deve ser um objeto")
if "hooks" in data and not isinstance(data["hooks"], dict):
    invalid("hooks deve ser um objeto")

changed = False
if "hooks" not in data:
    data["hooks"] = {}
    changed = True
hooks = data["hooks"]
if "PreToolUse" in hooks and not isinstance(hooks["PreToolUse"], list):
    invalid("hooks.PreToolUse deve ser uma lista")
if "PreToolUse" not in hooks:
    hooks["PreToolUse"] = []
    changed = True
pre = hooks["PreToolUse"]

for index, entry in enumerate(pre):
    if not isinstance(entry, dict):
        invalid("hooks.PreToolUse[%d] deve ser um objeto" % index)
    if "hooks" in entry and not isinstance(entry["hooks"], list):
        invalid("hooks.PreToolUse[%d].hooks deve ser uma lista" % index)
    for hook_index, hook in enumerate(entry.get("hooks", [])):
        if not isinstance(hook, dict):
            invalid("hooks.PreToolUse[%d].hooks[%d] deve ser um objeto" % (index, hook_index))

for matcher in ("Edit|Write|MultiEdit|NotebookEdit", "Bash"):
    matching = [entry for entry in pre if entry.get("matcher") == matcher]
    present = any(
        hook.get("type") == "command" and hook.get("command") == hook_command
        for entry in matching
        for hook in entry.get("hooks", [])
    )
    if present:
        continue
    if matching:
        target = matching[0]
        if "hooks" not in target:
            target["hooks"] = []
            changed = True
    else:
        target = {"matcher": matcher, "hooks": []}
        pre.append(target)
        changed = True
    target["hooks"].append({"type": "command", "command": hook_command})
    changed = True

for matcher in ("Edit|Write|MultiEdit|NotebookEdit", "Bash"):
    if not any(
        entry.get("matcher") == matcher
        and any(
            hook.get("type") == "command" and hook.get("command") == hook_command
            for hook in entry.get("hooks", [])
        )
        for entry in pre
    ):
        invalid("hook obrigatório não foi materializado para " + matcher)

if not changed:
    raise SystemExit(10)
with open(output, "w", encoding="utf-8") as stream:
    json.dump(data, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
with open(output, encoding="utf-8") as stream:
    json.load(stream)
PY
    return $?
  fi

  if command -v node >/dev/null 2>&1; then
    node - "$source" "$output" "$hook_command" <<'JS'
const fs = require("fs");
const [source, output, hookCommand] = process.argv.slice(2);

function invalid(message) {
  console.error(`settings.json inválido para merge seguro: ${message}`);
  process.exit(2);
}

let data;
const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
try {
  data = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  invalid(error.message);
}
if (data === null || Array.isArray(data) || typeof data !== "object") {
  invalid("a raiz deve ser um objeto");
}
if (hasOwn(data, "hooks") && (data.hooks === null || Array.isArray(data.hooks) || typeof data.hooks !== "object")) {
  invalid("hooks deve ser um objeto");
}

let changed = false;
if (!hasOwn(data, "hooks")) {
  data.hooks = {};
  changed = true;
}
if (hasOwn(data.hooks, "PreToolUse") && !Array.isArray(data.hooks.PreToolUse)) {
  invalid("hooks.PreToolUse deve ser uma lista");
}
if (!hasOwn(data.hooks, "PreToolUse")) {
  data.hooks.PreToolUse = [];
  changed = true;
}
const pre = data.hooks.PreToolUse;
pre.forEach((entry, index) => {
  if (entry === null || Array.isArray(entry) || typeof entry !== "object") {
    invalid(`hooks.PreToolUse[${index}] deve ser um objeto`);
  }
  if (hasOwn(entry, "hooks") && !Array.isArray(entry.hooks)) {
    invalid(`hooks.PreToolUse[${index}].hooks deve ser uma lista`);
  }
  (entry.hooks || []).forEach((hook, hookIndex) => {
    if (hook === null || Array.isArray(hook) || typeof hook !== "object") {
      invalid(`hooks.PreToolUse[${index}].hooks[${hookIndex}] deve ser um objeto`);
    }
  });
});

for (const matcher of ["Edit|Write|MultiEdit|NotebookEdit", "Bash"]) {
  const matching = pre.filter((entry) => entry.matcher === matcher);
  const present = matching.some((entry) =>
    (entry.hooks || []).some((hook) => hook.type === "command" && hook.command === hookCommand));
  if (present) continue;
  let target;
  if (matching.length) {
    target = matching[0];
    if (!hasOwn(target, "hooks")) {
      target.hooks = [];
      changed = true;
    }
  } else {
    target = {matcher, hooks: []};
    pre.push(target);
    changed = true;
  }
  target.hooks.push({type: "command", command: hookCommand});
  changed = true;
}

for (const matcher of ["Edit|Write|MultiEdit|NotebookEdit", "Bash"]) {
  const installed = pre.some((entry) =>
    entry.matcher === matcher
      && (entry.hooks || []).some((hook) => hook.type === "command" && hook.command === hookCommand));
  if (!installed) invalid(`hook obrigatório não foi materializado para ${matcher}`);
}

if (!changed) process.exit(10);
fs.writeFileSync(output, JSON.stringify(data, null, 2) + "\n", "utf8");
JSON.parse(fs.readFileSync(output, "utf8"));
JS
    return $?
  fi

  return 127
}

install_claude_hooks() {
  local settings="$1" hook_command="sdd/governanca/sdd-hook-claude.sh"
  local source tmp rc=0
  assert_safe_destination "$settings"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m faria merge estrutural de hooks em %s\n' "$settings"
    return 0
  fi
  # O hook canônico usa python3 para parsing fail-closed do payload; instalar
  # apenas o settings sem essa dependência deixaria o enforcement inutilizável.
  command -v python3 >/dev/null 2>&1 \
    || incomplete "hooks do Claude não instalados: python3 é obrigatório para o enforcement"
  if [ -e "$settings" ] && [ ! -f "$settings" ]; then
    incomplete ".claude/settings.json não é um arquivo regular; enforcement não instalado"
  fi

  mkdir -p "$(dirname "$settings")"
  source="$settings"
  if [ ! -f "$source" ]; then
    source="$WORK_DIR/empty-claude-settings.json"
    printf '{}\n' >"$source"
  fi
  tmp="$(mktemp "${settings}.sdd-new.XXXXXX")"
  PENDING_TEMPS+=("$tmp")
  [ ! -f "$settings" ] || cp -p "$settings" "$tmp"

  merge_claude_hooks_json "$source" "$tmp" "$hook_command" || rc=$?
  case "$rc" in
    0)
      mv "$tmp" "$settings"
      ok "hooks do Claude Code mesclados atomicamente em .claude/settings.json"
      ;;
    10)
      rm -f "$tmp"
      ok "preservado: hooks SDD já instalados estruturalmente em .claude/settings.json"
      ;;
    127)
      rm -f "$tmp"
      incomplete "hooks do Claude não instalados: processador JSON indisponível"
      ;;
    *)
      rm -f "$tmp"
      incomplete ".claude/settings.json não pôde ser validado/mesclado; enforcement não instalado"
      ;;
  esac
}

validate_existing_project_policy() {
  local policy candidate version rc=0
  [ "$SCOPE" = project ] || return 0
  policy="$PROJECT_DIR/sdd/governanca/policies.yaml"
  [ -f "$policy" ] || return 0
  candidate="$PROJECT_DIR/sdd/governanca/policies.yaml.v2.example"
  assert_safe_destination "$policy"
  assert_safe_destination "$candidate"
  version="$(awk '
    /^version:[[:space:]]*/ {
      count++
      value=$0
      sub(/^version:[[:space:]]*/, "", value)
      sub(/[[:space:]]+#.*/, "", value)
      gsub(/[[:space:]]/, "", value)
    }
    END { if (count != 1) exit 1; print value }
  ' "$policy" 2>/dev/null)" || version=""

  if [ "$version" != 2 ]; then
    if [ ! -e "$candidate" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf '\033[2m[dry-run]\033[0m criaria referência de migração em %s\n' "${candidate#$PROJECT_DIR/}"
      else
        mkdir -p "$(dirname "$candidate")"
        cp "$SRC_DIR/governanca/policies.yaml.example" "$candidate"
      fi
    fi
    incomplete "policies.yaml version ${version:-desconhecida} exige migração; compare com ${candidate#$PROJECT_DIR/}"
  fi

  (cd "$PROJECT_DIR" && unset SDD_POLICIES_FILE SDD_TRUSTED_POLICIES \
    && bash "$SRC_DIR/governanca/sdd-guard.sh" validate-policy >/dev/null) \
    || rc=$?
  if [ "$rc" -ne 0 ]; then
    if [ ! -e "$candidate" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf '\033[2m[dry-run]\033[0m criaria referência de migração em %s\n' "${candidate#$PROJECT_DIR/}"
      else
        cp "$SRC_DIR/governanca/policies.yaml.example" "$candidate"
      fi
    fi
    incomplete "policies.yaml não pertence ao subset canônico; compare com ${candidate#$PROJECT_DIR/}"
  fi
}

validate_existing_project_policy

info "Instalando prompts canônicos em $CANON_DIR"
run mkdir -p "$CANON_DIR"
for name in $PROMPTS; do
  run cp "$SRC_DIR/$name.md" "$CANON_DIR/$name.md"
done
run cp "$SRC_DIR/_comum.md" "$CANON_DIR/_comum.md"
if [ -d "$SRC_DIR/docs" ]; then
  run mkdir -p "$CANON_DIR/docs"
  for doc in "$SRC_DIR"/docs/*.md; do
    [ -e "$doc" ] && run cp "$doc" "$CANON_DIR/docs/"
  done
fi

adapter_body() {
  local file="$1"
  cat <<EOF
Execute uma etapa do fluxo SDD.

1. Leia \`$CANON_REF/_comum.md\`.
2. Leia \`$CANON_REF/$file\` e siga-o.
3. Use os argumentos como slug, contexto e limites.
4. Não exceda a autoridade registrada no incremento.

Argumentos do usuário: \$ARGUMENTS
EOF
}

agent_body() {
  local step="$1"
  cat <<EOF
Você é um verificador independente do fluxo SDD e roda em contexto isolado.

1. Leia \`$CANON_REF/_comum.md\`.
2. Leia \`$CANON_REF/$step.md\`.
3. Exija um \`[feature]\` explícito e confirme o escopo antes de avaliar.
4. Siga exatamente o contrato do prompt canônico, sem completar lacunas por suposição.
5. Inspecione evidências reais; não herde conclusões da sessão implementadora.
6. Gere os artefatos obrigatórios e registre lacunas, limitações e itens não verificados.
EOF
}

install_claude() {
  local name desc slug extra aname
  for name in $PROMPTS; do
    desc="$(step_desc "$name")"
    slug="$(skill_slug "$name")"
    extra=""
    if is_agent_step "$name"; then
      aname="$(agent_name "$name")"
      extra="$(printf 'context: fork\nagent: %s' "$aname")"
      write_file "$CLAUDE_AGENTS/$aname.md" <<EOF
---
name: $aname
description: "$(agent_desc "$name")."
---

$(agent_body "$name")
EOF
    fi
    write_file "$CLAUDE_SKILLS/$slug/SKILL.md" <<EOF
---
description: "$desc"
argument-hint: "[feature] [contexto]"
disable-model-invocation: true
${extra:+$extra
}---

$(adapter_body "$name.md")
EOF
  done
  ok "Claude Code: 15 skills e 3 agents"
}

install_codex() {
  local name desc slug aname
  for name in $PROMPTS; do
    desc="$(step_desc "$name")"
    slug="$(skill_slug "$name")"
    write_file "$CODEX_SKILLS/$slug/SKILL.md" <<EOF
---
name: $slug
description: "$desc. Use somente por invocação explícita."
---

$(adapter_body "$name.md")
EOF
  done
  for name in $AGENT_STEPS; do
    aname="$(agent_name "$name")"
    write_file "$CODEX_AGENTS/$aname.toml" <<EOF
name = "$aname"
description = "$(agent_desc "$name")"
developer_instructions = """
$(agent_body "$name")
"""
EOF
  done
  ok "Codex: 15 skills e 3 agents"
}

install_opencode() {
  local name desc slug extra aname
  for name in $PROMPTS; do
    desc="$(step_desc "$name")"
    slug="$(skill_slug "$name")"
    extra=""
    if is_agent_step "$name"; then
      aname="$(agent_name "$name")"
      extra="$(printf 'agent: %s\nsubtask: true' "$aname")"
      write_file "$OPENCODE_AGENTS/$aname.md" <<EOF
---
description: "$(agent_desc "$name")"
mode: subagent
---

$(agent_body "$name")
EOF
    fi
    write_file "$OPENCODE_CMDS/$slug.md" <<EOF
---
description: "$desc"
${extra:+$extra
}---

$(adapter_body "$name.md")
EOF
  done
  ok "OpenCode: 15 commands e 3 agents"
}

has_tool claude && install_claude
has_tool codex && install_codex
has_tool opencode && install_opencode

# A configuração antiga continua sendo a fonte de retomada até que todos os
# adapters legados tenham sido removidos. Se a limpeza falhar, a próxima
# execução ainda descobre MIGRATE_FROM_PREFIX e conclui a mesma migração.
if [ -n "$MIGRATE_FROM_PREFIX" ]; then
  info "Finalizando migração de adapters de $MIGRATE_FROM_PREFIX para $PREFIX"
  remove_adapters_for_prefix "$MIGRATE_FROM_PREFIX"
fi

[ "$SCOPE" != "global" ] || persist_global_prefix

if [ "$SCOPE" = "project" ]; then
  info "Criando estrutura do projeto"
  run mkdir -p \
    "$PROJECT_DIR/sdd/contratos" \
    "$PROJECT_DIR/sdd/incrementos" \
    "$PROJECT_DIR/sdd/historico" \
    "$PROJECT_DIR/sdd/aprendizados" \
    "$PROJECT_DIR/sdd/governanca" \
    "$PROJECT_DIR/sdd/evals/cases" \
    "$PROJECT_DIR/.compozy/tasks"

  if [ ! -f "$PROJECT_DIR/.compozy/config.toml" ] \
     && [ -f "$SRC_DIR/compozy-config.toml.example" ]; then
    run cp "$SRC_DIR/compozy-config.toml.example" \
      "$PROJECT_DIR/.compozy/config.toml"
  fi

  [ ! -f "$SRC_DIR/governanca/policies.yaml.example" ] \
    || copy_if_absent "$SRC_DIR/governanca/policies.yaml.example" \
      "$PROJECT_DIR/sdd/governanca/policies.yaml"

  # Código do harness é promovido como um único bundle versionado. Arquivos
  # divergentes do último manifest são preservados antes da atualização.
  install_managed_bundle

  # Detector operacional: exemplos, porque dependem de métricas do projeto.
  for example in sdd-watch.sh.example watch.yaml.example; do
    [ ! -f "$SRC_DIR/governanca/$example" ] \
      || copy_if_absent "$SRC_DIR/governanca/$example" \
        "$PROJECT_DIR/sdd/governanca/$example"
  done

  [ ! -f "$SRC_DIR/evals/README.md" ] \
    || copy_if_absent "$SRC_DIR/evals/README.md" \
      "$PROJECT_DIR/sdd/evals/README.md"

  # Hooks determinísticos do Claude Code (enforcement enquanto o agente age).
  if has_tool claude; then
    claude_settings="$PROJECT_DIR/.claude/settings.json"
    install_claude_hooks "$claude_settings"
  fi

  agents_file="$PROJECT_DIR/AGENTS.md"
  assert_safe_destination "$agents_file"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m atualizaria %s\n' "$agents_file"
  else
    block="$(mktemp)"
    cat >"$block" <<EOF
$MARKER_BEGIN
Este projeto usa SDD com contratos vivos e gates AI-native.

- Regras: \`sdd/prompts/_comum.md\`.
- Etapas: \`sdd/prompts/00-*.md\` a \`14-*.md\`.
- Comportamento consolidado: \`sdd/contratos/\`.
- Plano ativo: \`sdd/incrementos/[feature]/execucao.md\`.
- Policies: \`sdd/governanca/policies.yaml\`.
- Guard: \`sdd/governanca/sdd-guard.sh\` (gates determinísticos).
- Próximo passo do loop: \`sdd/governanca/sdd-fluxo.sh [feature]\`.
- Métricas: \`sdd/governanca/sdd-metricas.sh [feature]\`.
- Evals do harness: \`sdd/evals/run-evals.sh --tier1\`.
- Detector operacional: \`sdd/governanca/sdd-watch.sh\` (copie do \`.example\`).
- Não altere \`sdd/contratos/\` antes do passo 13.
- Parecer do agente não substitui gate humano.
- Sem commit, push, PR, merge ou deploy fora da autoridade registrada.
$MARKER_END
EOF
    install_agents_block "$agents_file" "$block"
    rm -f "$block"
  fi
fi

install_compozy() {
  if command -v compozy >/dev/null 2>&1; then
    ok "Compozy já instalado"
    return
  fi
  info "Instalando Compozy"
  if command -v brew >/dev/null 2>&1; then
    run brew install compozy/compozy/compozy
  elif command -v npm >/dev/null 2>&1; then
    run npm install -g @compozy/cli
  elif command -v go >/dev/null 2>&1; then
    run go install github.com/compozy/compozy/cmd/compozy@latest
  else
    warn "Instale o Compozy manualmente: https://github.com/compozy/compozy"
  fi
}

[ "$INSTALL_COMPOZY" -eq 0 ] || install_compozy

echo
ok "SDD instalado"
if [ "$SCOPE" = "project" ]; then
  printf 'Próximo passo: /%s-instalar-rules-skills ou /%s-iniciar-incremento\n' \
    "$PREFIX" "$PREFIX"
else
  printf 'Reinicie o harness e invoque /%s-iniciar-incremento\n' "$PREFIX"
fi
