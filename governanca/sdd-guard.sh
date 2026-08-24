#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Uso:
  sdd-guard.sh pre-specify <feature>
  sdd-guard.sh pre-implement <feature> <task_NN>
  sdd-guard.sh pre-complete <feature> <task_NN>
  sdd-guard.sh pre-validate <feature>
  sdd-guard.sh pre-merge <feature>
  sdd-guard.sh pre-merge-ci <feature>          # metadados; nunca executa codigo candidato
  sdd-guard.sh pre-production <feature>
  sdd-guard.sh pre-consolidate <feature>
  sdd-guard.sh authority-check <feature> <gate> [target]
  sdd-guard.sh validate-policy
  sdd-guard.sh protect <caminho>
  sdd-guard.sh protect-ci <caminho>       # usa autoridade externa para contratos
  sdd-guard.sh scan-secrets <arquivo>...
  sdd-guard.sh scan-content <caminho-logico> <arquivo-conteudo>...
  sdd-guard.sh review-required <feature>
USAGE
}

fail()  { printf 'SDD GUARD: %s\n' "$*" >&2; exit 1; }
fail2() { printf 'SDD GUARD (bloqueado): %s\n' "$*" >&2; exit 2; }
ok()    { printf 'SDD GUARD: OK - %s\n' "$*"; }

[ $# -ge 1 ] || { usage; exit 2; }

command_name="$1"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
root="$(cd "$root" && pwd -P)"

canonical_external_file() {
  local candidate="$1" directory resolved
  case "$candidate" in /*) ;; *) return 1 ;; esac
  case "/${candidate#/}/" in */../*|*/./*) return 1 ;; esac
  [ -f "$candidate" ] && [ ! -L "$candidate" ] || return 1
  directory="$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)" || return 1
  resolved="$directory/$(basename "$candidate")"
  [ -f "$resolved" ] && [ ! -L "$resolved" ] || return 1
  case "$resolved" in "$root"|"$root"/*) return 1 ;; esac
  printf '%s' "$resolved"
}

if [ -n "${SDD_POLICIES_FILE:-}" ]; then
  policies="$(canonical_external_file "$SDD_POLICIES_FILE")" || {
    printf 'SDD GUARD: SDD_POLICIES_FILE deve ser arquivo canonico fora do worktree\n' >&2
    exit 1
  }
elif [ -f "$root/sdd/governanca/policies.yaml" ]; then
  policies="$root/sdd/governanca/policies.yaml"
elif [ -f "$root/governanca/policies.yaml" ]; then
  policies="$root/governanca/policies.yaml"
elif [ -f "$root/governanca/policies.yaml.example" ]; then
  # Permite que o proprio repositorio do template valide seu exemplo canonico.
  policies="$root/governanca/policies.yaml.example"
else
  policies="$root/sdd/governanca/policies.yaml"
fi

feature="${2:-}"
task="${3:-}"
inc=""
wf=""
yaml=""
audit=""
review=""

init_feature() {
  [[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || fail "feature invalida: use somente letras, numeros, ponto, '_' e '-'"
  inc="$root/sdd/incrementos/$feature"
  wf="$root/.compozy/tasks/$feature"
  yaml="$inc/incremento.yaml"
  audit="$wf/auditoria-especificacao.md"
  review="$wf/reviews-001/review-report.md"
}

require_file() {
  [ -f "$1" ] || fail "arquivo obrigatorio ausente: ${1#$root/}"
  [ ! -L "$1" ] || fail "arquivo obrigatorio nao pode ser symlink: ${1#$root/}"
}

# Parser do subset YAML canonico aceito pelo guard:
# - mapas com indentacao exata de dois espacos;
# - listas escalares ou listas de mapas;
# - escalares plain, com aspas simples/duplas, ou lista vazia [];
# - sem tabs, anchors, aliases, tags, block scalars, flow maps ou flow lists.
# A saida interna e: tipo<TAB>caminho<TAB>valor.
canonical_yaml_dump() {
  local file="$1"
  awk '
    function die(message) {
      printf "YAML canonico invalido em %s:%d: %s\n", FILENAME, NR, message > "/dev/stderr"
      exit 2
    }
    function ltrim(value) { sub(/^[ ]+/, "", value); return value }
    function rtrim(value) { sub(/[ ]+$/, "", value); return value }
    function trim(value) { return rtrim(ltrim(value)) }
    function strip_comment(raw,    i,c,quote,escaped,out,previous) {
      quote = ""
      escaped = 0
      out = ""
      for (i = 1; i <= length(raw); i++) {
        c = substr(raw, i, 1)
        previous = (i > 1) ? substr(raw, i - 1, 1) : ""
        if (escaped) {
          out = out c
          escaped = 0
          continue
        }
        if (quote == "\"" && c == "\\") {
          out = out c
          escaped = 1
          continue
        }
        if (c == "\"" || c == "\047") {
          if (quote == "") quote = c
          else if (quote == c) quote = ""
          out = out c
          continue
        }
        if (c == "#" && quote == "" && (i == 1 || previous == " ")) break
        out = out c
      }
      if (quote != "") die("aspas nao fechadas")
      return rtrim(out)
    }
    function clear_from(level, i) {
      for (i = level; i < 80; i++) delete parent[i]
    }
    function decode(raw,    first,last,inner,out,i,ch,nextch) {
      raw = trim(strip_comment(raw))
      if (raw == "") { decoded = ""; return 1 }
      if (raw == "[]") { decoded = "[]"; return 2 }
      first = substr(raw, 1, 1)
      last = substr(raw, length(raw), 1)
      if (first == "\"") {
        if (length(raw) < 2 || last != "\"") die("aspas duplas nao fechadas")
        inner = substr(raw, 2, length(raw) - 2)
        out = ""
        for (i = 1; i <= length(inner); i++) {
          ch = substr(inner, i, 1)
          if (ch == "\\") {
            i++
            if (i > length(inner)) die("escape incompleto")
            nextch = substr(inner, i, 1)
            if (nextch != "\\" && nextch != "\"" && nextch != "/") {
              die("escape nao suportado; escape a barra como \\\\")
            }
            out = out nextch
          } else if (ch == "\"") {
            die("aspas duplas internas devem ser escapadas")
          } else {
            out = out ch
          }
        }
        decoded = out
      } else if (first == "\047") {
        if (length(raw) < 2 || last != "\047") die("aspas simples nao fechadas")
        inner = substr(raw, 2, length(raw) - 2)
        out = ""
        for (i = 1; i <= length(inner); i++) {
          ch = substr(inner, i, 1)
          if (ch == "\047") {
            if (substr(inner, i + 1, 1) != "\047") die("aspas simples internas devem ser duplicadas")
            i++
          }
          out = out ch
        }
        decoded = out
      } else {
        if (first ~ /[-?:,\[\]{}#&*!|>@`]/ || first == "\047" || first == "%") {
          die("escalar plain com prefixo reservado")
        }
        if (raw ~ /[ ]#/ || raw ~ /:[ ]/) die("comentario inline ou mapa inline nao suportado")
        if (raw ~ /^[[]/ || raw ~ /[]]$/) die("somente a flow list vazia [] e aceita")
        decoded = raw
      }
      if (decoded ~ /[\t\r\n]/) die("caractere de controle em escalar")
      return 1
    }
    function emit(kind, path, value) {
      if (seen[path]++) die("chave duplicada: " path)
      printf "%s\t%s\t%s\n", kind, path, value
    }
    BEGIN { parent[0] = "" }
    {
      sub(/\r$/, "")
      if (index($0, "\t")) die("tabs nao sao permitidos")
      if ($0 ~ /^[ ]*(#|$)/) next
      match($0, /^[ ]*/)
      indent = RLENGTH
      if (indent % 2) die("indentacao deve ser multipla de dois")
      level = indent / 2
      if (!(level in parent)) die("salto de indentacao ou pai escalar")
      line = substr($0, indent + 1)
      line = rtrim(line)
      clear_from(level + 1)

      if (line ~ /^-([ ]|$)/) {
        if (parent[level] == "") die("lista sem chave pai")
        item = substr(line, 2)
        item = ltrim(item)
        if (item == "") die("item de lista vazio nao suportado")
        list_count[parent[level]]++
        item_path = parent[level] "[" list_count[parent[level]] "]"
        printf "I\t%s\t\n", item_path

        colon = index(item, ":")
        if (colon > 1 && substr(item, 1, colon - 1) ~ /^[A-Za-z_][A-Za-z0-9_-]*$/) {
          key = substr(item, 1, colon - 1)
          rest = substr(item, colon + 1)
          if (rest != "" && substr(rest, 1, 1) != " ") die("use um espaco depois de :")
          rest = trim(rest)
          path = item_path "." key
          parent[level + 1] = item_path
          if (rest == "") {
            emit("C", path, "")
            parent[level + 2] = path
          } else {
            kind = decode(rest)
            if (kind == 2) emit("E", path, "")
            else emit("S", path, decoded)
          }
        } else {
          kind = decode(item)
          if (kind == 2) die("[] nao e item escalar de lista")
          printf "L\t%s\t%s\n", parent[level], decoded
        }
        next
      }

      colon = index(line, ":")
      if (colon <= 1) die("esperado mapeamento chave: valor")
      key = substr(line, 1, colon - 1)
      if (key !~ /^[A-Za-z_][A-Za-z0-9_-]*$/) die("chave fora do subset canonico: " key)
      rest = substr(line, colon + 1)
      if (rest != "" && substr(rest, 1, 1) != " ") die("use um espaco depois de :")
      rest = trim(rest)
      path = (parent[level] == "" ? key : parent[level] "." key)
      if (rest == "") {
        emit("C", path, "")
        parent[level + 1] = path
      } else {
        kind = decode(rest)
        if (kind == 2) emit("E", path, "")
        else emit("S", path, decoded)
      }
    }
  ' "$file"
}

policy_data=""
policy_loaded=0
policy_schema_validated=0
policy_load_reason=""

load_policies() {
  local output version rc=0
  [ "$policy_loaded" -eq 0 ] || return 0
  if [ ! -f "$policies" ] || [ -L "$policies" ]; then
    policy_load_reason="policies ausente ou symlink: ${policies#$root/}"
    return 1
  fi
  if ! output="$(canonical_yaml_dump "$policies")"; then
    policy_load_reason="policies malformada: ${policies#$root/}"
    return 1
  fi
  version="$(dump_scalar "$output" version)" || rc=$?
  if [ "$rc" -ne 0 ] || [[ ! "$version" =~ ^(1|2)$ ]]; then
    policy_load_reason="policies sem version suportada (1 ou 2): ${policies#$root/}"
    return 1
  fi
  policy_data="$output"
  policy_loaded=1
}

require_policies() {
  load_policies || fail "$policy_load_reason"
  if [ "$policy_schema_validated" -eq 0 ]; then
    validate_policy_schema || fail "policies nao atende ao schema version 2"
    policy_schema_validated=1
  fi
}

dump_scalar() {
  local dump="$1" path="$2"
  awk -F '\t' -v wanted="$path" '
    $1 == "S" && $2 == wanted { print substr($0, length($1) + length($2) + 3); found++ }
    END { if (found > 1) exit 2; if (!found) exit 1 }
  ' <<<"$dump"
}

dump_optional_scalar() {
  local dump="$1" path="$2" value rc=0
  value="$(dump_scalar "$dump" "$path")" || rc=$?
  case "$rc" in
    0) printf '%s' "$value" ;;
    1) return 0 ;;
    *) return "$rc" ;;
  esac
}

dump_has_path() {
  local dump="$1" path="$2"
  awk -F '\t' -v wanted="$path" '
    ($1 == "S" || $1 == "C" || $1 == "E" || $1 == "L") && $2 == wanted { found = 1 }
    END { exit(found ? 0 : 1) }
  ' <<<"$dump"
}

dump_list() {
  local dump="$1" path="$2"
  awk -F '\t' -v wanted="$path" '
    $1 == "L" && $2 == wanted { print substr($0, length($1) + length($2) + 3) }
  ' <<<"$dump"
}

