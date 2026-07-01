#!/usr/bin/env bash
#
# Instalador do SDD Template (https://github.com/cezaraf/sdd-template)
#
# Instala o fluxo SDD como skills/commands em Claude Code, Codex e OpenCode,
# em escopo global ou por projeto, e opcionalmente instala o CLI do Compozy.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/cezaraf/sdd-template/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --global
#
set -euo pipefail

REPO="${SDD_REPO:-cezaraf/sdd-template}"
REF="main"
SCOPE=""            # global | project
PROJECT_DIR=""
TOOLS="claude,codex,opencode"
INSTALL_COMPOZY=1
UNINSTALL=0
DRY_RUN=0

PROMPTS="00-iniciar-incremento-sdd 01-criar-prd 02-criar-techspec 03-criar-tasks \
04-auditar-especificacao 05-instalar-rules-skills 06-executar-task \
07-revisar-implementacao 08-executar-qa 09-corrigir-bugs 10-consolidar-contrato-vivo"

MARKER_BEGIN="<!-- sdd-template:begin -->"
MARKER_END="<!-- sdd-template:end -->"

# ---------------------------------------------------------------- utilitários

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m ok \033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mavis\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31merro\033[0m %s\n' "$*" >&2; exit 1; }

run() { # executa ou apenas mostra, conforme --dry-run
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

note_done() { # mensagem de sucesso ciente do dry-run
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m faria: %s\n' "$*"
  else
    ok "$*"
  fi
}

write_file() { # write_file <caminho>  (conteúdo via stdin)
  local path="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m escreveria %s\n' "$path"
    cat >/dev/null
  else
    mkdir -p "$(dirname "$path")"
    cat >"$path"
  fi
}

usage() {
  cat <<'EOF'
Instalador do SDD Template — fluxo SDD como skills/commands em
Claude Code, Codex e OpenCode, com instalação opcional do Compozy.

Uso:
  curl -fsSL https://raw.githubusercontent.com/cezaraf/sdd-template/main/install.sh | bash
  curl -fsSL .../install.sh | bash -s -- [flags]

Flags:
  --global                escopo global (home do usuário)
  --project [dir]         escopo por projeto (default: raiz git do diretório atual)
  --tools LISTA           claude,codex,opencode (default: os três)
  --skip-compozy          não instala o CLI do Compozy
  --ref REF               branch ou tag do template (default: main)
  --uninstall             remove skills/commands gerados no escopo escolhido
  --dry-run               mostra o que seria feito, sem escrever
  -h | --help             esta ajuda

Env: SDD_REPO=usuario/fork sobrepõe o repositório de origem.
EOF
  exit 0
}

step_desc() { # descrição curta de cada etapa (pt-BR, uma linha, sem aspas duplas)
  case "$1" in
    00-iniciar-incremento-sdd)   echo "SDD 00 — Iniciar incremento: triagem, trilha de rigor, brief e incremento.yaml" ;;
    01-criar-prd)                echo "SDD 01 — Criar PRD do incremento a partir do brief" ;;
    02-criar-techspec)           echo "SDD 02 — Criar TechSpec (trilhas medium/large)" ;;
    03-criar-tasks)              echo "SDD 03 — Quebrar em tasks BDD, cenários Gherkin e impactos contratuais" ;;
    04-auditar-especificacao)    echo "SDD 04 — Auditar a especificação; só PRONTO libera implementação" ;;
    05-instalar-rules-skills)    echo "SDD 05 — Governança local do projeto (AGENTS.md, rules, skills)" ;;
    06-executar-task)            echo "SDD 06 — Executar task com escopo controlado, testes e gates" ;;
    07-revisar-implementacao)    echo "SDD 07 — Revisar implementação: bugs, contratos, severidade P0-P3" ;;
    08-executar-qa)              echo "SDD 08 — QA como consumidor do sistema; relatório e bugs" ;;
    09-corrigir-bugs)            echo "SDD 09 — Corrigir bugs e issues de review na causa raiz" ;;
    10-consolidar-contrato-vivo) echo "SDD 10 — Consolidar incremento e atualizar o contrato vivo" ;;
    *)                           echo "Etapa do fluxo SDD" ;;
  esac
}

