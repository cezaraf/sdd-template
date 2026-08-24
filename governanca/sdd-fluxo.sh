#!/usr/bin/env bash
# Driver determinístico do loop SDD.
#
# Dado um incremento, indica a próxima etapa autorizada pela máquina de
# estados. Com --run, executa SOMENTE transições determinísticas de status
# (proposto→especificado e em_execucao→validado), sempre após evidência
# verificável. Nunca concede gate humano, nunca commita, nunca implanta.
#
# Uso:
#   sdd-fluxo.sh <feature>            # consulta o próximo passo
#   sdd-fluxo.sh <feature> --run      # aplica transições determinísticas
#   sdd-fluxo.sh <feature> --json     # saída machine-readable
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
root="$(cd "$root" && pwd -P)"
RUN=0 JSON=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --run) RUN=1 ;;
    --json) JSON=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done
[ "${#ARGS[@]}" -ge 1 ] || { printf 'Uso: sdd-fluxo.sh <feature> [--run] [--json]\n' >&2; exit 2; }
feature="${ARGS[0]}"
[[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  printf 'SDD FLUXO: feature inválida: %s\n' "$feature" >&2
  exit 2
}

if [ "${SDD_PREFIX+x}" != x ]; then
  prefix_config="$root/sdd/governanca/sdd-template.env"
  if [ -f "$prefix_config" ]; then
    persisted_prefix="$(awk -F= '
      /^SDD_PREFIX=/ { count++; value=substr($0, index($0, "=") + 1); next }
      /^[[:space:]]*$/ { next }
      { invalid=1 }
      END { if (invalid || count != 1) exit 1; print value }
    ' "$prefix_config")" || {
      printf 'SDD FLUXO: configuração persistida de prefixo inválida\n' >&2
      exit 2
    }
    SDD_PREFIX="$persisted_prefix"
  fi
fi
command_prefix="${SDD_PREFIX:-cz}"
[[ "$command_prefix" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
  printf 'SDD FLUXO: SDD_PREFIX deve ser um slug seguro: %s\n' "$command_prefix" >&2
  exit 2
}

yaml="$root/sdd/incrementos/$feature/incremento.yaml"
wf="$root/.compozy/tasks/$feature"
audit="$wf/auditoria-especificacao.md"
review="$wf/reviews-001/review-report.md"
guard="$root/sdd/governanca/sdd-guard.sh"
metrics="$root/sdd/governanca/sdd-metricas.sh"
[ -x "$guard" ] || guard="$root/governanca/sdd-guard.sh"
[ -x "$metrics" ] || metrics="$root/governanca/sdd-metricas.sh"
[ -x "$guard" ] || { printf 'SDD FLUXO: sdd-guard.sh ausente\n' >&2; exit 1; }
[ -x "$metrics" ] || metrics=""
[ -f "$yaml" ] || { printf 'SDD FLUXO: incremento ausente: %s\n' "$feature" >&2; exit 1; }

fail() { printf 'SDD FLUXO: %s\n' "$*" >&2; exit 1; }

yaml_value() {
  awk -v target="$2" '
    function trim(v) { sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    function clean(v) {
      sub(/[[:space:]]+#.*/, "", v); v = trim(v)
      if ((v ~ /^".*"$/) || (v ~ /^\047.*\047$/)) v = substr(v, 2, length(v) - 2)
      return v
    }
    /^[[:space:]]*(#|$)/ { next }
    {
      match($0, /^[ ]*/); indent = RLENGTH
      line = substr($0, indent + 1)
      if (line !~ /^[A-Za-z0-9_-]+:[[:space:]]*/) next
      key = line; sub(/:.*/, "", key)
      value = line; sub(/^[^:]+:[[:space:]]*/, "", value)
      level = int(indent / 2) + 1
      stack[level] = key
      for (i = level + 1; i <= 20; i++) delete stack[i]
      current = stack[1]
      for (i = 2; i <= level; i++) current = current "." stack[i]
      if (current == target && value != "") { print clean(value); exit }
    }' "$1"
}

set_top() {
  local key="$1" value="$2" tmp
  case "$key" in
    status|fase) ;;
    *) fail "chave top-level não autorizada para alteração: $key" ;;
  esac

  tmp="$(mktemp "${yaml}.tmp.XXXXXX")" || fail "não foi possível criar arquivo temporário"
  if ! cp -p "$yaml" "$tmp"; then
    rm -f "$tmp"
    fail "não foi possível preparar atualização de $key"
  fi
  if ! awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    {
      if ($0 == key ":" || $0 ~ ("^" key ":[[:space:]]")) {
        found++
        print key ": " value
        next
      }
      print
    }
    END { if (found != 1) exit 1 }
  ' "$yaml" >"$tmp"; then
    rm -f "$tmp"
    fail "incremento deve conter exatamente uma chave top-level '$key'"
  fi
  if ! mv -f "$tmp" "$yaml"; then
    rm -f "$tmp"
    fail "não foi possível aplicar atualização atômica de $key"
  fi
}

top_key_count() {
  awk -v key="$1" '
    $0 == key ":" || $0 ~ ("^" key ":[[:space:]]") { count++ }
    END { print count + 0 }
  ' "$yaml"
}

has_exact_status() {
  [ -f "$1" ] && grep -Eq "^[[:space:]-]*Status:[[:space:]]*$2[[:space:]]*$" "$1"
}

audit_pronto() { has_exact_status "$audit" PRONTO; }

qa_report_approved() {
  awk '
    /^[[:space:]-]*Status:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]-]*Status:[[:space:]]*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      found = 1
      if (value != "APROVADO") invalid = 1
    }
    END { exit(found && !invalid ? 0 : 1) }
  ' "$1"
}