validate_policy_dump_schema() {
  local dump="$1"
  python3 -c '
import re
import sys

records = []
for raw in sys.stdin:
    parts = raw.rstrip("\n").split("\t", 2)
    if len(parts) != 3:
        raise SystemExit("registro interno de policy invalido")
    records.append(tuple(parts))

by_path = {}
for kind, path, value in records:
    by_path.setdefault(path, []).append((kind, value))

def one(path, kinds=("S",)):
    values = by_path.get(path, [])
    if len(values) != 1 or values[0][0] not in kinds:
        raise SystemExit(f"policy exige {path} com tipo {kinds}")
    return values[0][1]

allowed = [
    re.compile(r"version"),
    re.compile(r"project(?:\.(?:language|default_target_branch))?"),
    re.compile(r"protected_paths(?:\[[1-9][0-9]*\](?:\.(?:path|access|writable_only_in_step))?)?"),
    re.compile(r"gates(?:\.(?:pre_specify|pre_implement|pre_complete|pre_validate|pre_merge|pre_production|pre_consolidate)(?:\.require(?:\[[1-9][0-9]*\](?:\.[a-z_][a-z0-9_-]*)?)?)?)?"),
    re.compile(r"authority(?:\.(?:check_command|check_sha256|timeout_seconds|assistido|autonomo_ate_pr|autonomo_ate_staging|producao_com_gate)(?:\.(?:commit|push|pull_request|merge|staging|production))?)?"),
    re.compile(r"quality_commands(?:\.(?:common|lint|typecheck|build|test|e2e)(?:\[[1-9][0-9]*\])?)?"),
    re.compile(r"secrets(?:\.(?:forbidden_patterns|allowed_files)(?:\[[1-9][0-9]*\])?)?"),
    re.compile(r"production(?:\.(?:approval_max_age_minutes|require_rollback|require_health_checks))?"),
    re.compile(r"consolidation(?:\.attestation_ttl_seconds)?"),
    re.compile(r"guard_commands(?:\.(?:pre_specify|pre_implement|pre_complete|pre_validate|pre_merge|pre_merge_ci|pre_production|pre_consolidate|authority_check|protect_ci))?"),
]
for _, path, _ in records:
    if not any(pattern.fullmatch(path) for pattern in allowed):
        raise SystemExit(f"chave desconhecida em policies: {path}")

if one("version") != "2":
    raise SystemExit("policies operacional deve usar version 2")
for path in ("project.language", "project.default_target_branch"):
    if not one(path):
        raise SystemExit(f"policy vazia: {path}")

timeout = one("authority.timeout_seconds")
if not timeout.isdigit() or not 1 <= int(timeout) <= 300:
    raise SystemExit("authority.timeout_seconds deve estar entre 1 e 300")
checker = one("authority.check_command")
if checker and not checker.startswith("/"):
    raise SystemExit("authority.check_command deve ser vazio ou absoluto")
checker_sha = one("authority.check_sha256")
if checker:
    if not re.fullmatch(r"[0-9a-f]{64}", checker_sha):
        raise SystemExit("authority.check_sha256 deve fixar o checker em hexadecimal lowercase")
elif checker_sha:
    raise SystemExit("authority.check_sha256 deve ser vazio sem check_command")

actions = ("commit", "push", "pull_request", "merge", "staging", "production")
expected = {
    "assistido": ("explicit_external",) * 5 + ("explicit_external",),
    "autonomo_ate_pr": ("external_scope", "external_scope", "external_scope", "explicit_external", "explicit_external", "explicit_external"),
    "autonomo_ate_staging": ("external_scope", "external_scope", "external_scope", "explicit_external", "external_scope", "explicit_external"),
    "producao_com_gate": ("external_scope", "external_scope", "external_scope", "explicit_external", "external_scope", "explicit_external_recent"),
}
for mode, values in expected.items():
    for action, wanted in zip(actions, values):
        actual = one(f"authority.{mode}.{action}")
        if actual != wanted:
            raise SystemExit(f"authority.{mode}.{action} deve ser {wanted}")

for gate in ("pre_specify", "pre_implement", "pre_complete", "pre_validate", "pre_merge", "pre_production", "pre_consolidate"):
    prefix = f"gates.{gate}.require["
    if not any(path.startswith(prefix) and kind == "I" for kind, path, _ in records):
        raise SystemExit(f"gates.{gate}.require deve conter requisitos")

for category in ("lint", "typecheck", "build", "test", "e2e"):
    path = f"quality_commands.{category}"
    values = by_path.get(path, [])
    if not values or not any(kind in {"E", "L"} for kind, _ in values) or any(kind not in {"C", "E", "L"} for kind, _ in values):
        raise SystemExit(f"{path} deve ser lista canonica")

for path in ("secrets.forbidden_patterns", "secrets.allowed_files"):
    values = by_path.get(path, [])
    if not values or not any(kind in {"E", "L"} for kind, _ in values) or any(kind not in {"C", "E", "L"} for kind, _ in values):
        raise SystemExit(f"{path} deve ser lista canonica")
if not any(kind == "L" and path == "secrets.forbidden_patterns" and value for kind, path, value in records):
    raise SystemExit("secrets.forbidden_patterns nao pode ser vazia")

age = one("production.approval_max_age_minutes")
if not age.isdigit() or int(age) < 1:
    raise SystemExit("production.approval_max_age_minutes invalido")
for path in ("production.require_rollback", "production.require_health_checks"):
    if one(path) != "true":
        raise SystemExit(f"{path} deve ser true")
ttl = one("consolidation.attestation_ttl_seconds")
if not ttl.isdigit() or not 1 <= int(ttl) <= 3600:
    raise SystemExit("consolidation.attestation_ttl_seconds deve estar entre 1 e 3600")

for command in ("pre_specify", "pre_implement", "pre_complete", "pre_validate", "pre_merge", "pre_merge_ci", "pre_production", "pre_consolidate", "authority_check", "protect_ci"):
    if not one(f"guard_commands.{command}"):
        raise SystemExit(f"guard_commands.{command} nao pode ser vazio")
' <<<"$dump"
}

validate_policy_schema() {
  local index pattern normalized access step unknown
  validate_policy_dump_schema "$policy_data" || return 1
  while IFS= read -r index; do
    [ -n "$index" ] || continue
    unknown="$(awk -F '\t' -v prefix="protected_paths[$index]." '
      index($2, prefix) == 1 {
        key = substr($2, length(prefix) + 1)
        if (key != "path" && key != "access" && key != "writable_only_in_step") print key
      }
    ' <<<"$policy_data")"
    [ -z "$unknown" ] || { printf 'atributo protegido desconhecido: %s\n' "$unknown" >&2; return 1; }
    pattern="$(dump_optional_scalar "$policy_data" "protected_paths[$index].path")"
    [ -n "$pattern" ] || { printf 'protected_paths[%s].path ausente\n' "$index" >&2; return 1; }
    normalized="$(normalize_policy_pattern "$pattern")" || {
      printf 'protected_paths[%s].path inseguro\n' "$index" >&2
      return 1
    }
    access="$(dump_optional_scalar "$policy_data" "protected_paths[$index].access")"
    step="$(dump_optional_scalar "$policy_data" "protected_paths[$index].writable_only_in_step")"
    [ -n "$access" ] || { [ -n "$step" ] && access=step || access=deny; }
    case "$access" in deny|deny_unless_explicit) [ -z "$step" ] || return 1 ;; step) [ "$step" = pre-consolidate ] || [ "$step" = 13 ] || return 1 ;; *) return 1 ;; esac
  done < <(protected_record_indexes)
  [ -n "$(protected_record_indexes)" ] || { printf 'protected_paths nao pode ser vazio\n' >&2; return 1; }
}

policy_scalar() {
  local path="$1" value rc=0
  require_policies
  value="$(dump_scalar "$policy_data" "$path")" || rc=$?
  [ "$rc" -eq 0 ] || fail "chave obrigatoria ausente em policies: $path"
  printf '%s' "$value"
}

policy_optional_scalar() {
  require_policies
  dump_optional_scalar "$policy_data" "$1"
}

yaml_data=""
yaml_loaded=0

load_increment() {
  local output
  [ "$yaml_loaded" -eq 0 ] || return 0
  require_file "$yaml"
  output="$(canonical_yaml_dump "$yaml")" \
    || fail "incremento.yaml fora do subset YAML canonico"
  yaml_data="$output"
  yaml_loaded=1
}

yaml_scalar() {
  local path="$1" value rc=0
  load_increment
  value="$(dump_scalar "$yaml_data" "$path")" || rc=$?
  [ "$rc" -eq 0 ] || fail "chave obrigatoria ausente em incremento.yaml: $path"
  printf '%s' "$value"
}