strip_agents_block() { # remove o bloco SDD de um AGENTS.md (exige ambos os marcadores)
  local file="$1"
  [ -f "$file" ] || return 0
  if grep -qF "$MARKER_BEGIN" "$file" && grep -qF "$MARKER_END" "$file"; then
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0==b {skip=1; next}
      $0==e {skip=0; next}
      !skip {print}' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
  elif grep -qF "$MARKER_BEGIN" "$file"; then
    warn "AGENTS.md tem marcador de início sem o de fim; bloco SDD não foi tocado"
    return 1
  fi
}

# ------------------------------------------------------------------ argumentos

while [ $# -gt 0 ]; do
  case "$1" in
    --global)        SCOPE="global" ;;
    --project)
      SCOPE="project"
      if [ $# -gt 1 ] && [ "${2#--}" = "$2" ]; then PROJECT_DIR="$2"; shift; fi ;;
    --tools)         [ $# -gt 1 ] || die "--tools exige valor"; TOOLS="$2"; shift ;;
    --skip-compozy)  INSTALL_COMPOZY=0 ;;
    --ref)           [ $# -gt 1 ] || die "--ref exige valor"; REF="$2"; shift ;;
    --uninstall)     UNINSTALL=1 ;;
    --dry-run)       DRY_RUN=1 ;;
    -h|--help)       usage ;;
    *)               die "flag desconhecida: $1 (use --help)" ;;
  esac
  shift
done

# valida --tools item a item (rejeita valores desconhecidos)
[ -n "$TOOLS" ] || die "--tools não pode ser vazio"
for t in $(printf '%s' "$TOOLS" | tr ',' ' '); do
  case "$t" in
    claude|codex|opencode) : ;;
    *) die "ferramenta desconhecida em --tools: $t (válidas: claude, codex, opencode)" ;;
  esac
done

has_tool() { case ",$TOOLS," in *,"$1",*) return 0 ;; *) return 1 ;; esac; }

# escopo default: projeto se estivermos dentro de um repo git, senão global
if [ -z "$SCOPE" ]; then
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    SCOPE="project"
  else
    SCOPE="global"
  fi
  info "Escopo não informado; usando: $SCOPE (force com --global ou --project)"
fi

if [ "$SCOPE" = "project" ]; then
  if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
  PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || die "diretório de projeto inválido"
fi

# ---------------------------------------------------------- caminhos por escopo

if [ "$SCOPE" = "global" ]; then
  CANON_DIR="$HOME/.sdd/prompts"
  CLAUDE_SKILLS="$HOME/.claude/skills"
  CODEX_SKILLS="$HOME/.codex/skills"
  OPENCODE_CMDS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/command"
  CANON_REF="$CANON_DIR"          # caminho absoluto nos adaptadores
else
  CANON_DIR="$PROJECT_DIR/sdd/prompts"
  CLAUDE_SKILLS="$PROJECT_DIR/.claude/skills"
  CODEX_SKILLS="$PROJECT_DIR/.agents/skills"
  OPENCODE_CMDS="$PROJECT_DIR/.opencode/command"
  CANON_REF="sdd/prompts"         # caminho relativo à raiz do repo
fi

# ------------------------------------------------------------------- uninstall

if [ "$UNINSTALL" -eq 1 ]; then
  info "Removendo artefatos SDD (escopo: $SCOPE)"
  for name in $PROMPTS; do
    run rm -rf "$CLAUDE_SKILLS/sdd-$name" "$CODEX_SKILLS/sdd-$name"
    run rm -f  "$OPENCODE_CMDS/sdd-$name.md"
  done
  run rm -rf "$CANON_DIR"
  if [ "$DRY_RUN" -eq 0 ]; then
    # limpeza não destrutiva de diretórios que ficaram vazios
    rmdir "$CLAUDE_SKILLS" "$CODEX_SKILLS" "$OPENCODE_CMDS" 2>/dev/null || true
    if [ "$SCOPE" = "global" ]; then
      rmdir "$HOME/.sdd" 2>/dev/null || true
    else
      rmdir "$PROJECT_DIR/sdd/prompts" "$PROJECT_DIR/sdd" 2>/dev/null || true
      strip_agents_block "$PROJECT_DIR/AGENTS.md" || true
      # remove AGENTS.md se tiver ficado vazio (era só o nosso bloco)
      if [ -f "$PROJECT_DIR/AGENTS.md" ] && ! grep -q '[^[:space:]]' "$PROJECT_DIR/AGENTS.md"; then
        rm -f "$PROJECT_DIR/AGENTS.md"
      fi
    fi
  fi
  ok "Removido. Dados do processo (sdd/contratos, sdd/incrementos, sdd/historico) foram preservados."
  exit 0
