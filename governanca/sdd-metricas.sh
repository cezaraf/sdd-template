#!/usr/bin/env bash
# Metricas do fluxo SDD (indicadores leading/lagging por incremento).
#
# Fontes: bloco `metricas:` do incremento.yaml (canonico) com fallback para o
# historico git do artefato correspondente.
#
# Uso:
#   sdd-metricas.sh <feature>                       # imprime relatorio markdown
#   sdd-metricas.sh <feature> --csv                 # upsert em sdd/metricas.csv
#   sdd-metricas.sh <feature> --marcar <campo>      # registra data UTC no campo
#   sdd-metricas.sh <feature> --atualizar-relatorio # atualiza relatorio-fechamento.md
set -euo pipefail

usage() {
  printf 'Uso: sdd-metricas.sh <feature> [--csv|--marcar CAMPO|--atualizar-relatorio]\n'
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  '') usage >&2; exit 2 ;;
esac

feature="$1"
shift
[[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  printf 'SDD METRICAS: feature invalida: %s\n' "$feature" >&2
  exit 2
}
MODE="report"
FIELD=""
case "$#" in
  0) ;;
  1)
    case "$1" in
      --csv) MODE="csv" ;;
      --atualizar-relatorio) MODE="relatorio" ;;
      *) usage >&2; exit 2 ;;
    esac
    ;;
  2)
    if [ "$1" != "--marcar" ]; then
      usage >&2
      exit 2
    fi
    MODE="marcar"
    FIELD="$2"
    ;;
  *) usage >&2; exit 2 ;;
esac

if [ "$MODE" = "marcar" ]; then
  case "$FIELD" in
    data_triagem|data_especificado|data_primeira_task|data_validado|data_merge|data_deploy|data_consolidado) ;;
    *)
      printf 'SDD METRICAS: campo nao permitido em metricas: %s\n' "$FIELD" >&2
      exit 2
      ;;
  esac
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
root="$(cd "$root" && pwd -P)"
yaml="$root/sdd/incrementos/$feature/incremento.yaml"
wf="$root/.compozy/tasks/$feature"
for directory in "$root/sdd" "$root/sdd/incrementos" "$root/sdd/incrementos/$feature"; do
  [ -d "$directory" ] && [ ! -L "$directory" ] \
    || { printf 'SDD METRICAS: diretorio canonico ausente ou inseguro: %s\n' "${directory#"$root"/}" >&2; exit 1; }
  [ "$(cd "$directory" && pwd -P)" = "$directory" ] \
    || { printf 'SDD METRICAS: diretorio fora do repositorio: %s\n' "${directory#"$root"/}" >&2; exit 1; }
done
[ -f "$yaml" ] && [ ! -L "$yaml" ] \
  || { printf 'SDD METRICAS: incremento ausente ou inseguro: %s\n' "$feature" >&2; exit 1; }
if [ -e "$wf" ]; then
  [ -d "$wf" ] && [ ! -L "$wf" ] && [ "$(cd "$wf" && pwd -P)" = "$wf" ] \
    || { printf 'SDD METRICAS: diretorio de tarefas inseguro: %s\n' "$feature" >&2; exit 1; }
fi