yaml_optional_scalar() {
  load_increment
  dump_optional_scalar "$yaml_data" "$1"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

current_head() {
  local head
  head="$(git -C "$root" rev-parse --verify HEAD 2>/dev/null)" \
    || return 1
  [[ "$head" =~ ^[0-9a-fA-F]{40,64}$ ]] || return 1
  printf '%s' "$head"
}

authority_check_external() {
  local auth_feature="$1" gate="$2" target="$3"
  local configured resolved resolved_dir expected_sha actual_sha timeout_seconds head rc=0
  local checker_dir checker_copy clean_path env_bin timeout_bin python_bin
  local authority_data authority_path trusted trusted_resolved version autonomy="" decision=""

  [ "$gate" != producao ] || gate=production

  trusted="${SDD_TRUSTED_POLICIES:-}"
  if [ -n "$trusted" ]; then
    trusted_resolved="$(canonical_external_file "$trusted")" || {
      printf 'SDD GUARD: policy confiavel deve ser canonica e estar fora do worktree\n' >&2
      return 1
    }
    authority_data="$(canonical_yaml_dump "$trusted_resolved")" || {
      printf 'SDD GUARD: policy confiavel malformada\n' >&2
      return 1
    }
    version="$(dump_optional_scalar "$authority_data" version)"
    [ "$version" = 2 ] && validate_policy_dump_schema "$authority_data" || {
      printf 'SDD GUARD: policy confiavel nao atende ao schema version 2\n' >&2
      return 1
    }
    authority_path="$trusted_resolved"
  else
    load_policies || { printf 'SDD GUARD: %s\n' "$policy_load_reason" >&2; return 1; }
    validate_policy_schema || {
      printf 'SDD GUARD: policies nao atende ao schema version 2\n' >&2
      return 1
    }
    policy_schema_validated=1
    authority_data="$policy_data"
    authority_path="$policies"
  fi

  case "$gate" in
    commit|push|pull_request|merge|staging|production)
      feature="$auth_feature"
      init_feature
      load_increment
      autonomy="$(yaml_scalar 'classificacao.autonomia')"
      case "$autonomy" in assistido|autonomo_ate_pr|autonomo_ate_staging|producao_com_gate) ;; *)
        printf 'SDD GUARD: classificacao.autonomia invalida para autoridade\n' >&2
        return 1
        ;;
      esac
      decision="$(dump_optional_scalar "$authority_data" "authority.$autonomy.$gate")"
      case "$decision" in explicit_external|external_scope|explicit_external_recent) ;;
        *)
          printf 'SDD GUARD: authority.%s.%s ausente ou invalida\n' "$autonomy" "$gate" >&2
          return 1
          ;;
      esac
      ;;
  esac

  configured="$(dump_optional_scalar "$authority_data" 'authority.check_command')" || return 1
  [ -n "$configured" ] || {
    printf 'SDD GUARD: authority.check_command vazio; nenhuma aprovacao e presumida\n' >&2
    return 1
  }
  case "$configured" in
    /*) ;;
    *)
      printf 'SDD GUARD: authority.check_command deve ser caminho absoluto fora do worktree\n' >&2
      return 1
      ;;
  esac
  [ -f "$configured" ] && [ ! -L "$configured" ] && [ -x "$configured" ] || {
    printf 'SDD GUARD: authority checker ausente ou nao executavel: %s\n' "$configured" >&2
    return 1
  }
  resolved_dir="$(cd "$(dirname "$configured")" 2>/dev/null && pwd -P)" || {
    printf 'SDD GUARD: nao foi possivel canonicalizar authority checker\n' >&2
    return 1
  }
  resolved="$resolved_dir/$(basename "$configured")"
  case "$resolved" in
    "$root"|"$root"/*)
      printf 'SDD GUARD: authority checker deve estar fora do worktree\n' >&2
      return 1
      ;;
  esac
  [ -x "$resolved" ] || return 1
  [ -n "$auth_feature" ] && [ -n "$gate" ] && [ -n "$target" ] || {
    printf 'SDD GUARD: authority check exige feature, gate e target nao vazios\n' >&2
    return 1
  }
  [[ "$auth_feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
    printf 'SDD GUARD: feature invalida para authority check\n' >&2
    return 1
  }
  [[ "$gate" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || {
    printf 'SDD GUARD: gate invalido para authority check\n' >&2
    return 1
  }
  head="$(current_head)" || {
    printf 'SDD GUARD: HEAD valido e obrigatorio para authority check\n' >&2
    return 1
  }
  timeout_seconds="$(dump_optional_scalar "$authority_data" 'authority.timeout_seconds')" || return 1
  [ -n "$timeout_seconds" ] || timeout_seconds=30
  [[ "$timeout_seconds" =~ ^[0-9]+$ ]] \
    && [ "$timeout_seconds" -ge 1 ] && [ "$timeout_seconds" -le 300 ] || {
      printf 'SDD GUARD: authority.timeout_seconds deve estar entre 1 e 300\n' >&2
      return 1
    }
  expected_sha="$(dump_optional_scalar "$authority_data" 'authority.check_sha256')" || return 1
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'SDD GUARD: authority.check_sha256 ausente ou invalido\n' >&2
    return 1
  }
  checker_dir="$(umask 077 && mktemp -d "/tmp/sdd-authority.XXXXXX")" || {
    printf 'SDD GUARD: nao foi possivel criar sandbox privada para authority checker\n' >&2
    return 1
  }
  checker_copy="$checker_dir/$(basename "$resolved")"
  if ! command cp "$resolved" "$checker_copy" || [ ! -f "$checker_copy" ] || [ -L "$checker_copy" ]; then
    rm -f "$checker_copy"
    rmdir "$checker_dir" 2>/dev/null || true
    printf 'SDD GUARD: nao foi possivel selar authority checker\n' >&2
    return 1
  fi
  chmod 0500 "$checker_copy" || {
    rm -f "$checker_copy"
    rmdir "$checker_dir" 2>/dev/null || true
    printf 'SDD GUARD: nao foi possivel restringir copia do authority checker\n' >&2
    return 1
  }
  actual_sha="$(sha256_stream <"$checker_copy")" || {
    rm -f "$checker_copy"
    rmdir "$checker_dir" 2>/dev/null || true
    printf 'SDD GUARD: sha256sum ou shasum e obrigatorio para validar authority checker\n' >&2
    return 1
  }
  [ "$actual_sha" = "$expected_sha" ] || {
    rm -f "$checker_copy"
    rmdir "$checker_dir" 2>/dev/null || true
    printf 'SDD GUARD: authority checker diverge do SHA-256 confiavel\n' >&2
    return 1
  }
  clean_path="/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"
  env_bin="$(PATH="$clean_path" command -v env 2>/dev/null || true)"
  timeout_bin="$(PATH="$clean_path" command -v timeout 2>/dev/null || true)"
  python_bin="$(PATH="$clean_path" command -v python3 2>/dev/null || true)"
  [ -n "$env_bin" ] || {
    rm -f "$checker_copy"
    rmdir "$checker_dir" 2>/dev/null || true
    printf 'SDD GUARD: env de sistema e obrigatorio para isolar authority checker\n' >&2
    return 1
  }

  if [ -n "$timeout_bin" ]; then
    "$env_bin" -i PATH="$clean_path" HOME="$checker_dir" TMPDIR="$checker_dir" \
      SDD_AUTH_FEATURE="$auth_feature" SDD_AUTH_GATE="$gate" \
      SDD_AUTH_HEAD="$head" SDD_AUTH_HEAD_SHA="$head" SDD_AUTH_TARGET="$target" \
      SDD_AUTH_POLICIES="$authority_path" SDD_AUTH_AUTONOMY="$autonomy" \
      SDD_AUTH_DECISION="$decision" SDD_FEATURE="$auth_feature" SDD_GATE="$gate" \
      SDD_HEAD_SHA="$head" SDD_TARGET="$target" \
      "$timeout_bin" --signal=TERM "$timeout_seconds" "$checker_copy" || rc=$?
  elif [ -n "$python_bin" ]; then
    "$env_bin" -i PATH="$clean_path" HOME="$checker_dir" TMPDIR="$checker_dir" \
      SDD_AUTH_FEATURE="$auth_feature" SDD_AUTH_GATE="$gate" \
      SDD_AUTH_HEAD="$head" SDD_AUTH_HEAD_SHA="$head" SDD_AUTH_TARGET="$target" \
      SDD_AUTH_POLICIES="$authority_path" SDD_AUTH_AUTONOMY="$autonomy" \
      SDD_AUTH_DECISION="$decision" SDD_FEATURE="$auth_feature" SDD_GATE="$gate" \
      SDD_HEAD_SHA="$head" SDD_TARGET="$target" \
      "$python_bin" - "$timeout_seconds" "$checker_copy" <<'PY' || rc=$?
import subprocess
import sys

try:
    result = subprocess.run([sys.argv[2]], timeout=int(sys.argv[1]), check=False)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
raise SystemExit(result.returncode)
PY
  else
    printf 'SDD GUARD: timeout ou python3 e obrigatorio para limitar authority checker\n' >&2
    rc=125
  fi
  rm -f "$checker_copy"
  rmdir "$checker_dir" 2>/dev/null || true
  if [ "$rc" -ne 0 ]; then
    printf 'SDD GUARD: authority checker negou ou falhou (gate=%s, exit=%s)\n' "$gate" "$rc" >&2
    return 1
  fi
}

require_authority() {
  authority_check_external "$1" "$2" "$3" \
    || fail "autoridade externa nao comprovada para '$2'"
}

require_human_gate() {
  local gate="$1" force_required="${2:-false}"
  local required status approver scope date target authority_gate
  required="$(yaml_scalar "gates.$gate.gate_humano.requerido")"
  status="$(yaml_scalar "gates.$gate.gate_humano.status")"
  case "$required" in true|false) ;; *) fail "requerido de '$gate' deve ser true ou false exato" ;; esac
  if [ "$force_required" = true ] && [ "$required" != true ]; then
    fail "gate humano '$gate' e obrigatorio por enforcement"
  fi
  if [ "$required" = true ]; then
    [ "$status" = aprovado ] || fail "gate humano '$gate' nao esta aprovado"
    approver="$(yaml_scalar "gates.$gate.gate_humano.aprovado_por")"
    scope="$(yaml_scalar "gates.$gate.gate_humano.escopo")"
    date="$(yaml_scalar "gates.$gate.gate_humano.data")"
    [ -n "$approver" ] && [ -n "$scope" ] && [ -n "$date" ] \
      || fail "gate humano '$gate' sem aprovador, escopo ou data"
    target="$scope"
    authority_gate="$gate"
    [ "$authority_gate" != producao ] || authority_gate=production
    require_authority "$feature" "$authority_gate" "$target"
  else
    [ "$status" = dispensado ] \
      || fail "gate humano '$gate' nao requerido deve ter status dispensado exato"
  fi
}

require_report_status() {
  local file="$1" expected="$2" section="${3:-}" value
  require_file "$file"
  value="$(awk -v wanted_section="$section" '
    function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    /^##[[:space:]]+/ {
      heading = $0
      sub(/^##[[:space:]]+/, "", heading)
      heading = trim(heading)
      current = heading
      if (heading == wanted_section) section_found = 1
      next
    }
    {
      lowered = tolower($0)
      if (lowered ~ /^[[:space:]]*-[[:space:]]*status[[:space:]]*:/ \
          && $0 !~ /^[[:space:]]*-[[:space:]]+Status:[[:space:]]*/) {
        malformed = 1
      }
      if ($0 ~ /^[[:space:]]*-[[:space:]]+Status:[[:space:]]*/) {
        value = $0
        sub(/^[[:space:]]*-[[:space:]]+Status:[[:space:]]*/, "", value)
        value = trim(value)
        all[++all_count] = value
        if (current == wanted_section) selected[++selected_count] = value
      }
    }
    END {
      if (malformed) exit 3
      if (wanted_section != "" && section_found) {
        if (selected_count != 1) exit 4
        print selected[1]
      } else {
        if (all_count != 1) exit 5
        print all[1]
      }
    }
  ' "$file")" || fail "status normativo ausente, duplicado ou malformado em ${file#$root/}"
  [ "$value" = "$expected" ] \
    || fail "status de ${file#$root/} deve ser '$expected' exato (obtido: ${value:-vazio})"
}

report_evidence_sha() {
  local file="$1" value
  require_file "$file"
  value="$(awk '
    /^[[:space:]]*-[[:space:]]+Evidence SHA:[[:space:]]*/ {
      found++
      value = $0
      sub(/^[[:space:]]*-[[:space:]]+Evidence SHA:[[:space:]]*/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      selected = value
    }
    END { if (found != 1) exit 2; print selected }
  ' "$file")" || fail "Evidence SHA ausente ou duplicado em ${file#$root/}"
  [[ "$value" =~ ^[0-9a-fA-F]{40,64}$ ]] \
    || fail "Evidence SHA invalido em ${file#$root/}"
  git -C "$root" rev-parse -q --verify "$value^{commit}" >/dev/null 2>&1 \
    || fail "Evidence SHA nao referencia commit valido em ${file#$root/}"
  git -C "$root" merge-base --is-ancestor "$value" HEAD >/dev/null 2>&1 \
    || fail "Evidence SHA nao e ancestral de HEAD em ${file#$root/}"
  printf '%s' "$value"
}

collect_changes_since() {
  local sha="$1" output="$2"
  : >"$output" || return 1
  git -C "$root" -c core.quotepath=false diff --name-only -z "$sha"..HEAD -- >>"$output" || return 1
  git -C "$root" -c core.quotepath=false diff --cached --name-only -z -- >>"$output" || return 1
  git -C "$root" -c core.quotepath=false diff --name-only -z -- >>"$output" || return 1
  git -C "$root" -c core.quotepath=false ls-files --others --exclude-standard -z >>"$output" || return 1
}

is_delivery_evidence_path() {
  local path="$1"
  case "$path" in
    ".compozy/tasks/$feature/auditoria-especificacao.md"|\
    ".compozy/tasks/$feature/bugs.md"|\
    ".compozy/tasks/$feature/reviews-"*|\
    ".compozy/tasks/$feature/qa/"*|\
    ".compozy/tasks/$feature/pr/"*|\
    ".compozy/tasks/$feature/ops/"*|\
    "sdd/incrementos/$feature/incremento.yaml"|\
    "sdd/incrementos/$feature/relatorio-fechamento.md"|\
    sdd/metricas.csv) return 0 ;;
    *) return 1 ;;
  esac
}