fi

# ------------------------------------------------------- obter arquivos-fonte

# Fonte local só quando o script roda de um ARQUIVO dentro de um checkout
# completo do template (nunca quando vem por pipe — evita sequestro via cwd).
SRC_DIR=""
TMP_DIR=""
cleanup() {
  [ -z "${TMP_DIR:-}" ] || rm -rf "$TMP_DIR"
  [ -z "${TMP_BLOCK:-}" ] || rm -f "$TMP_BLOCK"
}
trap cleanup EXIT

src_is_complete() { # todos os prompts + _comum.md presentes?
  local d="$1" name
  [ -f "$d/_comum.md" ] || return 1
  for name in $PROMPTS; do
    [ -f "$d/$name.md" ] || return 1
  done
}

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if src_is_complete "$script_dir"; then
    SRC_DIR="$script_dir"
    info "Usando arquivos locais de $SRC_DIR"
  fi
fi

if [ -z "$SRC_DIR" ]; then
  command -v curl >/dev/null 2>&1 || die "curl é necessário"
  command -v tar  >/dev/null 2>&1 || die "tar é necessário"
  TMP_DIR="$(mktemp -d)"
  info "Baixando template ($REPO@$REF)"
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" -o "$TMP_DIR/sdd.tar.gz" \
    || curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/tags/$REF" -o "$TMP_DIR/sdd.tar.gz" \
    || die "falha ao baixar $REPO@$REF"
  tar -xzf "$TMP_DIR/sdd.tar.gz" -C "$TMP_DIR"
  SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [ -n "$SRC_DIR" ] && src_is_complete "$SRC_DIR" || die "tarball inesperado: prompts do template não encontrados"
fi

# --------------------------------------------------- 1. prompts canônicos

info "Instalando prompts canônicos em $CANON_DIR"
run mkdir -p "$CANON_DIR"
for name in $PROMPTS; do
  run cp "$SRC_DIR/$name.md" "$CANON_DIR/$name.md"
done
run cp "$SRC_DIR/_comum.md" "$CANON_DIR/_comum.md"
if [ -f "$SRC_DIR/docs/guia-para-leigos.md" ]; then
  run mkdir -p "$CANON_DIR/docs"
  run cp "$SRC_DIR/docs/guia-para-leigos.md" "$CANON_DIR/docs/guia-para-leigos.md"
fi
note_done "prompts canônicos (00–10 + _comum.md)"

# --------------------------------------------------- 2. adaptadores por ferramenta