yaml_value() {
  LC_ALL=C awk -v target="$2" '
    function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    function clean(v) {
      sub(/[[:space:]]+#.*/, "", v)
      v = trim(v)
      if ((v ~ /^".*"$/) || (v ~ /^\047.*\047$/)) v = substr(v, 2, length(v) - 2)
      return v
    }
    /^[[:space:]]*(#|$)/ { next }
    {
      match($0, /^[ ]*/)
      indent = RLENGTH
      line = substr($0, indent + 1)
      if (line !~ /^[A-Za-z0-9_-]+:[[:space:]]*/) next
      key = line
      sub(/:.*/, "", key)
      value = line
      sub(/^[^:]+:[[:space:]]*/, "", value)
      level = int(indent / 2) + 1
      stack[level] = key
      for (i = level + 1; i <= 20; i++) delete stack[i]
      current = stack[1]
      for (i = 2; i <= level; i++) current = current "." stack[i]
      if (current == target && value != "") { print clean(value); exit }
    }
  ' "$1"
}

iso_to_epoch() {
  local ts="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
from datetime import datetime, timezone
import sys
raw = sys.argv[1].strip()
try:
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    dt = datetime.fromisoformat(raw)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except ValueError:
    raise SystemExit(1)
' "$ts" && return
  fi
  date -u -d "$ts" +%s 2>/dev/null && return
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ts" +%s 2>/dev/null && return
  date -u -j -f '%Y-%m-%d' "$ts" +%s 2>/dev/null && return
  return 1
}

relative_to_root() {
  case "$1" in
    "$root"/*) printf '%s' "${1#"$root"/}" ;;
    *) return 1 ;;
  esac
}

first_commit_date() {
  local file="$1" relative
  [ -f "$file" ] || return 1
  relative="$(relative_to_root "$file")" || return 1
  git -C "$root" log --follow --format=%aI --reverse -- "$relative" 2>/dev/null \
    | awk 'NR == 1 { first = $0 } END { if (first != "") print first }'
}

first_commit_date_many() {
  local file relative
  local -a relatives=()
  for file in "$@"; do
    [ -f "$file" ] || continue
    relative="$(relative_to_root "$file")" || continue
    relatives+=("$relative")
  done
  [ "${#relatives[@]}" -gt 0 ] || return 1
  git -C "$root" log --format=%aI --reverse -- "${relatives[@]}" 2>/dev/null \
    | awk 'NR == 1 { first = $0 } END { if (first != "") print first }'
}

first_task_date() {
  local -a files=()
  shopt -s nullglob
  files=("$wf"/task_[0-9][0-9].md)
  shopt -u nullglob
  [ "${#files[@]}" -gt 0 ] || return 1
  first_commit_date "${files[0]}"
}

first_qa_date() {
  local -a files=()
  shopt -s nullglob
  files=("$wf"/qa/*-qa-report.md)
  shopt -u nullglob
  [ "${#files[@]}" -gt 0 ] || return 1
  first_commit_date_many "${files[@]}"
}

metric_field() {
  local field="$1" value=""
  value="$(yaml_value "$yaml" "metricas.$field")"
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi
  case "$field" in
    data_triagem)       first_commit_date "$yaml" || true ;;
    data_especificado)  first_commit_date "$wf/auditoria-especificacao.md" || true ;;
    data_primeira_task) first_task_date || true ;;
    data_validado)      first_qa_date || true ;;
    data_merge)         first_commit_date "$wf/pr/merge-report.md" || true ;;
    data_deploy)        first_commit_date "$wf/ops/deploy-report.md" || true ;;
    data_consolidado)   yaml_value "$yaml" 'fechamento.consolidado_em' || true ;;
  esac
}

mark_metric() {
  local field="$1" value="$2" tmp
  tmp="$(mktemp "${yaml}.tmp.XXXXXX")" || return 1
  if ! cp -p "$yaml" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if ! LC_ALL=C awk -v field="$field" -v value="$value" '
      function indentation(line) { match(line, /^[ ]*/); return RLENGTH }
      function body_at(line, indent) { return substr(line, indent + 1) }
      function mapping_key(body, key) {
        if (body !~ /^[A-Za-z0-9_-]+:[[:space:]]*/) return ""
        key = body
        sub(/:.*/, "", key)
        return key
      }
      function comment_for(body, rest) {
        rest = body
        sub(/^[^:]+:/, "", rest)
        if (match(rest, /[[:space:]]+#/)) return substr(rest, RSTART)
        return ""
      }
      { lines[NR] = $0 }
      END {
        count = 0
        for (i = 1; i <= NR; i++) {
          indent = indentation(lines[i])
          body = body_at(lines[i], indent)
          if (indent == 0 && body ~ /^metricas:[[:space:]]*/) {
            count++
            start = i
            declaration = body
          }
        }
        if (count > 1) exit 2
        if (count == 0) {
          for (i = 1; i <= NR; i++) print lines[i]
          if (NR > 0 && lines[NR] != "") print ""
          print "metricas:"
          print "  " field ": " value
          exit 0
        }

        rest = declaration
        sub(/^metricas:[[:space:]]*/, "", rest)
        inline_empty = (rest ~ /^(\{\}|null|~)[[:space:]]*($|#)/)
        block = (rest == "" || rest ~ /^#/)
        if (!inline_empty && !block) exit 2

        finish = NR + 1
        for (i = start + 1; i <= NR; i++) {
          if (lines[i] ~ /^[[:space:]]*(#|$)/) continue
          indent = indentation(lines[i])
          if (indent == 0) { finish = i; break }
        }

        direct_indent = 0
        if (block) {
          for (i = start + 1; i < finish; i++) {
            if (lines[i] ~ /^[[:space:]]*(#|$)/) continue
            indent = indentation(lines[i])
            body = body_at(lines[i], indent)
            if (mapping_key(body) == "") continue
            if (direct_indent == 0 || indent < direct_indent) direct_indent = indent
          }
        }
        if (direct_indent == 0) direct_indent = 2

        targets = 0
        if (block) {
          for (i = start + 1; i < finish; i++) {
            indent = indentation(lines[i])
            body = body_at(lines[i], indent)
            if (indent == direct_indent && mapping_key(body) == field) targets++
          }
        }
        if (targets > 1) exit 2

        inserted = 0
        for (i = 1; i <= NR; i++) {
          if (i == start && inline_empty) {
            comment = ""
            if (match(lines[i], /[[:space:]]+#/)) comment = substr(lines[i], RSTART)
            print "metricas:" comment
            printf "%*s%s: %s\n", direct_indent, "", field, value
            inserted = 1
            continue
          }
          if (i == finish && block && targets == 0) {
            printf "%*s%s: %s\n", direct_indent, "", field, value
            inserted = 1
          }
          if (block && i > start && i < finish) {
            indent = indentation(lines[i])
            body = body_at(lines[i], indent)
            if (indent == direct_indent && mapping_key(body) == field) {
              comment = comment_for(body)
              printf "%*s%s: %s%s\n", direct_indent, "", field, value, comment
              inserted = 1
              continue
            }
          }
          print lines[i]
        }
        if (block && finish == NR + 1 && targets == 0) {
          printf "%*s%s: %s\n", direct_indent, "", field, value
          inserted = 1
        }
        if (!inserted) exit 2
      }
    ' "$yaml" >"$tmp"; then
    rm -f "$tmp"
    printf 'SDD METRICAS: bloco metricas invalido; arquivo preservado\n' >&2
    return 1
  fi
  if ! mv -f "$tmp" "$yaml"; then
    rm -f "$tmp"
    return 1
  fi
}

if [ "$MODE" = "marcar" ]; then
  metric_lock="${yaml}.sdd-metricas.lock"
  mkdir "$metric_lock" 2>/dev/null \
    || { printf 'SDD METRICAS: outra atualizacao de marco esta em andamento\n' >&2; exit 1; }
  cleanup_metric_lock() { rmdir "$metric_lock" 2>/dev/null || true; }
  trap cleanup_metric_lock EXIT HUP INT TERM
  current_value="$(yaml_value "$yaml" "metricas.$FIELD")"
  if [ -n "$current_value" ]; then
    iso_to_epoch "$current_value" >/dev/null \
      || { printf 'SDD METRICAS: marco existente invalido em metricas.%s\n' "$FIELD" >&2; exit 1; }
    printf 'SDD METRICAS: %s ja estava registrado; valor preservado\n' "$FIELD"
    exit 0
  fi
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mark_metric "$FIELD" "$timestamp" \
    || { printf 'SDD METRICAS: falha ao atualizar incremento.yaml\n' >&2; exit 1; }
  printf 'SDD METRICAS: %s registrado em metricas\n' "$FIELD"
  exit 0
fi

count_review_issues() {
  local file count=0
  local -a files=()
  shopt -s nullglob
  files=("$wf"/reviews-*/issue_[0-9][0-9][0-9].md)
  shopt -u nullglob
  for file in "${files[@]}"; do
    [ -f "$file" ] && count=$((count + 1))
  done
  printf '%s' "$count"
}

open_p01_bugs() {
  local file="$wf/bugs.md"
  [ -f "$file" ] || { printf '0'; return; }
  LC_ALL=C awk '
    function flush() {
      if (inbug && severity ~ /^p[01]$/ && status !~ /^(fixed|closed|corrigido|corrigida|resolvido|resolvida|done|concluido|concluida)$/) count++
    }
    /^##[[:space:]]+BUG-[0-9]+/ { flush(); inbug = 1; severity = ""; status = ""; next }
    inbug && /^[[:space:]-]*[Ss]everidade:/ {
      value = $0; sub(/^[^:]+:[[:space:]]*/, "", value); gsub(/[[:space:]\047\042]/, "", value); severity = tolower(value)
    }
    inbug && /^[[:space:]-]*[Ss]tatus:/ {
      value = $0; sub(/^[^:]+:[[:space:]]*/, "", value); gsub(/[[:space:]\047\042]/, "", value); status = tolower(value)
    }
    END { flush(); print count + 0 }
  ' "$file"
}

hours_between() {
  local start="$1" end="$2" start_epoch end_epoch
  if [ -z "$start" ] || [ -z "$end" ]; then
    printf '\n'
    return 0
  fi
  start_epoch="$(iso_to_epoch "$start")" || { printf '\n'; return 0; }
  end_epoch="$(iso_to_epoch "$end")" || { printf '\n'; return 0; }
  if [ "$end_epoch" -lt "$start_epoch" ]; then
    printf '\n'
    return 0
  fi
  printf '%s\n' "$(( (end_epoch - start_epoch + 1800) / 3600 ))"
}

hours_label() {
  if [ -n "$1" ]; then printf '%sh' "$1"; else printf 'NA'; fi
}

expected_plan_paths() {
  LC_ALL=C awk -F'|' '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    /^## Arquivos e superfícies esperadas[[:space:]]*$/ { section = 1; next }
    section && /^##[[:space:]]/ { exit }
    section && /^[[:space:]]*\|/ && $0 !~ /---/ {
      path = trim($3)
      if (path ~ /^`.*`$/) path = substr(path, 2, length(path) - 2)
      sub(/^\.\//, "", path)
      if (path != "" && path != "Arquivo/diretório") print path
    }
  ' "$plano" | LC_ALL=C sort -u
}

d_triagem="$(metric_field data_triagem)"
d_espec="$(metric_field data_especificado)"
d_task="$(metric_field data_primeira_task)"
d_valid="$(metric_field data_validado)"
d_merge="$(metric_field data_merge)"
d_deploy="$(metric_field data_deploy)"
d_consol="$(metric_field data_consolidado)"

h_espec="$(hours_between "$d_triagem" "$d_espec")"
h_impl="$(hours_between "$d_task" "$d_valid")"
h_val_merge="$(hours_between "$d_valid" "$d_merge")"
end_date="${d_consol:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
h_total="$(hours_between "$d_triagem" "$end_date")"
h_espec_label="$(hours_label "$h_espec")"
h_impl_label="$(hours_label "$h_impl")"
h_val_merge_label="$(hours_label "$h_val_merge")"
h_total_label="$(hours_label "$h_total")"

reaudit="$(yaml_value "$yaml" 'metricas.reauditorias')"
reaudit="${reaudit:-0}"
replan="$(yaml_value "$yaml" 'metricas.revisoes_plano')"
replan="${replan:-0}"
issues_total="$(count_review_issues)"
bugs_total="$(grep -cE '^##[[:space:]]+BUG-[0-9]+' "$wf/bugs.md" 2>/dev/null || true)"
bugs_total="${bugs_total:-0}"
p01_abertos="$(open_p01_bugs)"

aderencia=""
base_sha="$(yaml_value "$yaml" 'execucao.base_sha')"
plano="$root/sdd/incrementos/$feature/execucao.md"
if [ -n "$base_sha" ] && [ -f "$plano" ] \
   && git -C "$root" rev-parse -q --verify "$base_sha^{commit}" >/dev/null 2>&1; then
  mapfile -t expected_paths < <(expected_plan_paths)
  if [ "${#expected_paths[@]}" -eq 0 ]; then
    aderencia="indeterminada (plano sem paths esperados)"
  elif changed_raw="$(
      git -C "$root" -c core.quotepath=false diff --name-only "$base_sha"..HEAD -- &&
      git -C "$root" -c core.quotepath=false diff --cached --name-only -- &&
      git -C "$root" -c core.quotepath=false diff --name-only -- &&
      git -C "$root" -c core.quotepath=false ls-files --others --exclude-standard
    )"; then
    mapfile -t changed_paths < <(printf '%s\n' "$changed_raw" | LC_ALL=C sort -u)
  else
    printf 'SDD METRICAS: falha ao coletar alteracoes do git\n' >&2
    exit 1
  fi

  if [ "${#expected_paths[@]}" -gt 0 ]; then
    outside=0
    considered=0
    for changed in "${changed_paths[@]}"; do
      [ -n "$changed" ] || continue
      case "$changed" in
        ".compozy/tasks/$feature/auditoria-especificacao.md"|\
        ".compozy/tasks/$feature/bugs.md"|\
        ".compozy/tasks/$feature/reviews-"*|\
        ".compozy/tasks/$feature/qa/"*|\
        ".compozy/tasks/$feature/pr/"*|\
        ".compozy/tasks/$feature/ops/"*|\
        "sdd/incrementos/$feature/incremento.yaml"|\
        "sdd/incrementos/$feature/relatorio-fechamento.md"|\
        sdd/metricas.csv) continue ;;
      esac
      considered=$((considered + 1))
      planned=0
      for expected in "${expected_paths[@]}"; do
        expected="${expected%/}"
        if [ "$changed" = "$expected" ] || [[ "$changed" == "$expected/"* ]]; then
          planned=1
          break
        fi
      done
      [ "$planned" -eq 1 ] || outside=$((outside + 1))
    done
    if [ "$considered" -eq 0 ]; then
      aderencia="sem_alteracoes_de_implementacao"
    else
      aderencia="fora_do_plano=$outside/$considered"
    fi
  fi
fi

alvo="$(yaml_value "$yaml" 'classificacao.alvo_contrato')"

render_report() {
  cat <<EOF
### Métricas do fluxo - $feature

**Leading (tempo de ciclo)**

| Indicador | Valor |
| --- | --- |
| Triagem -> especificado (espec.) | $h_espec_label |
| Primeira task -> validado (impl.+verificacao) | $h_impl_label |
| Validado -> merge | $h_val_merge_label |
| Lead time total (triagem -> fim) | $h_total_label |

**Lagging (qualidade e retrabalho)**

| Indicador | Valor |
| --- | --- |
| Reauditorias da especificacao | $reaudit |
| Revisoes do plano | $replan |
| Issues de review (total) | $issues_total |
| Bugs registrados (total) | $bugs_total |
| P0/P1 abertos | $p01_abertos |
| Aderencia ao plano | ${aderencia:-indeterminada (sem base_sha)} |

Datas: triagem=${d_triagem:-NA} espec=${d_espec:-NA} task1=${d_task:-NA} valid=${d_valid:-NA} merge=${d_merge:-NA} deploy=${d_deploy:-NA} consolidado=${d_consol:-NA}
EOF
}

csv_escape() {
  local value="$1"
  case "$value" in
    *','*|*'"'*|*$'\n'*|*$'\r'*)
      value="${value//\"/\"\"}"
      printf '"%s"' "$value"
      ;;
    *) printf '%s' "$value" ;;
  esac
}

update_csv() {
  local csv="$root/sdd/metricas.csv" tmp header current_header row
  header='incremento,alvo,lead_especificacao_h,lead_implementacao_h,lead_validacao_merge_h,lead_total_h,reauditorias,revisoes_plano,issues_review,bugs,p01_abertos,aderencia'
  [ ! -L "$csv" ] \
    || { printf 'SDD METRICAS: sdd/metricas.csv nao pode ser link simbolico\n' >&2; return 1; }
  if [ -f "$csv" ]; then
    IFS= read -r current_header <"$csv" || true
    current_header="${current_header%$'\r'}"
    if [ "$current_header" != "$header" ]; then
      printf 'SDD METRICAS: cabecalho inesperado em sdd/metricas.csv; arquivo preservado\n' >&2
      return 1
    fi
  fi

  row="$(csv_escape "$feature"),$(csv_escape "$alvo"),$(csv_escape "${h_espec:-NA}"),$(csv_escape "${h_impl:-NA}"),$(csv_escape "${h_val_merge:-NA}"),$(csv_escape "${h_total:-NA}"),$(csv_escape "$reaudit"),$(csv_escape "$replan"),$(csv_escape "$issues_total"),$(csv_escape "$bugs_total"),$(csv_escape "$p01_abertos"),$(csv_escape "${aderencia:-NA}")"
  tmp="$(mktemp "${csv}.tmp.XXXXXX")" || return 1
  if [ -f "$csv" ] && ! cp -p "$csv" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if ! printf '%s\n' "$header" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if [ -f "$csv" ] && ! LC_ALL=C awk -v feature="$feature" '
      function first_field(line, i, c, nextc, value, comma) {
        if (substr(line, 1, 1) != "\"") {
          comma = index(line, ",")
          if (comma == 0) return line
          return substr(line, 1, comma - 1)
        }
        for (i = 2; i <= length(line); i++) {
          c = substr(line, i, 1)
          if (c == "\"") {
            nextc = substr(line, i + 1, 1)
            if (nextc == "\"") { value = value "\""; i++; continue }
            if (nextc == "," || nextc == "") return value
            invalid = 1
            return ""
          }
          value = value c
        }
        invalid = 1
        return ""
      }
      NR == 1 { next }
      {
        key = first_field($0)
        if (key != feature) print
      }
      END { if (invalid) exit 2 }
    ' "$csv" >>"$tmp"; then
    rm -f "$tmp"
    printf 'SDD METRICAS: CSV invalido; arquivo preservado\n' >&2
    return 1
  fi
  if ! printf '%s\n' "$row" >>"$tmp" || ! mv -f "$tmp" "$csv"; then
    rm -f "$tmp"
    return 1
  fi
}

if [ "$MODE" = "csv" ]; then
  update_csv || { printf 'SDD METRICAS: falha ao atualizar sdd/metricas.csv\n' >&2; exit 1; }
  printf 'SDD METRICAS: incremento atualizado em sdd/metricas.csv\n'
  exit 0
fi

update_closure_report() {
  local report="$root/sdd/incrementos/$feature/relatorio-fechamento.md"
  local start_marker='<!-- SDD-METRICAS:INICIO -->'
  local end_marker='<!-- SDD-METRICAS:FIM -->'
  local section tmp
  [ -f "$report" ] && [ ! -L "$report" ] || {
    printf 'SDD METRICAS: relatorio de fechamento ausente: %s\n' "${report#"$root"/}" >&2
    return 1
  }
  section="$(mktemp "${report}.section.XXXXXX")" || return 1
  tmp="$(mktemp "${report}.tmp.XXXXXX")" || { rm -f "$section"; return 1; }
  if ! cp -p "$report" "$tmp"; then
    rm -f "$section" "$tmp"
    return 1
  fi
  if ! {
    printf '%s\n' "$start_marker"
    render_report
    printf '%s\n' "$end_marker"
  } >"$section"; then
    rm -f "$section" "$tmp"
    return 1
  fi
  if ! LC_ALL=C awk -v start="$start_marker" -v finish="$end_marker" -v section="$section" '
      BEGIN {
        while ((getline line < section) > 0) replacement[++replacement_count] = line
        close(section)
      }
      function print_replacement(i) { for (i = 1; i <= replacement_count; i++) print replacement[i] }
      {
        last = $0
        if ($0 == start) {
          starts++
          if (inside || starts > 1) invalid = 1
          if (!invalid) print_replacement()
          inside = 1
          next
        }
        if ($0 == finish) {
          finishes++
          if (!inside || finishes > 1) invalid = 1
          inside = 0
          next
        }
        if (!inside) print
      }
      END {
        if (inside || starts != finishes || starts > 1) invalid = 1
        if (invalid) exit 2
        if (starts == 0) {
          if (NR > 0 && last != "") print ""
          print_replacement()
        }
      }
    ' "$report" >"$tmp"; then
    rm -f "$section" "$tmp"
    printf 'SDD METRICAS: marcadores invalidos; relatorio preservado\n' >&2
    return 1
  fi
  rm -f "$section"
  if ! mv -f "$tmp" "$report"; then
    rm -f "$tmp"
    return 1
  fi
}

if [ "$MODE" = "relatorio" ]; then
  update_closure_report || exit 1
  printf 'SDD METRICAS: secao atualizada em sdd/incrementos/%s/relatorio-fechamento.md\n' "$feature"
  exit 0
fi

render_report