is_audit_material_path() {
  local path="$1"
  case "$path" in
    "sdd/incrementos/$feature/incremento.yaml"|\
    "sdd/incrementos/$feature/brief.md"|\
    "sdd/incrementos/$feature/execucao.md"|\
    "sdd/incrementos/$feature/impacto-contratual/"*|\
    ".compozy/tasks/$feature/_prd.md"|\
    ".compozy/tasks/$feature/_techspec.md"|\
    ".compozy/tasks/$feature/INDEX.md"|\
    ".compozy/tasks/$feature/task_"[0-9][0-9].md|\
    ".compozy/tasks/$feature/feature/"*.feature|\
    ".compozy/tasks/$feature/adrs/"*) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_audit_material() {
  local logical="$1" source="$2" output="$3"
  if [ "$logical" = "sdd/incrementos/$feature/brief.md" ]; then
    command cp "$source" "$output"
    return
  fi
  if [ "$logical" = "sdd/incrementos/$feature/incremento.yaml" ]; then
    canonical_yaml_dump "$source" | awk -F '\t' '
      {
        path=$2
        top=path
        sub(/[.\[].*$/, "", top)
        if (top != "status" && top != "fase" && top != "gates" && top != "pr" \
            && top != "deploy" && top != "metricas" && top != "bloqueio" \
            && top != "fechamento") print
        else if (top == "gates" && path ~ /\.gate_humano\.requerido$/) print
      }
    ' >"$output"
    return
  fi
  python3 - "$logical" "$source" "$output" <<'PY'
import pathlib
import re
import sys

logical, source_path, output_path = sys.argv[1:]
text = pathlib.Path(source_path).read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
result = []
in_frontmatter = bool(lines and lines[0].rstrip("\r\n") == "---")
skip_produced = False
for index, line in enumerate(lines):
    raw = line.rstrip("\r\n")
    if skip_produced:
        if raw.startswith("## "):
            skip_produced = False
        else:
            continue
    if re.fullmatch(r"## (Evidências|Evidencias) produzidas", raw):
        skip_produced = True
        continue
    if in_frontmatter and index > 0 and raw == "---":
        in_frontmatter = False
    if in_frontmatter and re.match(r"^status:\s*", raw):
        ending = "\n" if line.endswith("\n") else ""
        line = "status: <operational>" + ending
    line = re.sub(r"- \[[xX ]\]", "- [ ]", line)
    if logical.endswith("/INDEX.md"):
        line = re.sub(r"\b(pending|in_progress|completed)\b", "<operational>", line)
    result.append(line)
pathlib.Path(output_path).write_text("".join(result), encoding="utf-8")
PY
}

validate_audit_material_snapshot() {
  local sha="$1" path old indexed normalized_old normalized_index normalized_current
  local old_paths current_paths compare_dir old_mode index_mode mode_changes
  local -A material_paths=()
  old_paths="$(mktemp)" || fail "nao foi possivel listar snapshot auditado"
  current_paths="$(mktemp)" || { rm -f "$old_paths"; fail "nao foi possivel listar snapshot atual"; }
  git -C "$root" ls-tree -rz --name-only "$sha" -- \
    "sdd/incrementos/$feature" ".compozy/tasks/$feature" >"$old_paths" \
    || { rm -f "$old_paths" "$current_paths"; fail "nao foi possivel ler snapshot auditado"; }
  git -C "$root" ls-files -co --exclude-standard -z -- \
    "sdd/incrementos/$feature" ".compozy/tasks/$feature" >"$current_paths" \
    || { rm -f "$old_paths" "$current_paths"; fail "nao foi possivel ler artefatos atuais"; }
  while IFS= read -r -d '' path; do
    is_audit_material_path "$path" && material_paths["$path"]=1
  done <"$old_paths"
  while IFS= read -r -d '' path; do
    is_audit_material_path "$path" && material_paths["$path"]=1
  done <"$current_paths"
  rm -f "$old_paths" "$current_paths"
  [ "${#material_paths[@]}" -gt 0 ] || fail "snapshot auditado nao contem artefatos materiais"
  compare_dir="$(mktemp -d)" || fail "nao foi possivel criar comparador de snapshot"
  old="$compare_dir/old"
  indexed="$compare_dir/index"
  normalized_old="$compare_dir/old.normalized"
  normalized_index="$compare_dir/index.normalized"
  normalized_current="$compare_dir/current.normalized"
  for path in "${!material_paths[@]}"; do
    [ -f "$root/$path" ] && [ ! -L "$root/$path" ] \
      || fail "artefato auditado foi removido ou virou symlink: $path"
    if ! git -C "$root" show "$sha:$path" >"$old" 2>/dev/null; then
      fail "artefato material nao existia no Evidence SHA da auditoria: $path"
    fi
    if ! git -C "$root" ls-files --error-unmatch -- "$path" >/dev/null 2>&1 \
       || ! git -C "$root" show ":$path" >"$indexed" 2>/dev/null; then
      fail "artefato material ausente do index: $path; reaudite"
    fi
    old_mode="$(git -C "$root" ls-tree "$sha" -- "$path" | awk 'NR == 1 { print $1 }')"
    index_mode="$(git -C "$root" ls-files -s -- "$path" | awk 'NR == 1 { print $1 }')"
    [ -n "$old_mode" ] && [ "$old_mode" = "$index_mode" ] \
      || fail "modo do artefato material divergiu no index: $path; reaudite"
    mode_changes="$(git -C "$root" diff --summary "$sha" -- "$path")" \
      || fail "nao foi possivel comparar modo de $path"
    [ -z "$mode_changes" ] \
      || fail "modo do artefato material divergiu do Evidence SHA: $path; reaudite"
    normalize_audit_material "$path" "$old" "$normalized_old" \
      || fail "snapshot auditado invalido: $path"
    normalize_audit_material "$path" "$indexed" "$normalized_index" \
      || fail "snapshot no index invalido: $path"
    normalize_audit_material "$path" "$root/$path" "$normalized_current" \
      || fail "artefato material atual invalido: $path"
    cmp -s "$normalized_old" "$normalized_index" \
      || fail "index divergiu do Evidence SHA $sha: $path; reaudite"
    cmp -s "$normalized_old" "$normalized_current" \
      || fail "worktree divergiu do Evidence SHA $sha: $path; reaudite"
  done
  rm -f "$old" "$indexed" "$normalized_old" "$normalized_index" "$normalized_current"
  rmdir "$compare_dir" 2>/dev/null || true
}

validate_audit_evidence() {
  local sha status changes path
  sha="$(report_evidence_sha "$audit")"
  require_authority "$feature" audit_evidence "$sha"
  validate_audit_material_snapshot "$sha"
  status="$(yaml_scalar status)"
  changes="$(mktemp)" || fail "nao foi possivel validar Evidence SHA da auditoria"
  if ! collect_changes_since "$sha" "$changes"; then
    rm -f "$changes"
    fail "nao foi possivel calcular alteracoes desde a auditoria"
  fi
  while IFS= read -r -d '' path; do
    [ -n "$path" ] || continue
    case "$status" in
      proposto|especificado)
        is_delivery_evidence_path "$path" || {
          rm -f "$changes"
          fail "artefato mudou depois da auditoria ($sha): $path; reaudite a especificacao"
        }
        ;;
      *)
        case "$path" in
          ".compozy/tasks/$feature/_prd.md"|\
          ".compozy/tasks/$feature/_techspec.md"|\
          ".compozy/tasks/$feature/feature/"*|\
          ".compozy/tasks/$feature/adrs/"*|\
          "sdd/incrementos/$feature/impacto-contratual/"*)
            rm -f "$changes"
            fail "especificacao material mudou depois da auditoria ($sha): $path; reaudite"
            ;;
        esac
        ;;
    esac
  done <"$changes"
  rm -f "$changes"
}

delivery_evidence_sha=""

validate_delivery_report_sha() {
  local file="$1" evidence_gate="$2" sha changes path
  sha="$(report_evidence_sha "$file")"
  require_authority "$feature" "$evidence_gate" "$sha"
  if [ -n "$delivery_evidence_sha" ] && [ "$delivery_evidence_sha" != "$sha" ]; then
    fail "review e QA devem validar o mesmo Evidence SHA"
  fi
  delivery_evidence_sha="$sha"
  changes="$(mktemp)" || fail "nao foi possivel validar Evidence SHA da entrega"
  if ! collect_changes_since "$sha" "$changes"; then
    rm -f "$changes"
    fail "nao foi possivel calcular alteracoes desde review/QA"
  fi
  while IFS= read -r -d '' path; do
    [ -n "$path" ] || continue
    is_delivery_evidence_path "$path" || {
      rm -f "$changes"
      fail "implementacao mudou depois do Evidence SHA $sha: $path; repita review e QA"
    }
  done <"$changes"
  rm -f "$changes"
}

validate_report_traceability() {
  local task_file scenario id report_label
  local -a reports=("$@")
  local -a task_files_list=() feature_files=() scenario_ids=() test_ids=() report_scenarios=() report_tests=()
  [ "${#reports[@]}" -gt 0 ] || fail "relatorio ausente para rastreabilidade"
  report_label="${reports[0]#$root/}"
  shopt -s nullglob
  task_files_list=("$wf"/task_[0-9][0-9].md)
  feature_files=("$wf"/feature/*.feature)
  shopt -u nullglob
  [ "${#task_files_list[@]}" -gt 0 ] || fail "tasks ausentes para rastreabilidade"
  [ "${#feature_files[@]}" -gt 0 ] || fail "cenarios Gherkin ausentes para rastreabilidade"
  for task_file in "${task_files_list[@]}"; do
    LC_ALL=C grep -Eq 'SCN-[A-Za-z0-9][A-Za-z0-9._-]*' "$task_file" \
      || fail "task sem SCN rastreavel: ${task_file#$root/}"
    LC_ALL=C grep -Eq 'TST-[A-Za-z0-9][A-Za-z0-9._-]*' "$task_file" \
      || fail "task sem TST rastreavel: ${task_file#$root/}"
  done
  mapfile -t scenario_ids < <(LC_ALL=C grep -hEo 'SCN-[A-Za-z0-9][A-Za-z0-9._-]*' "${feature_files[@]}" | LC_ALL=C sort -u)
  mapfile -t test_ids < <(LC_ALL=C grep -hEo 'TST-[A-Za-z0-9][A-Za-z0-9._-]*' "${task_files_list[@]}" | LC_ALL=C sort -u)
  [ "${#scenario_ids[@]}" -gt 0 ] || fail "nenhum SCN canonico encontrado em Gherkin"
  [ "${#test_ids[@]}" -gt 0 ] || fail "nenhum TST canonico encontrado nas tasks"
  mapfile -t report_scenarios < <(LC_ALL=C grep -hEo 'SCN-[A-Za-z0-9][A-Za-z0-9._-]*' "${reports[@]}" | LC_ALL=C sort -u)
  mapfile -t report_tests < <(LC_ALL=C grep -hEo 'TST-[A-Za-z0-9][A-Za-z0-9._-]*' "${reports[@]}" | LC_ALL=C sort -u)
  for id in "${scenario_ids[@]}"; do
    printf '%s\n' "${report_scenarios[@]}" | grep -qxF "$id" \
      || fail "$report_label e relatorios relacionados nao cobrem $id"
    LC_ALL=C grep -hFq "$id" "${task_files_list[@]}" \
      || fail "nenhuma task referencia $id"
  done
  for id in "${test_ids[@]}"; do
    printf '%s\n' "${report_tests[@]}" | grep -qxF "$id" \
      || fail "$report_label e relatorios relacionados nao cobrem $id"
  done
}

reject_placeholders() {
  local file="$1"
  if LC_ALL=C grep -Eiq \
    '(\[(feature|dominio|nome|titulo|item|resultado|pergunta|componente|servico)\]|<(feature|domain|todo)>|\b(TODO|TBD|PREENCHER|A DEFINIR)\b|\b(FEAT|SCN|TST|RF|RNF|BR)-XXX\b)' \
    "$file"; then
    fail "placeholder nao resolvido em ${file#$root/}"
  fi
}

validate_task_file() {
  local file="$1" expected_mode="$2"
  require_file "$file"
  awk -v mode="$expected_mode" '
    function die(message) { printf "%s: %s\n", FILENAME, message > "/dev/stderr"; exit 2 }
    function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    NR == 1 { if ($0 != "---") die("frontmatter deve iniciar na primeira linha"); inside = 1; next }
    inside && $0 == "---" { inside = 0; closed = 1; next }
    inside {
      if ($0 ~ /^[[:space:]]*(#|$)/) next
      colon = index($0, ":")
      if (colon <= 1) die("linha invalida no frontmatter")
      key = substr($0, 1, colon - 1)
      if (key !~ /^[a-z_][a-z0-9_-]*$/) die("chave invalida no frontmatter")
      if (seen[key]++) die("chave duplicada no frontmatter: " key)
      value = trim(substr($0, colon + 1))
      if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) value = substr(value, 2, length(value) - 2)
      values[key] = value
      next
    }
    END {
      if (!closed) die("frontmatter sem fechamento")
      required[1] = "status"; required[2] = "title"; required[3] = "type"
      required[4] = "complexity"; required[5] = "dependencies"
      for (i = 1; i <= 5; i++) if (!(required[i] in seen)) die("chave ausente: " required[i])
      if (mode == "planned" && values["status"] != "pending") die("status deve ser pending")
      if (mode == "completed" && values["status"] != "completed") die("status deve ser completed")
      if (mode == "valid" && values["status"] !~ /^(pending|in_progress|completed)$/) die("status invalido")
      if (values["title"] == "" || values["title"] ~ /\[[^]]+\]/) die("title vazio ou placeholder")
      if (values["type"] !~ /^(frontend|backend|docs|test|infra|refactor|chore|bugfix)$/) die("type invalido")
      if (values["complexity"] !~ /^(low|medium|high)$/) die("complexity invalida")
      if (values["dependencies"] !~ /^\[[^]]*\]$/) die("dependencies deve ser flow list canonica")
    }
  ' "$file" || fail "task malformada: ${file#$root/}"
  reject_placeholders "$file"
}

task_files() {
  local file base found=0
  shopt -s nullglob
  for file in "$wf"/task_*.md; do
    base="${file##*/}"
    [[ "$base" =~ ^task_[0-9][0-9]\.md$ ]] \
      || fail "nome de task fora do padrao task_NN.md: $base"
    found=1
    printf '%s\n' "$file"
  done
  shopt -u nullglob
  [ "$found" -eq 1 ] || fail "nenhuma task encontrada em ${wf#$root/}"
}

all_tasks_with_mode() {
  local mode="$1" file list
  list="$(task_files)"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    validate_task_file "$file" "$mode"
  done <<<"$list"
}