adapter_body() { # adapter_body <arquivo.md>  — corpo comum dos adaptadores
  local file="$1"
  cat <<EOF
Execute uma etapa do fluxo SDD (Spec-Driven Development).

1. Leia as regras compartilhadas em \`$CANON_REF/_comum.md\`.
2. Leia o prompt canônico em \`$CANON_REF/$file\` e siga-o à risca.
3. Considere os argumentos do usuário abaixo (slug do incremento, contexto,
   caminhos); se nenhum for dado e a etapa exigir, pergunte.

Argumentos do usuário: \$ARGUMENTS
EOF
}

install_claude() {
  info "Claude Code: skills em $CLAUDE_SKILLS"
  local name desc
  for name in $PROMPTS; do
    desc="$(step_desc "$name")"
    write_file "$CLAUDE_SKILLS/sdd-$name/SKILL.md" <<EOF
---
description: "$desc"
argument-hint: "[feature] [contexto]"
disable-model-invocation: true
---

$(adapter_body "$name.md")
EOF
  done
  note_done "claude: 11 skills (invoque com /sdd-00-... até /sdd-10-...)"
}

install_codex() {
  info "Codex: skills em $CODEX_SKILLS"
  local name desc
  for name in $PROMPTS; do
    desc="$(step_desc "$name")"
    write_file "$CODEX_SKILLS/sdd-$name/SKILL.md" <<EOF
---
name: sdd-$name
description: "$desc. Use somente quando o usuário invocar explicitamente esta etapa do fluxo SDD."
---

$(adapter_body "$name.md")
EOF
  done
  note_done "codex: 11 skills (invoque com \$sdd-00-... ou menu /skills; reinicie o Codex)"
}

install_opencode() {
  info "OpenCode: commands em $OPENCODE_CMDS"
  local name desc
  for name in $PROMPTS; do
    desc="$(step_desc "$name")"
    write_file "$OPENCODE_CMDS/sdd-$name.md" <<EOF
---
description: "$desc"
---

$(adapter_body "$name.md")
EOF
  done
  note_done "opencode: 11 commands (invoque com /sdd-00-... até /sdd-10-...)"
}

has_tool claude   && install_claude
has_tool codex    && install_codex
has_tool opencode && install_opencode

# --------------------------------------------------- 3. scaffold do projeto

if [ "$SCOPE" = "project" ]; then
  info "Estrutura SDD do projeto em $PROJECT_DIR"
  run mkdir -p "$PROJECT_DIR/sdd/contratos" "$PROJECT_DIR/sdd/incrementos" \
               "$PROJECT_DIR/sdd/historico" "$PROJECT_DIR/.compozy/tasks"
  if [ ! -f "$PROJECT_DIR/.compozy/config.toml" ]; then
    if [ -f "$SRC_DIR/compozy-config.toml.example" ]; then
      run cp "$SRC_DIR/compozy-config.toml.example" "$PROJECT_DIR/.compozy/config.toml"
      note_done ".compozy/config.toml criado a partir do exemplo"
    else
      warn "compozy-config.toml.example ausente na fonte; .compozy/config.toml não foi criado"
    fi
  fi

  # bloco idempotente no AGENTS.md da raiz
  agents_file="$PROJECT_DIR/AGENTS.md"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m atualizaria bloco SDD em %s\n' "$agents_file"
  else
    TMP_BLOCK="$(mktemp)"
    cat >"$TMP_BLOCK" <<EOF
$MARKER_BEGIN
Este projeto usa o fluxo SDD (Spec-Driven Development).

- Regras compartilhadas: \`sdd/prompts/_comum.md\` (leitura obrigatória).
- Etapas do fluxo: \`sdd/prompts/00-*.md\` … \`10-*.md\`, instaladas como
  skills/commands \`sdd-NN-*\` em Claude Code, Codex e OpenCode.
- Verdade do comportamento do sistema: \`sdd/contratos/\` (contratos vivos).
- Não altere \`sdd/contratos/\` fora do fechamento (etapa 10).
$MARKER_END
EOF
    if strip_agents_block "$agents_file"; then
      if [ -f "$agents_file" ] && grep -q '[^[:space:]]' "$agents_file"; then
        { cat "$agents_file"; echo; cat "$TMP_BLOCK"; } >"$agents_file.tmp" && mv "$agents_file.tmp" "$agents_file"
      else
        cat "$TMP_BLOCK" >"$agents_file"
      fi
      ok "AGENTS.md com bloco SDD (idempotente)"
    else
      warn "bloco SDD não foi escrito no AGENTS.md (marcadores corrompidos); corrija manualmente"
    fi
    rm -f "$TMP_BLOCK"; TMP_BLOCK=""
  fi
fi

# --------------------------------------------------- 4. Compozy

install_compozy() {
  if command -v compozy >/dev/null 2>&1; then
    ok "compozy já instalado: $(compozy --version 2>/dev/null | head -n1 || echo 'versão desconhecida')"
    return 0
  fi
  info "Instalando Compozy CLI"
  # fontes corretas (o site oficial lista fontes erradas; NÃO use 'npx compozy'
  # nem o tap 'compozy/tap' — ver github.com/compozy/compozy)
  if command -v brew >/dev/null 2>&1; then
    run brew install compozy/compozy/compozy; return $?
  fi
  if command -v npm >/dev/null 2>&1; then
    run npm install -g @compozy/cli; return $?
  fi
  if command -v go >/dev/null 2>&1; then
    run go install github.com/compozy/compozy/cmd/compozy@latest; return $?
  fi
  # fallback: binário de release com verificação de checksum
  local os arch ver base asset bindir dl bin
  case "$(uname -s)" in
    Linux)  os=linux ;;
    Darwin) os=darwin ;;
    *) warn "SO não suportado para download de binário; instale manualmente: https://github.com/compozy/compozy"; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) warn "arquitetura não suportada; instale manualmente"; return 1 ;;
  esac
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m[dry-run]\033[0m baixaria a última release de compozy (%s_%s) com verificação de checksum\n' "$os" "$arch"
    return 0
  fi
  ver="$(curl -fsSL https://api.github.com/repos/compozy/compozy/releases/latest \
        | grep -o '"tag_name": *"[^"]*"' | head -n1 | sed 's/.*"\(v[^"]*\)".*/\1/')" || ver=""
  [ -n "$ver" ] || { warn "não foi possível descobrir a versão mais recente do compozy"; return 1; }
  base="https://github.com/compozy/compozy/releases/download/$ver"
  asset="compozy_${ver#v}_${os}_${arch}.tar.gz"
  dl="$(mktemp -d)"
  curl -fsSL "$base/$asset" -o "$dl/$asset" || { warn "falha ao baixar $asset"; rm -rf "$dl"; return 1; }
  if curl -fsSL "$base/checksums.txt" -o "$dl/checksums.txt" 2>/dev/null; then
    if command -v sha256sum >/dev/null 2>&1; then
      ( cd "$dl" && grep " $asset\$" checksums.txt | sha256sum -c - ) \
        || { warn "checksum inválido para $asset — abortando"; rm -rf "$dl"; return 1; }
    elif command -v shasum >/dev/null 2>&1; then
      ( cd "$dl" && grep " $asset\$" checksums.txt | shasum -a 256 -c - ) \
        || { warn "checksum inválido para $asset — abortando"; rm -rf "$dl"; return 1; }
    else
      warn "nenhuma ferramenta de checksum (sha256sum/shasum) disponível — abortando por segurança"
      rm -rf "$dl"; return 1
    fi
  else
    warn "checksums.txt indisponível; prosseguindo sem verificação"
  fi
  tar -xzf "$dl/$asset" -C "$dl" || { warn "falha ao extrair $asset"; rm -rf "$dl"; return 1; }
  bin="$(find "$dl" -maxdepth 2 -type f -name compozy | head -n1)"
  [ -n "$bin" ] || { warn "binário compozy não encontrado no asset"; rm -rf "$dl"; return 1; }
  bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  install -m 0755 "$bin" "$bindir/compozy" || { warn "falha ao instalar em $bindir"; rm -rf "$dl"; return 1; }
  rm -rf "$dl"
  [ -x "$bindir/compozy" ] || { warn "instalação do compozy não confirmada"; return 1; }
  case ":$PATH:" in
    *":$bindir:"*) : ;;
    *) warn "adicione $bindir ao PATH para usar o compozy" ;;
  esac
  ok "compozy instalado em $bindir/compozy"
}

if [ "$INSTALL_COMPOZY" -eq 1 ]; then
  install_compozy || warn "Compozy não foi instalado; o fluxo SDD funciona, mas a execução de tasks depende dele."
  echo
  info "Próximo passo do Compozy (uma vez): compozy setup --all"
  info "  (instala as skills internas do Compozy nos agentes detectados;"
  info "   'compozy tasks run' bloqueia sem isso)"
fi

# --------------------------------------------------- resumo

echo
info "Instalação concluída (escopo: $SCOPE)"
echo "  prompts canônicos : $CANON_DIR"
has_tool claude   && echo "  claude code       : $CLAUDE_SKILLS/sdd-*"
has_tool codex    && echo "  codex             : $CODEX_SKILLS/sdd-* (reinicie o Codex)"
has_tool opencode && echo "  opencode          : $OPENCODE_CMDS/sdd-*.md"
[ "$SCOPE" = "project" ] && echo "  projeto           : sdd/{contratos,incrementos,historico} + .compozy/"
echo
first_hint=""
has_tool claude   && first_hint="/sdd-00-iniciar-incremento-sdd (Claude Code)"
if has_tool opencode; then
  [ -n "$first_hint" ] && first_hint="$first_hint, "
  first_hint="${first_hint}/sdd-00-iniciar-incremento-sdd (OpenCode)"
fi
if has_tool codex; then
  [ -n "$first_hint" ] && first_hint="$first_hint, "
  first_hint="${first_hint}\$sdd-00-iniciar-incremento-sdd (Codex)"
fi
echo "Comece com: $first_hint"
echo "Novo no SDD? Leia $CANON_DIR/docs/guia-para-leigos.md"