issue_value() {
  awk -v wanted="$2" '
    {
      line = $0
      sub(/^[[:space:]-]*/, "", line)
      if (line !~ /^[A-Za-z]+:[[:space:]]*/) next
      key = line
      sub(/:.*/, "", key)
      normalized = tolower(key)
      if (wanted == "severity" && normalized != "severity" && normalized != "severidade") next
      if (wanted == "status" && normalized != "status") next
      sub(/^[^:]+:[[:space:]]*/, "", line)
      sub(/[[:space:]]+#.*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if ((line ~ /^".*"$/) || (line ~ /^\047.*\047$/)) line = substr(line, 2, length(line) - 2)
      print line
      exit
    }
  ' "$1"
}

open_blockers() {
  local f sev st
  for f in "$wf"/reviews-001/issue_*.md; do
    [ -f "$f" ] || continue
    sev="$(issue_value "$f" severity | tr '[:lower:]' '[:upper:]')"
    st="$(issue_value "$f" status)"
    case "$sev" in
      P0|P1)
        case "$(printf '%s' "$st" | tr '[:upper:]' '[:lower:]')" in
          fixed|closed|corrigid[oa]|resolvid[oa]|done|concluid[oa]) : ;;
          *) return 0 ;;
        esac
        ;;
    esac
  done
  [ -f "$wf/bugs.md" ] || return 1
  awk '
    function flush() {
      if (inbug && sev ~ /^p[01]$/ && st !~ /^(fixed|closed|corrigido|corrigida|resolvido|resolvida|done|concluido|concluida)$/) ok=1
    }
    /^##[[:space:]]+BUG-[0-9]+/ { flush(); inbug=1; sev=""; st=""; next }
    inbug && /^[[:space:]-]*[Ss]everidade:/ { v=$0; sub(/^[^:]+:[[:space:]]*/, "", v); gsub(/[[:space:]\047\042]/, "", v); sev=tolower(v) }
    inbug && /^[[:space:]-]*[Ss]tatus:/ { v=$0; sub(/^[^:]+:[[:space:]]*/, "", v); gsub(/[[:space:]\047\042]/, "", v); st=tolower(v) }
    END { flush(); exit(ok ? 0 : 1) }
  ' "$wf/bugs.md"
}

load_state() {
  local count
  count="$(top_key_count status)"
  [ "$count" = "1" ] || fail "status top-level ausente ou duplicado"
  count="$(top_key_count fase)"
  [ "$count" = "1" ] || fail "fase top-level ausente ou duplicada"

  status_value="$(yaml_value "$yaml" 'status')"
  fase_value="$(yaml_value "$yaml" 'fase')"
  alvo="$(yaml_value "$yaml" 'classificacao.alvo_contrato')"
  pr_merge_rota="$(yaml_value "$yaml" 'rota.pr_merge')"

  case "$status_value" in
    proposto|especificado|em_execucao|validado|consolidado|bloqueado) ;;
    *) fail "status inválido ou ausente: ${status_value:-vazio}" ;;
  esac
  case "$fase_value" in
    triagem|especificacao|planejamento|auditoria|implementacao|review|qa|validacao|pr|merge|deploy|verificacao|fechamento) ;;
    *) fail "fase inválida ou ausente: ${fase_value:-vazio}" ;;
  esac
}