validate_task_dependencies() {
  local target="${1:-}" operation="${2:-graph}"
  python3 - "$wf" "$target" "$operation" <<'PY' \
    || fail "grafo de dependencias das tasks invalido"
import pathlib
import re
import sys

directory = pathlib.Path(sys.argv[1])
target = sys.argv[2]
operation = sys.argv[3]
tasks = {}
statuses = {}

for path in sorted(directory.glob("task_*.md")):
    if not re.fullmatch(r"task_[0-9]{2}\.md", path.name):
        continue
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise ValueError(f"{path.name}: frontmatter ausente")
    try:
        finish = lines.index("---", 1)
    except ValueError as error:
        raise ValueError(f"{path.name}: frontmatter sem fechamento") from error
    fields = {}
    for line in lines[1:finish]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.fullmatch(r"([a-z_][a-z0-9_-]*):\s*(.*)", line)
        if not match:
            raise ValueError(f"{path.name}: frontmatter nao canonico")
        key, value = match.groups()
        if key in fields:
            raise ValueError(f"{path.name}: chave duplicada {key}")
        fields[key] = value.strip()
    raw_dependencies = fields.get("dependencies", "")
    match = re.fullmatch(r"\[\s*(.*?)\s*\]", raw_dependencies)
    if not match:
        raise ValueError(f"{path.name}: dependencies deve ser flow list")
    raw_items = match.group(1)
    dependencies = [] if not raw_items else [item.strip() for item in raw_items.split(",")]
    if any(not re.fullmatch(r"task_[0-9]{2}", item) for item in dependencies):
        raise ValueError(f"{path.name}: dependencia fora do formato task_NN")
    if len(dependencies) != len(set(dependencies)):
        raise ValueError(f"{path.name}: dependencia duplicada")
    task_id = path.stem
    if task_id in dependencies:
        raise ValueError(f"{path.name}: task depende de si mesma")
    tasks[task_id] = dependencies
    statuses[task_id] = fields.get("status", "")

if not tasks:
    raise ValueError("nenhuma task canonica")
for task_id, dependencies in tasks.items():
    for dependency in dependencies:
        if dependency not in tasks:
            raise ValueError(f"{task_id}: dependencia ausente {dependency}")

visiting = set()
visited = set()
def visit(task_id):
    if task_id in visiting:
        raise ValueError(f"ciclo de dependencias em {task_id}")
    if task_id in visited:
        return
    visiting.add(task_id)
    for dependency in tasks[task_id]:
        visit(dependency)
    visiting.remove(task_id)
    visited.add(task_id)
for task_id in tasks:
    visit(task_id)

for task_id, dependencies in tasks.items():
    if statuses[task_id] in {"in_progress", "completed"}:
        pending = [dependency for dependency in dependencies if statuses[dependency] != "completed"]
        if pending:
            raise ValueError(f"{task_id}: dependencias ainda nao concluidas: {pending}")

if target:
    if target not in tasks:
        raise ValueError(f"task alvo ausente: {target}")
    expected = {"start": {"pending", "in_progress"}, "complete": {"completed"}}.get(operation)
    if expected is None or statuses[target] not in expected:
        raise ValueError(f"{target}: status {statuses[target]} invalido para {operation}")
    pending = [dependency for dependency in tasks[target] if statuses[dependency] != "completed"]
    if pending:
        raise ValueError(f"{target}: dependencias ainda nao concluidas: {pending}")
PY
}

techspec_is_required() {
  local route rigor risk target
  route="$(yaml_scalar 'rota.techspec')"
  case "$route" in obrigatoria|dispensada) ;; *) fail "rota.techspec invalida" ;; esac
  rigor="$(yaml_scalar 'classificacao.rigor')"
  risk="$(yaml_scalar 'classificacao.risco')"
  target="$(yaml_scalar 'classificacao.alvo_contrato')"
  case "$rigor:$risk:$target" in
    medium:*|large:*|*:alto:*|*:regulado:*|*:*:producao) return 0 ;;
  esac
  [ "$route" = obrigatoria ]
}

review_is_required() {
  local route rigor risk target
  route="$(yaml_optional_scalar 'rota.review')"
  rigor="$(yaml_scalar 'classificacao.rigor')"
  risk="$(yaml_scalar 'classificacao.risco')"
  target="$(yaml_scalar 'classificacao.alvo_contrato')"
  case "$target" in branch|producao) return 0 ;; local) ;; *) fail "alvo_contrato invalido" ;; esac
  case "$risk" in medio|alto|regulado) return 0 ;; baixo) ;; *) fail "risco invalido" ;; esac
  case "$rigor" in medium|large) return 0 ;; small) ;; *) fail "rigor invalido" ;; esac
  case "$route" in
    obrigatoria) return 0 ;;
    dispensada) return 1 ;;
    "") return 0 ;;
    *) fail "rota.review invalida" ;;
  esac
}

validate_specification() {
  local task_mode="${1:-planned}" target_task="${2:-}" dependency_operation="${3:-graph}"
  local prd="$wf/_prd.md" techspec="$wf/_techspec.md"
  local plan="$inc/execucao.md" index="$wf/INDEX.md" risk autonomy force_gate=false
  load_increment
  require_file "$prd"
  require_file "$plan"
  require_file "$index"
  reject_placeholders "$prd"
  reject_placeholders "$plan"
  reject_placeholders "$index"
  if techspec_is_required; then
    require_file "$techspec"
    reject_placeholders "$techspec"
  elif [ -e "$techspec" ]; then
    require_file "$techspec"
    reject_placeholders "$techspec"
  fi
  all_tasks_with_mode "$task_mode"
  validate_task_dependencies "$target_task" "$dependency_operation"
  require_report_status "$audit" PRONTO Resumo
  reject_placeholders "$audit"
  validate_report_traceability "$audit"
  validate_audit_evidence
  risk="$(yaml_scalar 'classificacao.risco')"
  case "$risk" in
    alto|regulado) force_gate=true ;;
    baixo|medio) ;;
    *) fail "classificacao.risco invalida" ;;
  esac
  autonomy="$(yaml_scalar 'classificacao.autonomia')"
  case "$autonomy" in
    assistido) ;;
    autonomo_ate_pr|autonomo_ate_staging|producao_com_gate) force_gate=true ;;
    *) fail "classificacao.autonomia invalida" ;;
  esac
  require_human_gate especificacao "$force_gate"
}

contract_tree_dirty() {
  git -C "$root" status --porcelain --untracked-files=all -- sdd/contratos 2>/dev/null \
    | grep -q .
}

check_contracts_untouched() {
  local base rc=0
  base="$(yaml_scalar 'execucao.base_sha')"
  [ -n "$base" ] || fail "execucao.base_sha e obrigatorio para provar integridade do contrato vivo"
  git -C "$root" rev-parse -q --verify "$base^{commit}" >/dev/null 2>&1 \
    || fail "execucao.base_sha nao referencia commit valido"
  git -C "$root" merge-base --is-ancestor "$base" HEAD >/dev/null 2>&1 \
    || fail "execucao.base_sha nao e ancestral de HEAD"
  git -C "$root" diff --quiet "$base"..HEAD -- sdd/contratos || rc=$?
  case "$rc" in
    0) ;;
    1) fail "sdd/contratos possui commits depois de execucao.base_sha" ;;
    *) fail "nao foi possivel provar integridade de sdd/contratos" ;;
  esac
  contract_tree_dirty && fail "sdd/contratos possui alteracao no worktree"
  return 0
}

validate_review() {
  if review_is_required; then
    require_report_status "$review" APROVADO
    reject_placeholders "$review"
    validate_report_traceability "$review"
    validate_delivery_report_sha "$review" review_evidence
  elif [ -e "$review" ]; then
    require_report_status "$review" APROVADO
    validate_report_traceability "$review"
    validate_delivery_report_sha "$review" review_evidence
  fi
}

validate_qa() {
  local found=0 qa
  local -a qa_reports=()
  shopt -s nullglob
  for qa in "$wf"/qa/*-qa-report.md; do
    found=1
    qa_reports+=("$qa")
    require_report_status "$qa" APROVADO Resumo
    reject_placeholders "$qa"
    if LC_ALL=C grep -Eiq '(^|[^A-Z_])NAO_VERIFICADO([^A-Z_]|$)' "$qa"; then
      fail "QA contem NAO_VERIFICADO: ${qa#$root/}"
    fi
    LC_ALL=C grep -Eq 'SCN-[A-Za-z0-9][A-Za-z0-9._-]*' "$qa" \
      || fail "QA sem SCN: ${qa#$root/}"
    LC_ALL=C grep -Eq 'TST-[A-Za-z0-9][A-Za-z0-9._-]*' "$qa" \
      || fail "QA sem TST: ${qa#$root/}"
    validate_delivery_report_sha "$qa" qa_evidence
  done
  shopt -u nullglob
  [ "$found" -eq 1 ] || fail "relatorio de QA ausente"
  validate_report_traceability "${qa_reports[@]}"
}

issue_frontmatter() {
  local file="$1"
  awk '
    function die(message) { printf "%s: %s\n", FILENAME, message > "/dev/stderr"; exit 2 }
    function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    NR == 1 { if ($0 != "---") die("frontmatter ausente"); inside = 1; next }
    inside && $0 == "---" { inside = 0; closed = 1; next }
    inside {
      if ($0 ~ /^[[:space:]]*(#|$)/) next
      colon = index($0, ":")
      if (colon <= 1) die("linha invalida")
      key = substr($0, 1, colon - 1)
      if (seen[key]++) die("chave duplicada: " key)
      value = trim(substr($0, colon + 1))
      gsub(/^"|"$/, "", value)
      values[key] = value
    }
    END {
      if (!closed) die("frontmatter sem fechamento")
      if (!("severity" in seen) || !("status" in seen)) die("severity/status ausente")
      if (values["severity"] !~ /^P[0-3]$/) die("severity invalida")
      if (values["status"] !~ /^(open|fixed|closed|resolved|done)$/) die("status invalido")
      printf "%s\t%s\n", values["severity"], values["status"]
    }
  ' "$file"
}

validate_review_issues() {
  local file values severity status
  shopt -s nullglob
  for file in "$wf"/reviews-001/issue_*.md; do
    require_file "$file"
    values="$(issue_frontmatter "$file")" \
      || fail "issue de review malformada: ${file#$root/}"
    IFS=$'\t' read -r severity status <<<"$values"
    if [[ "$severity" =~ ^P[01]$ ]] && [[ ! "$status" =~ ^(fixed|closed|resolved|done)$ ]]; then
      fail "ha $severity aberto em ${file#$root/}"
    fi
  done
  shopt -u nullglob
}

validate_bugs() {
  local file="$wf/bugs.md" result
  [ -e "$file" ] || return 0
  require_file "$file"
  result="$(awk '
    function die(message) { printf "%s:%d: %s\n", FILENAME, NR, message > "/dev/stderr"; exit 2 }
    function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    function flush() {
      if (!in_bug) return
      if (severity_count != 1 || status_count != 1) die("BUG sem Severidade/Status unico")
      if (severity !~ /^P[0-3]$/) die("Severidade invalida")
      if (status !~ /^(open|aberto|fixed|closed|resolved|done|corrigido|resolvido|concluido)$/) die("Status invalido")
      if (severity ~ /^P[01]$/ && status !~ /^(fixed|closed|resolved|done|corrigido|resolvido|concluido)$/) blocker = 1
    }
    /^##[[:space:]]+BUG-/ && $0 !~ /^##[[:space:]]+BUG-[0-9]+([[:space:]-]|$)/ {
      die("identificador BUG invalido; use BUG-NNN")
    }
    /^##[[:space:]]+BUG-[0-9]+([[:space:]-]|$)/ {
      flush(); in_bug = 1; severity = ""; status = ""; severity_count = 0; status_count = 0; next
    }
    !in_bug && /^[[:space:]]*-[[:space:]]+(Severidade|Status):[[:space:]]*/ {
      die("Severidade/Status fora de bloco BUG-NNN")
    }
    in_bug && /^[[:space:]]*-[[:space:]]+Severidade:[[:space:]]*/ {
      severity_count++; severity = $0; sub(/^[^:]+:[[:space:]]*/, "", severity); severity = toupper(trim(severity)); next
    }
    in_bug && /^[[:space:]]*-[[:space:]]+Status:[[:space:]]*/ {
      status_count++; status = $0; sub(/^[^:]+:[[:space:]]*/, "", status); status = tolower(trim(status)); next
    }
    END { flush(); if (blocker) print "BLOCKER" }
  ' "$file")" || fail "bugs.md malformado"
  [ "$result" != BLOCKER ] || fail "ha P0/P1 aberto em bugs.md"
}

ensure_no_open_blockers() {
  validate_review_issues
  validate_bugs
}

validate_delivery_evidence() {
  delivery_evidence_sha=""
  require_report_status "$audit" PRONTO Resumo
  reject_placeholders "$audit"
  validate_report_traceability "$audit"
  validate_audit_evidence
  all_tasks_with_mode completed
  validate_review
  validate_qa
  ensure_no_open_blockers
  check_contracts_untouched
}

require_increment_status() {
  local expected="$1" actual
  actual="$(yaml_scalar status)"
  [ "$actual" = "$expected" ] \
    || fail "status do incremento deve ser '$expected' exato (obtido: ${actual:-vazio})"
}

quality_commands=()

append_policy_list() {
  local path="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || fail "quality command vazio em $path"
    quality_commands+=("$line")
  done < <(dump_list "$policy_data" "$path")
}

run_quality_commands() {
  local stage="$1" category command target
  require_policies
  quality_commands=()
  append_policy_list 'quality_commands.common'
  if dump_has_path "$policy_data" "quality_commands.$stage"; then
    append_policy_list "quality_commands.$stage"
  else
    for category in lint typecheck build test e2e; do
      append_policy_list "quality_commands.$category"
    done
  fi
  if [ "${#quality_commands[@]}" -eq 0 ]; then
    target="$(yaml_scalar 'classificacao.alvo_contrato')"
    require_authority "$feature" "quality_waiver_${stage//-/_}" "$target"
    return 0
  fi
  for command in "${quality_commands[@]}"; do
    printf 'SDD GUARD: quality[%s]: %s\n' "$stage" "$command"
    (cd "$root" && bash -o pipefail -c "$command") \
      || fail "quality command falhou em $stage: $command"
  done
}

report_scalar_field() {
  local file="$1" label="$2" value
  require_file "$file"
  value="$(awk -v label="$label" '
    {
      prefix = "- " label ":"
      if (index($0, prefix) == 1) {
        found++
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        selected = value
      }
    }
    END { if (found != 1) exit 2; print selected }
  ' "$file")" || fail "$label ausente ou duplicado em ${file#$root/}"
  [ -n "$value" ] || fail "$label vazio em ${file#$root/}"
  printf '%s' "$value"
}

require_merge_evidence() {
  local report="$wf/pr/merge-report.md" merge_sha validated_sha base_branch expected_branch
  require_report_status "$report" MERGED Resultado
  merge_sha="$(report_scalar_field "$report" 'Merge SHA')"
  validated_sha="$(report_scalar_field "$report" 'Head SHA validado')"
  base_branch="$(report_scalar_field "$report" 'Base branch')"
  expected_branch="$(policy_scalar 'project.default_target_branch')"
  [[ "$merge_sha" =~ ^[0-9a-fA-F]{40,64}$ ]] \
    || fail "Merge SHA invalido"
  git -C "$root" rev-parse -q --verify "$merge_sha^{commit}" >/dev/null 2>&1 \
    || fail "Merge SHA nao referencia commit valido"
  git -C "$root" merge-base --is-ancestor "$merge_sha" HEAD >/dev/null 2>&1 \
    || fail "Merge SHA nao e ancestral de HEAD"
  [ -n "$delivery_evidence_sha" ] \
    || fail "review/QA deve definir Evidence SHA antes da evidencia de merge"
  [ "$validated_sha" = "$delivery_evidence_sha" ] \
    || fail "Head SHA validado no merge diverge de review/QA"
  git -C "$root" merge-base --is-ancestor "$validated_sha" "$merge_sha" >/dev/null 2>&1 \
    || fail "Merge SHA nao contem a implementacao validada"
  [ "$base_branch" = "$expected_branch" ] \
    || fail "Base branch do merge deve ser $expected_branch"
  require_authority "$feature" merge_evidence "$merge_sha"
}

require_deploy_evidence() {
  local report="$wf/ops/deploy-report.md" merge_report="$wf/pr/merge-report.md"
  local merge_sha expected_merge artifact environment health rollback verified_at verified_epoch now
  require_report_status "$report" VERIFICADO Resultado
  merge_sha="$(report_scalar_field "$report" 'Merge SHA')"
  expected_merge="$(report_scalar_field "$merge_report" 'Merge SHA')"
  artifact="$(report_scalar_field "$report" 'Artifact SHA-256')"
  environment="$(report_scalar_field "$report" 'Ambiente')"
  health="$(report_scalar_field "$report" 'Health checks')"
  rollback="$(report_scalar_field "$report" 'Rollback pronto')"
  verified_at="$(report_scalar_field "$report" 'Verificado em')"
  [ "$merge_sha" = "$expected_merge" ] || fail "deploy nao corresponde ao Merge SHA confirmado"
  [[ "$artifact" =~ ^[0-9a-fA-F]{64}$ ]] || fail "Artifact SHA-256 invalido"
  [ "$environment" = production ] || fail "Ambiente de deploy deve ser production"
  [ "$(policy_scalar 'production.require_health_checks')" = true ] \
    || fail "policy de health checks invalida"
  [ "$health" = PASSOU ] || fail "health checks de producao nao passaram"
  [ "$rollback" = sim ] || fail "rollback nao esta pronto"
  verified_epoch="$(iso_to_epoch "$verified_at")" || fail "Verificado em deve ser ISO-8601 valido"
  now="$(date -u +%s)"
  [ "$verified_epoch" -le "$now" ] || fail "evidencia de deploy esta no futuro"
  require_authority "$feature" deploy_evidence "$environment:$merge_sha:$artifact"
}

iso_to_epoch() {
  local timestamp="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$timestamp" <<'PY'
from datetime import datetime, timezone
import sys
raw = sys.argv[1]
try:
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    value = datetime.fromisoformat(raw)
    if value.tzinfo is None:
        raise ValueError
    print(int(value.astimezone(timezone.utc).timestamp()))
except ValueError:
    raise SystemExit(1)
PY
    return
  fi
  date -u -d "$timestamp" +%s 2>/dev/null
}

require_recent_production_approval() {
  local timestamp approved_epoch now_epoch max_age age
  require_human_gate producao true
  timestamp="$(yaml_scalar 'gates.producao.gate_humano.data')"
  approved_epoch="$(iso_to_epoch "$timestamp")" \
    || fail "timestamp ISO-8601 invalido no gate de producao"
  now_epoch="$(date -u +%s)"
  max_age="$(policy_optional_scalar 'production.approval_max_age_minutes')"
  [ -n "$max_age" ] || max_age=60
  [[ "$max_age" =~ ^[0-9]+$ ]] && [ "$max_age" -ge 1 ] \
    || fail "production.approval_max_age_minutes invalido"
  age=$(( (now_epoch - approved_epoch) / 60 ))
  [ "$age" -ge 0 ] || fail "gate de producao esta no futuro"
  [ "$age" -le "$max_age" ] \
    || fail "gate de producao expirado (${age} min; maximo ${max_age} min)"
}

canonicalize_path() {
  local input="$1" rel part normalized="" current
  local -a parts
  [ -n "$input" ] || fail2 "caminho vazio"
  case "$input" in *$'\n'*|*$'\r'*|*$'\t'*) fail2 "caminho contem caractere de controle" ;; esac
  case "$input" in
    /*)
      case "$input" in
        "$root") rel="." ;;
        "$root"/*) rel="${input#"$root"/}" ;;
        *) fail2 "caminho absoluto escapa do worktree: $input" ;;
      esac
      ;;
    *) rel="$input" ;;
  esac
  IFS='/' read -r -a parts <<<"$rel"
  for part in "${parts[@]}"; do
    case "$part" in
      ""|.) continue ;;
      ..) fail2 "componentes '..' nao sao permitidos: $input" ;;
    esac
    [ -n "$normalized" ] && normalized+="/"
    normalized+="$part"
  done
  [ -n "$normalized" ] || normalized="."

  current="$root"
  if [ "$normalized" != "." ]; then
    IFS='/' read -r -a parts <<<"$normalized"
    for part in "${parts[@]}"; do
      current="$current/$part"
      [ ! -L "$current" ] || fail2 "symlink nao permitido no caminho protegido: $normalized"
    done
  fi
  printf '%s' "$normalized"
}

normalize_policy_pattern() {
  local pattern="$1" part normalized=""
  local -a parts
  [ -n "$pattern" ] || return 1
  case "$pattern" in /*) return 1 ;; esac
  IFS='/' read -r -a parts <<<"$pattern"
  for part in "${parts[@]}"; do
    case "$part" in ""|.) continue ;; ..) return 1 ;; esac
    [ -n "$normalized" ] && normalized+="/"
    normalized+="$part"
  done
  case "$pattern" in */) normalized+="/" ;; esac
  [ -n "$normalized" ] || return 1
  printf '%s' "$normalized"
}

path_matches() {
  local rel="$1" pattern="$2" tail_pattern
  case "$pattern" in
    */)
      case "$rel" in "${pattern%/}"|"$pattern"*) return 0 ;; esac
      ;;
    *)
      case "$rel" in $pattern|$pattern/*) return 0 ;; esac
      ;;
  esac
  case "$pattern" in
    '**/'*)
      tail_pattern="${pattern#**/}"
      case "$rel" in $tail_pattern|$tail_pattern/*) return 0 ;; esac
      ;;
  esac
  return 1
}

path_intersects() {
  local rel="$1" pattern="$2" literal
  path_matches "$rel" "$pattern" && return 0
  case "$pattern" in
    *'*'*|*'?'*|*'['*) return 1 ;;
  esac
  literal="${pattern%/}"
  case "$literal" in "$rel"/*) return 0 ;; esac
  return 1
}

directory_intersects_pattern() {
  local rel="$1" pattern="$2" physical descendant matched=1
  local globstar_state dotglob_state nullglob_state
  [ -d "$root/$rel" ] && [ ! -L "$root/$rel" ] || return 1
  globstar_state="$(shopt -p globstar || true)"
  dotglob_state="$(shopt -p dotglob || true)"
  nullglob_state="$(shopt -p nullglob || true)"
  shopt -s globstar dotglob nullglob
  for physical in "$root/$rel"/**; do
    [ -e "$physical" ] || [ -L "$physical" ] || continue
    descendant="${physical#"$root/"}"
    if path_matches "$descendant" "$pattern"; then
      matched=0
      break
    fi
  done
  eval "$globstar_state"
  eval "$dotglob_state"
  eval "$nullglob_state"
  return "$matched"
}

git_state_dir() {
  local git_dir
  git_dir="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  printf '%s/sdd-state/consolidate' "$git_dir"
}

sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    return 1
  fi
}

ensure_attestation_key() {
  local state_dir="$1" key="$state_dir/.attestation-key"
  if [ -e "$key" ]; then
    [ -f "$key" ] && [ ! -L "$key" ] || fail "chave de atestado insegura em .git/sdd-state"
    [ "$(wc -c <"$key" | tr -d ' ')" -eq 32 ] \
      || fail "chave de atestado invalida em .git/sdd-state"
  else
    umask 077
    dd if=/dev/urandom of="$key" bs=32 count=1 2>/dev/null \
      || fail "nao foi possivel criar chave de atestado"
  fi
  chmod 600 "$key"
  printf '%s' "$key"
}

attestation_ttl() {
  local ttl
  ttl="$(policy_optional_scalar 'consolidation.attestation_ttl_seconds')"
  [ -n "$ttl" ] || ttl=300
  [[ "$ttl" =~ ^[0-9]+$ ]] && [ "$ttl" -ge 1 ] && [ "$ttl" -le 3600 ] \
    || fail "consolidation.attestation_ttl_seconds deve estar entre 1 e 3600"
  printf '%s' "$ttl"
}

emit_consolidation_attestation() {
  local state_dir key head now expires ttl target impact_root impact_file domain
  local tmp payload_signature token
  local -a domains=()
  state_dir="$(git_state_dir)" || fail "repositorio Git obrigatorio para atestado"
  mkdir -p "$state_dir"
  [ -d "$state_dir" ] && [ ! -L "$state_dir" ] || fail "diretorio de atestado inseguro"
  key="$(ensure_attestation_key "$state_dir")"
  head="$(current_head)" || fail "HEAD obrigatorio para atestado"
  ttl="$(attestation_ttl)"
  now="$(date -u +%s)"
  expires=$((now + ttl))
  target="$(yaml_scalar 'classificacao.alvo_contrato')"
  impact_root="$inc/impacto-contratual"

  if [ -d "$impact_root" ] && [ ! -L "$impact_root" ]; then
    shopt -s nullglob
    for impact_file in "$impact_root"/*/contrato.md; do
      [ -f "$impact_file" ] && [ ! -L "$impact_file" ] \
        || fail "impacto contratual deve ser arquivo regular: ${impact_file#$root/}"
      domain="${impact_file%/contrato.md}"
      domain="${domain##*/}"
      case "$domain" in ""|.|..|*=*|*$'\n'*|*$'\r'*|*$'\t'*) fail "dominio de impacto invalido" ;; esac
      domains+=("$domain")
    done
    shopt -u nullglob
  elif [ -e "$impact_root" ]; then
    fail "impacto-contratual nao pode ser symlink"
  fi

  umask 077
  tmp="$(mktemp "$state_dir/.${feature}.XXXXXX")"
  {
    printf 'version=1\n'
    printf 'feature=%s\n' "$feature"
    printf 'head=%s\n' "$head"
    printf 'issued=%s\n' "$now"
    printf 'expires=%s\n' "$expires"
    printf 'target=%s\n' "$target"
    printf 'domains_count=%s\n' "${#domains[@]}"
    for domain in "${domains[@]}"; do printf 'domain=%s\n' "$domain"; done
  } >"$tmp"
  payload_signature="$({ command cat "$key"; command cat "$tmp"; command cat "$key"; } | sha256_stream)" \
    || { rm -f "$tmp"; fail "SHA-256 indisponivel para assinar atestado"; }
  printf 'signature=%s\n' "$payload_signature" >>"$tmp"
  chmod 600 "$tmp"
  token="$state_dir/$feature.ready"
  rm -f "$state_dir/$feature.ready" "$state_dir/$feature.active"
  mv "$tmp" "$token"
}