all_qa_approved() {
  local found=0 q
  shopt -s nullglob
  local reports=("$wf"/qa/*-qa-report.md)
  shopt -u nullglob
  for q in "${reports[@]}"; do
    found=1
    qa_report_approved "$q" || return 1
    grep -Fq 'NAO_VERIFICADO' "$q" && return 1
  done
  [ "$found" -eq 1 ]
}

first_runnable_task() {
  local candidate task_id task_status
  shopt -s nullglob
  for candidate in "$wf"/task_[0-9][0-9].md; do
    task_id="${candidate##*/}"
    task_id="${task_id%.md}"
    task_status="$(yaml_value "$candidate" status)"
    case "$task_status" in pending|in_progress) ;; *) continue ;; esac
    if "$guard" pre-implement "$feature" "$task_id" >/dev/null 2>&1; then
      shopt -u nullglob
      printf '%s' "$task_id"
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

load_state
merged_evidence="nao"
has_exact_status "$wf/pr/merge-report.md" MERGED && merged_evidence="sim"
deploy_verified="nao"
has_exact_status "$wf/ops/deploy-report.md" VERIFICADO && deploy_verified="sim"

next="" command="" detail=""
apply_transition=""
transition_verified=0

case "$status_value" in
  bloqueado)
    next="desbloquear incremento"
    detail="motivo=$(yaml_value "$yaml" 'bloqueio.motivo'); como=$(yaml_value "$yaml" 'bloqueio.como_desbloquear')"
    ;;

  consolidado)
    next="promover aprendizados"
    command="/${command_prefix}-promover-aprendizados $feature"
    ;;

  proposto)
    if audit_pronto; then
      if "$guard" pre-specify "$feature" >/dev/null 2>&1; then
        transition_verified=1
        apply_transition="especificado"
        next="especificação validada — avançar para implementação"
        command="/${command_prefix}-executar-task $feature task_01"
        detail="transição determinística proposta: proposto → especificado"
      else
        next="resolver pré-condições da especificação"
        command="sdd/governanca/sdd-guard.sh pre-specify $feature"
        detail="auditoria existe, mas artefatos ou autoridade ainda não sustentam a transição"
      fi
    elif [ ! -f "$wf/_prd.md" ]; then
      next="criar PRD"
      command="/${command_prefix}-criar-prd $feature"
    elif [ ! -f "$wf/task_01.md" ]; then
      next="criar plano persistido e tasks BDD"
      command="/${command_prefix}-criar-tasks $feature"
    else
      next="auditar especificação"
      command="/${command_prefix}-auditar-especificacao $feature"
    fi
    ;;

  especificado)
    task_id="$(first_runnable_task || true)"
    if [ -n "$task_id" ]; then
      next="executar tasks"
      command="/${command_prefix}-executar-task $feature $task_id"
    else
      next="resolver pré-condições de implementação"
      command="sdd/governanca/sdd-guard.sh pre-implement $feature task_NN"
      detail="gate ou dependências bloqueiam todas as tasks pendentes"
    fi
    ;;

  em_execucao)
    pending=""
    task_found=0
    shopt -s nullglob
    for t in "$wf"/task_[0-9][0-9].md; do
      task_found=1
      st="$(yaml_value "$t" 'status')"
      [ "$st" = "completed" ] || pending="${pending}${pending:+ }${t##*/}"
    done
    shopt -u nullglob
    if ! rr_req="$("$guard" review-required "$feature" 2>/dev/null)"; then rr_req="sim"; fi
    case "$rr_req" in sim|nao) ;; *) rr_req="sim" ;; esac
    rr_ok="nao"
    has_exact_status "$review" APROVADO && rr_ok="sim"
    qa_ok="nao"
    all_qa_approved && qa_ok="sim"

    if [ "$task_found" -eq 0 ]; then
      next="criar tasks antes de validar"
      command="/${command_prefix}-criar-tasks $feature"
    elif [ -n "$pending" ]; then
      task_id="$(first_runnable_task || true)"
      if [ -n "$task_id" ]; then
        next="concluir tasks pendentes (${pending})"
        command="/${command_prefix}-executar-task $feature $task_id"
      else
        next="resolver dependências ou gates das tasks pendentes (${pending})"
        command="sdd/governanca/sdd-guard.sh pre-implement $feature task_NN"
        detail="nenhuma task pendente está executável no grafo atual"
      fi
    elif [ "$rr_req" = "sim" ] && [ "$rr_ok" != "sim" ]; then
      next="review independente obrigatório"
      command="/${command_prefix}-revisar-implementacao $feature"
    elif [ "$qa_ok" != "sim" ]; then
      next="QA como consumidor"
      command="/${command_prefix}-executar-qa $feature"
    elif open_blockers; then
      next="corrigir P0/P1 abertos antes de validar"
      command="/${command_prefix}-corrigir-bugs $feature"
    else
      if ! "$guard" pre-validate "$feature" >/dev/null 2>&1; then
        next="resolver gate determinístico antes de validar"
        command="sdd/governanca/sdd-guard.sh pre-validate $feature"
        detail="tasks e relatórios parecem completos, mas o guard ainda bloqueia a transição"
      else
        transition_verified=1
        case "$pr_merge_rota" in
          obrigatoria)
            apply_transition="validado"
            next="entrega validada — preparar PR"
            command="/${command_prefix}-preparar-pr $feature"
            detail="transição determinística proposta: em_execucao → validado"
            ;;
          dispensada)
            apply_transition="validado"
            next="entrega validada — consolidar contrato vivo (alvo ${alvo:-local})"
            command="/${command_prefix}-consolidar-contrato-vivo $feature"
            detail="transição determinística proposta: em_execucao → validado"
            ;;
          *)
            next="corrigir rota de PR antes de validar"
            detail="rota.pr_merge inválida ou ausente: ${pr_merge_rota:-vazio}"
            ;;
        esac
      fi
    fi
    ;;

  validado)
    case "$pr_merge_rota" in
      dispensada)
        next="consolidar contrato vivo (alvo ${alvo:-local})"
        command="/${command_prefix}-consolidar-contrato-vivo $feature"
        ;;
      obrigatoria)
        if [ "$merged_evidence" != "sim" ]; then
          next="preparar pacote de PR"
          command="/${command_prefix}-preparar-pr $feature"
        elif [ "$alvo" = "producao" ] && [ "$deploy_verified" != "sim" ]; then
          next="merge confirmado — deploy e verificação pendentes"
          command="/${command_prefix}-deploy-verificar $feature"
        else
          next="consolidar contrato vivo no alvo confirmado"
          command="/${command_prefix}-consolidar-contrato-vivo $feature"
        fi
        ;;
      *)
        next="corrigir rota de PR antes de prosseguir"
        detail="rota.pr_merge inválida ou ausente: ${pr_merge_rota:-vazio}"
        ;;
    esac
    ;;