attestation_result=""
attestation_feature=""

verify_attestation_for_domain() {
  local token="$1" wanted_domain="$2" key="$3" now="$4" head="$5"
  local last signature expected payload_signature count i line token_feature token_head issued expires
  local domains_count target domain domain_match=0
  local -a lines
  attestation_result="invalid"
  attestation_feature=""
  [ -f "$token" ] && [ ! -L "$token" ] || return 2
  mapfile -t lines <"$token" || return 2
  [ "${#lines[@]}" -ge 8 ] || return 2
  last=$((${#lines[@]} - 1))
  signature="${lines[$last]}"
  [[ "$signature" =~ ^signature=([0-9a-f]{64})$ ]] || return 2
  expected="${BASH_REMATCH[1]}"
  [ "${lines[0]}" = version=1 ] || return 2
  [[ "${lines[1]}" == feature=* ]] || return 2
  [[ "${lines[2]}" == head=* ]] || return 2
  [[ "${lines[3]}" == issued=* ]] || return 2
  [[ "${lines[4]}" == expires=* ]] || return 2
  [[ "${lines[5]}" == target=* ]] || return 2
  [[ "${lines[6]}" == domains_count=* ]] || return 2
  token_feature="${lines[1]#feature=}"
  token_head="${lines[2]#head=}"
  issued="${lines[3]#issued=}"
  expires="${lines[4]#expires=}"
  target="${lines[5]#target=}"
  domains_count="${lines[6]#domains_count=}"
  [[ "$token_feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || return 2
  [[ "$token_head" =~ ^[0-9a-fA-F]{40,64}$ ]] || return 2
  [[ "$issued" =~ ^[0-9]+$ && "$expires" =~ ^[0-9]+$ && "$domains_count" =~ ^[0-9]+$ ]] || return 2
  [ -n "$target" ] || return 2
  count=$((last - 7))
  [ "$count" -eq "$domains_count" ] || return 2
  for ((i = 7; i < last; i++)); do
    line="${lines[$i]}"
    [[ "$line" == domain=* ]] || return 2
    domain="${line#domain=}"
    case "$domain" in ""|.|..|*=*|*$'\n'*|*$'\r'*|*$'\t'*) return 2 ;; esac
    [ "$domain" = "$wanted_domain" ] && domain_match=1
  done
  payload_signature="$({ command cat "$key"; printf '%s\n' "${lines[@]:0:$last}"; command cat "$key"; } | sha256_stream)" \
    || return 2
  [ "$payload_signature" = "$expected" ] || return 2
  if [ "$token_head" != "$head" ] || [ "$now" -lt "$issued" ] || [ "$now" -gt "$expires" ]; then
    attestation_result="stale"
    return 3
  fi
  if [ "$domain_match" -eq 1 ]; then
    attestation_result="match"
    attestation_feature="$token_feature"
    return 0
  fi
  attestation_result="other"
  return 1
}

authorize_contract_path() {
  local rel="$1" suffix domain state_dir key head now token rc active matches=0 matched=""
  local matched_feature="" state_yaml state_data state_status state_phase
  local -a tokens
  case "$rel" in
    .|sdd|sdd/contratos) fail2 "nao e permitido alterar ancestral ou raiz de sdd/contratos" ;;
    sdd/contratos/*) ;;
    *) return 0 ;;
  esac
  suffix="${rel#sdd/contratos/}"
  domain="${suffix%%/*}"
  [ -n "$domain" ] || fail2 "dominio do contrato ausente"
  state_dir="$(git_state_dir)" || fail2 "repositorio Git obrigatorio para validar atestado"
  key="$state_dir/.attestation-key"
  [ -f "$key" ] && [ ! -L "$key" ] || fail2 "atestado de pre-consolidate ausente"
  head="$(current_head)" || fail2 "HEAD invalido ao validar atestado"
  now="$(date -u +%s)"
  shopt -s nullglob
  tokens=("$state_dir"/*.ready "$state_dir"/*.active)
  shopt -u nullglob
  [ "${#tokens[@]}" -gt 0 ] || fail2 "atestado de pre-consolidate ausente"
  for token in "${tokens[@]}"; do
    rc=0
    verify_attestation_for_domain "$token" "$domain" "$key" "$now" "$head" || rc=$?
    case "$rc" in
      0) matches=$((matches + 1)); matched="$token"; matched_feature="$attestation_feature" ;;
      1) ;;
      2) fail2 "atestado de consolidacao malformado ou com assinatura invalida" ;;
      3) rm -f "$token" ;;
      *) fail2 "falha ao validar atestado de consolidacao" ;;
    esac
  done
  [ "$matches" -eq 1 ] || fail2 "nenhum atestado unico liga HEAD, feature e dominio '$domain'"
  state_yaml="$root/sdd/incrementos/$matched_feature/incremento.yaml"
  [ -f "$state_yaml" ] && [ ! -L "$state_yaml" ] \
    || fail2 "incremento ativo do atestado nao existe mais"
  state_data="$(canonical_yaml_dump "$state_yaml" 2>/dev/null)" \
    || fail2 "incremento ativo do atestado esta malformado"
  state_status="$(dump_optional_scalar "$state_data" status)"
  state_phase="$(dump_optional_scalar "$state_data" fase)"
  [ "$state_status" = validado ] && [ "$state_phase" = fechamento ] \
    || fail2 "atestado exige status validado e fase fechamento no incremento ativo"
  if [[ "$matched" == *.ready ]]; then
    active="${matched%.ready}.active"
    mv "$matched" "$active" || fail2 "nao foi possivel consumir atestado"
    matched="$active"
  fi
  umask 077
  printf '%s\t%s\t%s\n' "$now" "${matched##*/}" "$rel" >>"$state_dir/usage.log"
}

protected_record_indexes() {
  awk -F '\t' '
    $2 ~ /^protected_paths\[[0-9]+\]\./ {
      value = $2
      sub(/^protected_paths\[/, "", value)
      sub(/\].*$/, "", value)
      seen[value] = 1
    }
    END { for (value in seen) print value }
  ' <<<"$policy_data" | sort -n
}

protect_path() {
  local rel index pattern normalized access step unknown auth_feature target
  rel="$(canonicalize_path "$1")"

  case "$rel" in
    .git|.git/*) fail2 ".git e metadata protegida" ;;
  esac
  case "$rel" in
    .claude/settings.json|\
    .github/workflows/sdd-guard.yml|.github/workflows/template-evals.yml|\
    governanca/sdd-guard.sh|governanca/sdd-hook-claude.sh|\
    governanca/sdd-fluxo.sh|governanca/sdd-metricas.sh|\
    governanca/sdd-watch.sh.example|governanca/watch.yaml.example|\
    governanca/policies.yaml|governanca/policies.yaml.example|\
    evals|evals/*|scripts/validate-template.sh|install.sh|\
    sdd/governanca/sdd-guard.sh|sdd/governanca/sdd-hook-claude.sh|\
    sdd/governanca/sdd-fluxo.sh|sdd/governanca/sdd-metricas.sh|\
    sdd/governanca/sdd-watch.sh|sdd/governanca/watch.yaml|\
    sdd/governanca/policies.yaml|sdd/evals|sdd/evals/*)
      auth_feature="${SDD_FEATURE:-}"
      [[ "$auth_feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
        || fail2 "$rel exige SDD_FEATURE e autoridade externa de governanca"
      target="${SDD_AUTH_TARGET:-$rel}"
      authority_check_external "$auth_feature" governance_change "$target" \
        || fail2 "autoridade externa nao comprovada para alterar governanca: $rel"
      return 0
      ;;
  esac
  case "$rel" in
    .|sdd|sdd/contratos|sdd/contratos/*) authorize_contract_path "$rel" ;;
  esac

  if ! load_policies; then
    fail2 "$policy_load_reason"
  fi
  if dump_has_path "$policy_data" protected_paths; then
    awk -F '\t' '
      $2 == "protected_paths" && $1 == "S" { bad = 1 }
      $2 == "protected_paths" && $1 == "L" { bad = 1 }
      END { exit(bad ? 1 : 0) }
    ' <<<"$policy_data" || fail2 "protected_paths deve ser lista de mapas canonica"
  fi
  while IFS= read -r index; do
    [ -n "$index" ] || continue
    unknown="$(awk -F '\t' -v prefix="protected_paths[$index]." '
      index($2, prefix) == 1 {
        key = substr($2, length(prefix) + 1)
        if (key != "path" && key != "access" && key != "writable_only_in_step") print key
      }
    ' <<<"$policy_data")"
    [ -z "$unknown" ] || fail2 "atributo desconhecido em protected_paths[$index]: $unknown"
    pattern="$(dump_optional_scalar "$policy_data" "protected_paths[$index].path")"
    [ -n "$pattern" ] || fail2 "protected_paths[$index].path ausente"
    normalized="$(normalize_policy_pattern "$pattern")" \
      || fail2 "padrao protegido inseguro: $pattern"
    access="$(dump_optional_scalar "$policy_data" "protected_paths[$index].access")"
    step="$(dump_optional_scalar "$policy_data" "protected_paths[$index].writable_only_in_step")"
    [ -n "$access" ] || { [ -n "$step" ] && access=step || access=deny; }
    case "$access" in deny|deny_unless_explicit|step) ;; *) fail2 "access invalido em protected_paths[$index]" ;; esac
    if path_intersects "$rel" "$normalized" \
       || directory_intersects_pattern "$rel" "$normalized"; then
      case "$access" in
        deny) fail2 "caminho negado por policies: $rel" ;;
        deny_unless_explicit)
          auth_feature="${SDD_FEATURE:-}"
          [[ "$auth_feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
            || fail2 "$rel exige SDD_FEATURE e autoridade externa"
          target="${SDD_AUTH_TARGET:-$rel}"
          authority_check_external "$auth_feature" protected_path "$target" \
            || fail2 "autoridade externa nao comprovada para $rel"
          ;;
        step)
          case "$step" in 13|pre-consolidate) authorize_contract_path "$rel" ;; *) fail2 "janela protegida desconhecida: $step" ;; esac
          ;;
      esac
    fi
  done < <(protected_record_indexes)
}

protect_ci_path() {
  local rel auth_feature
  rel="$(canonicalize_path "$1")"
  [ -n "${SDD_TRUSTED_POLICIES:-}" ] \
    || fail2 "protect-ci exige SDD_TRUSTED_POLICIES extraida de uma base confiavel"
  case "$rel" in
    sdd/contratos|sdd/contratos/*)
      auth_feature="${SDD_FEATURE:-repository}"
      [[ "$auth_feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
        || fail2 "SDD_FEATURE invalida para validar contrato no CI"
      authority_check_external "$auth_feature" contract_change "$rel" \
        || fail2 "autoridade externa nao comprovada para alterar $rel"
      ;;
    .claude/settings.json|.github/workflows/sdd-guard.yml|.github/workflows/template-evals.yml|install.sh|scripts/validate-template.sh|sdd/governanca/sdd-guard.sh|sdd/governanca/sdd-hook-claude.sh|sdd/governanca/sdd-fluxo.sh|sdd/governanca/sdd-metricas.sh|sdd/governanca/sdd-watch.sh|sdd/governanca/watch.yaml|sdd/governanca/policies.yaml|sdd/evals|sdd/evals/*|governanca/sdd-guard.sh|governanca/sdd-hook-claude.sh|governanca/sdd-fluxo.sh|governanca/sdd-metricas.sh|governanca/sdd-watch.sh.example|governanca/watch.yaml.example|governanca/policies.yaml.example|evals|evals/*)
      auth_feature="${SDD_FEATURE:-repository}"
      [[ "$auth_feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
        || fail2 "SDD_FEATURE invalida para governanca no CI"
      authority_check_external "$auth_feature" governance_change "$rel" \
        || fail2 "autoridade externa nao comprovada para alterar trust root: $rel"
      ;;
    *) protect_path "$rel" ;;
  esac
}

is_allowed_secret_file() {
  local rel="$1" pattern normalized
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    normalized="$(normalize_policy_pattern "$pattern")" || fail "allowed_files contem caminho inseguro: $pattern"
    path_matches "$rel" "$normalized" && return 0
  done < <(dump_list "$policy_data" 'secrets.allowed_files')
  return 1
}

secret_patterns=()
secret_engine=""

load_secret_patterns() {
  local pattern rc
  require_policies
  dump_has_path "$policy_data" 'secrets.forbidden_patterns' \
    || fail "secrets.forbidden_patterns ausente"
  awk -F '\t' '
    $2 == "secrets.forbidden_patterns" && $1 == "S" { bad = 1 }
    index($2, "secrets.forbidden_patterns.") == 1 { bad = 1 }
    index($2, "secrets.forbidden_patterns[") == 1 && $1 == "S" { bad = 1 }
    END { exit(bad ? 1 : 0) }
  ' <<<"$policy_data" || fail "secrets.forbidden_patterns deve ser lista escalar canonica"
  if dump_has_path "$policy_data" 'secrets.allowed_files'; then
    awk -F '\t' '
      $2 == "secrets.allowed_files" && $1 == "S" { bad = 1 }
      index($2, "secrets.allowed_files.") == 1 { bad = 1 }
      index($2, "secrets.allowed_files[") == 1 && $1 == "S" { bad = 1 }
      END { exit(bad ? 1 : 0) }
    ' <<<"$policy_data" || fail "secrets.allowed_files deve ser lista escalar canonica"
  fi
  secret_patterns=()
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || fail "forbidden_patterns contem regex vazia"
    secret_patterns+=("$pattern")
  done < <(dump_list "$policy_data" 'secrets.forbidden_patterns')
  [ "${#secret_patterns[@]}" -gt 0 ] || fail "secrets.forbidden_patterns vazio ou ausente"
  if printf 'x\n' | grep -aP -- 'x' >/dev/null 2>&1; then secret_engine=pcre; else secret_engine=ere; fi
  for pattern in "${secret_patterns[@]}"; do
    rc=0
    if [ "$secret_engine" = pcre ]; then
      printf '' | grep -aP -- "$pattern" >/dev/null 2>&1 || rc=$?
    else
      pattern="${pattern#(?i)}"
      printf '' | grep -aE -- "$pattern" >/dev/null 2>&1 || rc=$?
    fi
    [ "$rc" -le 1 ] || fail "regex invalida em secrets.forbidden_patterns"
  done
}

scan_one_file() {
  local logical="$1" physical="$2" pattern effective output rc hits status=0 policy_declaration=0
  local placeholder_file=0 filtered
  if is_allowed_secret_file "$logical"; then placeholder_file=1; fi
  case "$logical" in
    governanca/policies.yaml|governanca/policies.yaml.example|sdd/governanca/policies.yaml) policy_declaration=1 ;;
  esac
  for pattern in "${secret_patterns[@]}"; do
    effective="$pattern"
    rc=0
    if [ "$policy_declaration" -eq 1 ]; then
      if [ "$secret_engine" = pcre ]; then
        output="$(LC_ALL=C awk '
          /^  forbidden_patterns:[[:space:]]*($|#)/ { inside=1; print ""; next }
          inside && /^    -[[:space:]]/ { print ""; next }
          inside && !/^[[:space:]]*(#|$)/ { inside=0 }
          { print }
        ' "$physical" | grep -anP -- "$effective" 2>/dev/null)" || rc=$?
      else
        effective="${effective#(?i)}"
        output="$(LC_ALL=C awk '
          /^  forbidden_patterns:[[:space:]]*($|#)/ { inside=1; print ""; next }
          inside && /^    -[[:space:]]/ { print ""; next }
          inside && !/^[[:space:]]*(#|$)/ { inside=0 }
          { print }
        ' "$physical" | grep -aniE -- "$effective" 2>/dev/null)" || rc=$?
      fi
    elif [ "$secret_engine" = pcre ]; then
      output="$(LC_ALL=C grep -anP -- "$effective" "$physical" 2>/dev/null)" || rc=$?
    else
      effective="${effective#(?i)}"
      output="$(LC_ALL=C grep -aniE -- "$effective" "$physical" 2>/dev/null)" || rc=$?
    fi
    [ "$rc" -le 1 ] || fail "regex invalida durante scan"
    if [ "$rc" -eq 0 ] && [ "$placeholder_file" -eq 1 ]; then
      case "$pattern" in
        *'api[_-]?key|token|password'*)
          filtered="$(awk '
            function trim(value) {
              sub(/^[[:space:]]+/, "", value)
              sub(/[[:space:]]+$/, "", value)
              return value
            }
            {
              original=$0
              text=$0
              sub(/^[0-9]+:/, "", text)
              lowered=tolower(text)
              if (!match(lowered, /(api[_-]?key|token|password)[[:space:]]*[:=]/)) {
                print original
                next
              }
              value=trim(substr(text, RSTART + RLENGTH))
              quote=substr(value, 1, 1)
              if (quote == "\047" || quote == "\042") {
                rest=substr(value, 2)
                closing=index(rest, quote)
                if (!closing) {
                  print original
                  next
                }
                trailing=trim(substr(rest, closing + 1))
                if (trailing != "" && substr(trailing, 1, 1) != "#") {
                  print original
                  next
                }
                value=substr(rest, 1, closing - 1)
              } else {
                sub(/[[:space:]]+#.*/, "", value)
                value=trim(value)
              }
              value=tolower(value)
              if (value !~ /^(changeme|change_me|change-me|example|dummy|placeholder|test)$/) print original
            }
          ' <<<"$output")"
          output="$filtered"
          [ -n "$output" ] || rc=1
          ;;
      esac
    fi
    if [ "$rc" -eq 0 ]; then
      hits="$(awk -F: 'NR <= 5 { values = values (values ? "," : "") $1 } END { print values }' <<<"$output")"
      printf 'SDD GUARD (bloqueado): segredo detectado em %s (linhas %s)\n' "$logical" "$hits" >&2
      status=2
    fi
  done
  return "$status"
}