esac

if [ "$apply_transition" != "" ]; then
  if [ "$RUN" = "1" ]; then
    if [ "$transition_verified" -ne 1 ]; then
      case "$apply_transition" in
        especificado) "$guard" pre-specify "$feature" >/dev/null ;;
        validado) "$guard" pre-validate "$feature" >/dev/null ;;
      esac
    fi
    set_top status "$apply_transition"
    case "$apply_transition" in
      especificado)
        set_top fase auditoria
        [ -z "$metrics" ] || "$metrics" "$feature" --marcar data_especificado >/dev/null 2>&1 || true
        ;;
      validado)
        # `fechamento` é assumida apenas pelo passo 13, depois do atestado de
        # pre-consolidate; o driver mantém o contrato vivo protegido.
        if [ "$pr_merge_rota" = "obrigatoria" ]; then
          set_top fase pr
        else
          set_top fase validacao
        fi
        [ -z "$metrics" ] || "$metrics" "$feature" --marcar data_validado >/dev/null 2>&1 || true
        ;;
    esac
    detail="${detail} — APLICADA"
  else
    detail="${detail} (rode com --run para aplicar)"
  fi
fi

if [ "$RUN" = "1" ]; then
  load_state
fi

json_string() {
  local value="$1" char code i
  local LC_ALL=C
  printf '"'
  for ((i = 0; i < ${#value}; i++)); do
    char="${value:i:1}"
    case "$char" in
      '"') printf '\\"' ;;
      \\) printf '\\\\' ;;
      $'\b') printf '\\b' ;;
      $'\f') printf '\\f' ;;
      $'\n') printf '\\n' ;;
      $'\r') printf '\\r' ;;
      $'\t') printf '\\t' ;;
      *)
        printf -v code '%d' "'$char"
        if [ "$code" -lt 32 ]; then
          printf '\\u%04x' "$code"
        else
          printf '%s' "$char"
        fi
        ;;
    esac
  done
  printf '"'
}

if [ "$JSON" = "1" ]; then
  printf '{"feature":'; json_string "$feature"
  printf ',"status":'; json_string "${status_value:-}"
  printf ',"fase":'; json_string "${fase_value:-}"
  printf ',"alvo":'; json_string "${alvo:-}"
  printf ',"next":'; json_string "$next"
  printf ',"command":'; json_string "$command"
  printf ',"detail":'; json_string "$detail"
  printf '}\n'
else
  printf 'SDD FLUXO: %s\n' "$feature"
  printf '  estado : status=%s fase=%s alvo=%s\n' "${status_value:-?}" "${fase_value:-?}" "${alvo:-?}"
  printf '  próximo: %s\n' "$next"
  [ -n "$command" ] && printf '  comando: %s\n' "$command"
  [ -n "$detail" ] && printf '  detalhe: %s\n' "$detail"
fi