scan_secrets() {
  local file rel status=0 rc=0
  [ "$#" -ge 1 ] || fail "scan-secrets exige ao menos um arquivo"
  load_secret_patterns
  for file in "$@"; do
    [ -e "$file" ] || fail "arquivo solicitado para scan ausente: $file"
    [ -f "$file" ] && [ ! -L "$file" ] || fail "scan exige arquivo regular: $file"
    rel="$(canonicalize_path "$file")"
    scan_one_file "$rel" "$root/$rel" || rc=$?
    [ "$rc" -eq 0 ] || status="$rc"
  done
  return "$status"
}

scan_content() {
  local logical="$1" rel content status=0 rc=0
  shift
  [ "$#" -ge 1 ] || fail "scan-content exige arquivo de conteudo"
  load_secret_patterns
  rel="$(canonicalize_path "$logical")"
  for content in "$@"; do
    [ -f "$content" ] && [ ! -L "$content" ] || fail "conteudo temporario invalido"
    scan_one_file "$rel" "$content" || rc=$?
    [ "$rc" -eq 0 ] || status="$rc"
  done
  return "$status"
}

case "$command_name" in
  validate-policy)
    [ "$#" -eq 1 ] || { usage; exit 2; }
    require_policies
    load_secret_patterns
    ok "policies canonica valida (version $(policy_scalar version))"
    ;;

  pre-specify)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    require_policies
    validate_specification planned
    ok "especificacao, plano, auditoria e autoridade estao validos para transicao"
    ;;

  pre-implement)
    [ "$#" -eq 3 ] || { usage; exit 2; }
    init_feature
    require_policies
    [[ "$task" =~ ^task_[0-9][0-9]$ ]] || fail "informe task_NN valida"
    validate_specification valid "$task" start
    implementation_status="$(yaml_scalar status)"
    case "$implementation_status" in
      especificado|em_execucao) ;;
      *) fail "status do incremento deve ser especificado ou em_execucao antes de uma task" ;;
    esac
    ok "pre-condicoes de implementacao atendidas"
    ;;

  pre-complete)
    [ "$#" -eq 3 ] || { usage; exit 2; }
    init_feature
    require_policies
    load_increment
    require_increment_status em_execucao
    require_report_status "$audit" PRONTO Resumo
    validate_audit_evidence
    [[ "$task" =~ ^task_[0-9][0-9]$ ]] || fail "informe task_NN valida"
    all_tasks_with_mode valid
    validate_task_file "$wf/$task.md" completed
    validate_task_dependencies "$task" complete
    check_contracts_untouched
    if command -v compozy >/dev/null 2>&1; then
      compozy tasks validate --name "$feature" >/dev/null \
        || fail "compozy tasks validate falhou"
    fi
    run_quality_commands pre-complete
    check_contracts_untouched
    ok "task concluida com gates de qualidade e integridade"
    ;;

  pre-validate)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    require_policies
    load_increment
    require_increment_status em_execucao
    validate_delivery_evidence
    run_quality_commands pre-validate
    check_contracts_untouched
    ok "tasks, review, QA e blockers estao validos para transicao"
    ;;

  pre-merge)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    require_policies
    require_increment_status validado
    validate_delivery_evidence
    run_quality_commands pre-merge
    check_contracts_untouched
    require_human_gate merge true
    ok "pre-condicoes tecnicas e autoridade externa de merge atendidas"
    ;;

  pre-merge-ci)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    require_policies
    require_increment_status validado
    validate_delivery_evidence
    check_contracts_untouched
    head="$(current_head)" || fail "HEAD invalido para evidencia de qualidade no CI"
    require_authority "$feature" quality_evidence_pre_merge "$head"
    require_human_gate merge true
    ok "metadados, checks externos e autoridade de merge atendidos sem executar codigo candidato"
    ;;

  pre-production)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    require_policies
    require_increment_status validado
    validate_delivery_evidence
    require_merge_evidence
    require_human_gate merge true
    [ "$(yaml_scalar 'classificacao.alvo_contrato')" = producao ] \
      || fail "alvo_contrato deve ser producao"
    [ -n "$(yaml_scalar 'deploy.rollback')" ] || fail "rollback de producao nao definido"
    require_recent_production_approval
    ok "pre-condicoes e autoridade externa de producao atendidas"
    ;;

  pre-consolidate)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    require_policies
    require_increment_status validado
    validate_delivery_evidence
    run_quality_commands pre-consolidate
    check_contracts_untouched
    target="$(yaml_scalar 'classificacao.alvo_contrato')"
    case "$target" in
      producao)
        require_merge_evidence
        require_human_gate merge true
        require_deploy_evidence
        require_recent_production_approval
        ;;
      branch)
        require_merge_evidence
        require_human_gate merge true
        ;;
      local)
        [ -n "$(yaml_scalar 'classificacao.motivo')" ] \
          || fail "alvo local exige classificacao.motivo"
        ;;
      *) fail "alvo_contrato invalido: $target" ;;
    esac
    emit_consolidation_attestation
    ok "pre-condicoes atendidas; atestado efemero emitido em .git/sdd-state"
    ;;

  authority-check)
    [ "$#" -ge 3 ] && [ "$#" -le 4 ] || { usage; exit 2; }
    feature="$2"
    gate="$3"
    target="${4:-${SDD_AUTH_TARGET:-HEAD}}"
    authority_check_external "$feature" "$gate" "$target" \
      || fail "autoridade externa nao comprovada para '$gate'"
    ok "autoridade externa comprovada para $gate"
    ;;

  review-required)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    init_feature
    load_increment
    if review_is_required; then printf 'sim\n'; else printf 'nao\n'; fi
    ;;

  protect)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    protect_path "$2"
    ;;

  protect-ci)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    protect_ci_path "$2"
    ;;

  scan-secrets)
    [ "$#" -ge 2 ] || { usage; exit 2; }
    shift
    if scan_secrets "$@"; then ok "nenhum segredo detectado"; else exit $?; fi
    ;;

  scan-content)
    [ "$#" -ge 3 ] || { usage; exit 2; }
    logical="$2"
    shift 2
    if scan_content "$logical" "$@"; then ok "conteudo sem segredo"; else exit $?; fi
    ;;

  *)
    usage
    exit 2
    ;;
esac
