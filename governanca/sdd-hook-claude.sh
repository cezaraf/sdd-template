#!/bin/sh
# Bootstrap POSIX: /bin/sh não carrega BASH_ENV em modo não interativo. Só
# depois de limpar todo o ambiente iniciamos um Bash absoluto do trust root.
# O marcador é posicional porque uma variável herdada seria forjável.
IFS="$(printf ' \t\nx')"; IFS="${IFS%x}"
if [ "${1:-}" != "__sdd_hook_clean_bootstrap_v1__" ]; then
  sdd_hook_env=/usr/bin/env
  [ -x "$sdd_hook_env" ] || {
    printf 'SDD HOOK (bloqueado): /usr/bin/env confiavel e obrigatorio\n' >&2
    exit 2
  }
  sdd_hook_bash=""
  for sdd_hook_candidate in /usr/bin/bash /bin/bash; do
    [ -x "$sdd_hook_candidate" ] || continue
    if "$sdd_hook_env" -i PATH=/usr/bin:/bin HOME=/tmp TMPDIR=/tmp \
      "$sdd_hook_candidate" --noprofile --norc -c \
      '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) ))' \
      >/dev/null 2>&1; then
      sdd_hook_bash="$sdd_hook_candidate"
      break
    fi
  done
  [ -n "$sdd_hook_bash" ] || {
    printf 'SDD HOOK (bloqueado): Bash >= 4.4 confiavel e obrigatorio\n' >&2
    exit 2
  }
  exec "$sdd_hook_env" -i PATH=/usr/bin:/bin HOME=/tmp TMPDIR=/tmp LANG=C.UTF-8 \
    SDD_FEATURE="${SDD_FEATURE:-}" SDD_AUTH_TARGET="${SDD_AUTH_TARGET:-}" \
    SDD_POLICIES_FILE="${SDD_POLICIES_FILE:-}" \
    SDD_TRUSTED_POLICIES="${SDD_TRUSTED_POLICIES:-}" \
    "$sdd_hook_bash" --noprofile --norc "$0" __sdd_hook_clean_bootstrap_v1__ "$@"
fi
shift
# Hook PreToolUse do Claude Code. Toda ambiguidade de parsing, guard ou escrita
# potencialmente mutante e tratada como bloqueio (exit 2).
set -euo pipefail

block() {
  printf 'SDD HOOK (bloqueado): %s\n' "$*" >&2
  exit 2
}

if [ "${BASH_VERSINFO[0]}" -lt 4 ] \
   || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
  block "Bash >= 4.4 e obrigatorio"
fi

input="$(cat)" || block "nao foi possivel ler o JSON do hook"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
root="$(cd "$root" && pwd -P)"
guard="$root/sdd/governanca/sdd-guard.sh"
[ -x "$guard" ] || guard="$root/governanca/sdd-guard.sh"
[ -x "$guard" ] || block "sdd-guard.sh ausente ou nao executavel"
command -v python3 >/dev/null 2>&1 || block "python3 e obrigatorio para parsing JSON fail-closed"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/sdd-hook.XXXXXX")" \
  || block "nao foi possivel criar area temporaria"
trap 'rm -rf "$tmpdir"' EXIT
meta="$tmpdir/meta"

if ! printf '%s' "$input" | python3 -I -c '
import json
import os
import sys

tmpdir = sys.argv[1]

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result

def reject_constant(value):
    raise ValueError(f"invalid JSON constant: {value}")

try:
    data = json.load(
        sys.stdin,
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )
    if not isinstance(data, dict):
        raise ValueError("hook payload must be an object")
    tool = data.get("tool_name")
    tool_input = data.get("tool_input")
    if not isinstance(tool, str) or not tool:
        raise ValueError("tool_name must be a non-empty string")
    if not isinstance(tool_input, dict):
        raise ValueError("tool_input must be an object")

    paths = []
    for key in ("file_path", "notebook_path"):
        if key in tool_input:
            value = tool_input[key]
            if not isinstance(value, str):
                raise ValueError(f"{key} must be a string")
            if value:
                paths.append(value)
    if len(set(paths)) > 1:
        raise ValueError("conflicting file_path and notebook_path")
    path = paths[0] if paths else ""

    command = tool_input.get("command", "")
    if not isinstance(command, str):
        raise ValueError("command must be a string")

    contents = []
    content_keys = {"content", "new_string", "new_source", "source"}

    def collect(value, parent_key=""):
        if isinstance(value, dict):
            for key, child in value.items():
                if key in content_keys:
                    if isinstance(child, str):
                        contents.append(child)
                    elif isinstance(child, list) and all(isinstance(item, str) for item in child):
                        contents.extend(child)
                    else:
                        raise ValueError(f"{key} must be a string or list of strings")
                elif key in {"cells", "edits", "notebook"}:
                    collect(child, key)
        elif isinstance(value, list):
            for child in value:
                collect(child, parent_key)
        elif parent_key:
            raise ValueError(f"{parent_key} contains an invalid value")

    collect(tool_input)
    if tool == "Write" and "content" not in tool_input:
        raise ValueError("Write without content")
    edit_plan = []
    if tool == "Edit":
        old_string = tool_input.get("old_string")
        new_string = tool_input.get("new_string")
        replace_all = tool_input.get("replace_all", False)
        if not isinstance(old_string, str) or not isinstance(new_string, str):
            raise ValueError("Edit requires old_string/new_string strings")
        if not isinstance(replace_all, bool):
            raise ValueError("Edit replace_all must be boolean")
        edit_plan.append({"old_string": old_string, "new_string": new_string, "replace_all": replace_all})
    if tool == "MultiEdit":
        edits = tool_input.get("edits")
        if not isinstance(edits, list) or not edits:
            raise ValueError("MultiEdit requires non-empty edits")
        for index, edit in enumerate(edits):
            if not isinstance(edit, dict):
                raise ValueError(f"MultiEdit edits[{index}] must be an object")
            old_string = edit.get("old_string")
            new_string = edit.get("new_string")
            replace_all = edit.get("replace_all", False)
            if not isinstance(old_string, str) or not isinstance(new_string, str):
                raise ValueError(f"MultiEdit edits[{index}] requires old_string/new_string")
            if not isinstance(replace_all, bool):
                raise ValueError(f"MultiEdit edits[{index}].replace_all must be boolean")
            edit_plan.append({"old_string": old_string, "new_string": new_string, "replace_all": replace_all})
    if tool == "NotebookEdit" and not contents:
        raise ValueError("NotebookEdit without written source")
    if tool in {"Write", "Edit", "MultiEdit", "NotebookEdit"} and not path:
        raise ValueError(f"{tool} without target path")
    if tool == "Bash" and not command:
        raise ValueError("Bash without command")

    for index, content in enumerate(contents):
        content_path = os.path.join(tmpdir, f"content-{index:04d}")
        with open(content_path, "wb") as handle:
            handle.write(content.encode("utf-8"))

    if edit_plan:
        with open(os.path.join(tmpdir, "edit-plan.json"), "w", encoding="utf-8") as handle:
            json.dump(edit_plan, handle, ensure_ascii=False)

    fields = (tool, path, command, str(len(contents)))
    for field in fields:
        sys.stdout.buffer.write(field.encode("utf-8") + b"\0")
except (ValueError, TypeError, json.JSONDecodeError, UnicodeError, OSError) as error:
    print(f"invalid hook JSON: {error}", file=sys.stderr)
    raise SystemExit(2)
' "$tmpdir" >"$meta"; then
  block "JSON invalido, duplicado ou com tipos inesperados"
fi

fields=()
mapfile -d '' -t fields <"$meta" || block "falha ao ler JSON normalizado"
[ "${#fields[@]}" -eq 4 ] || block "JSON normalizado incompleto"
tool="${fields[0]}"
file_path="${fields[1]}"
command="${fields[2]}"
content_count="${fields[3]}"
[[ "$content_count" =~ ^[0-9]+$ ]] || block "contador de conteudo invalido"

guard_or_block() {
  local output rc=0
  output="$("$guard" "$@" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$output" >&2
    block "sdd-guard.sh falhou; a operacao nao sera liberada"
  fi
}

case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit)
    guard_or_block protect "$file_path"
    if [ "$content_count" -gt 0 ]; then
      content_files=()
      for ((index = 0; index < content_count; index++)); do
        content_files+=("$tmpdir/content-$(printf '%04d' "$index")")
      done
      guard_or_block scan-content "$file_path" "${content_files[@]}"
    fi
    if [ "$tool" = Edit ] || [ "$tool" = MultiEdit ]; then
      case "$file_path" in
        /*) actual_path="$file_path" ;;
        *) actual_path="$root/${file_path#./}" ;;
      esac
      [ -f "$actual_path" ] && [ ! -L "$actual_path" ] \
        || block "$tool exige arquivo regular existente para calcular conteúdo final"
      if ! python3 -I - "$actual_path" "$tmpdir/edit-plan.json" "$tmpdir/final-content" <<'PY'
import json
import pathlib
import sys

source, plan_path, output = map(pathlib.Path, sys.argv[1:])
try:
    text = source.read_text(encoding="utf-8")
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    for edit in plan:
        old = edit["old_string"]
        new = edit["new_string"]
        occurrences = text.count(old)
        if old == "" or occurrences == 0:
            raise ValueError("old_string ausente ou vazio")
        if not edit["replace_all"] and occurrences != 1:
            raise ValueError("old_string deve ser único quando replace_all=false")
        text = text.replace(old, new, -1 if edit["replace_all"] else 1)
    output.write_text(text, encoding="utf-8")
except (OSError, UnicodeError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
    print(f"não foi possível materializar edição: {error}", file=sys.stderr)
    raise SystemExit(2)
PY
      then
        block "não foi possível provar o conteúdo final da edição"
      fi
      guard_or_block scan-content "$file_path" "$tmpdir/final-content"
    fi
    ;;
  Bash) ;;
  Read|Glob|Grep|WebFetch|Task) ;;
  *)
    # Ferramenta nova que carrega caminho/conteudo e potencialmente mutante nao
    # e presumida segura. Ferramentas sem esses campos permanecem consultivas.
    if [ -n "$file_path" ] || [ "$content_count" -gt 0 ]; then
      block "ferramenta mutante desconhecida: $tool"
    fi
    ;;
esac

resolve_authority_feature() {
  local candidate branch path rest
  local -A candidates=()
  if [ -n "${SDD_FEATURE:-}" ]; then
    [[ "$SDD_FEATURE" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
      || block "SDD_FEATURE invalida"
    printf '%s' "$SDD_FEATURE"
    return
  fi

  branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
  if [[ "$branch" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
      && { [ -d "$root/sdd/incrementos/$branch" ] || [ -d "$root/.compozy/tasks/$branch" ]; }; then
    candidates["$branch"]=1
  fi

  while IFS= read -r -d '' path; do
    candidate=""
    case "$path" in
      sdd/incrementos/*/*)
        rest="${path#sdd/incrementos/}"
        candidate="${rest%%/*}"
        ;;
      .compozy/tasks/*/*)
        rest="${path#.compozy/tasks/}"
        candidate="${rest%%/*}"
        ;;
    esac
    if [[ "$candidate" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      candidates["$candidate"]=1
    fi
  done < <(
    git -C "$root" diff --name-only -z HEAD -- 2>/dev/null || true
    git -C "$root" diff --cached --name-only -z HEAD -- 2>/dev/null || true
    git -C "$root" ls-files --others --exclude-standard -z 2>/dev/null || true
  )

  if [ "${#candidates[@]}" -ne 1 ]; then
    block "nao foi possivel vincular a acao a uma feature unica; defina SDD_FEATURE"
  fi
  for candidate in "${!candidates[@]}"; do printf '%s' "$candidate"; done
}

if [ "$tool" = Bash ]; then
  analysis="$tmpdir/analysis"
  if ! python3 -I -c '
import os
import re
import shlex
import shutil
import sys

command = sys.argv[1]
project_root = os.path.realpath(sys.argv[2])
records = []
actions = set()

def add(kind, value):
    records.append((kind, value))

# Detecta autoridade mesmo quando o restante do shell e complexo; a operacao
# complexa ainda sera bloqueada depois da verificacao externa.
for match in re.finditer(r"(?:^|[;&|()\s])(?:[A-Za-z0-9_./-]*/)?git\b([^\n;&|]*)", command):
    fragment = match.group(1)
    if re.search(r"(?:^|\s)commit(?:\s|$)", fragment):
        actions.add("commit")
    if re.search(r"(?:^|\s)push(?:\s|$)", fragment):
        actions.add("push")
    if re.search(r"(?:^|\s)merge(?:\s|$)", fragment):
        actions.add("merge")
for match in re.finditer(r"(?:^|[;&|()\s])(?:[A-Za-z0-9_./-]*/)?gh\s+pr\s+(create|merge)\b", command):
    actions.add("pull_request" if match.group(1) == "create" else "merge")

for action in sorted(actions):
    add("A", action)

mutator_words = re.compile(
    r"(?:^|[;&|()\s/])(?:rm|rmdir|unlink|mv|cp|install|mkdir|touch|truncate|tee|dd|ln|"
    r"chmod|chown|chgrp|rsync|patch|sed|perl|python[0-9.]*|node|ruby|php|bash|sh|zsh|"
    r"tar|zip|unzip|find|xargs|kubectl|helm|terraform|tofu|docker|aws|gcloud|az|flyctl|"
    r"vercel|netlify|heroku|railway|npm|pnpm|yarn|pip|pip3|gem|cargo|go|make|just|task)"
    r"(?:\s|$)"
)
authority_words = bool(actions)
has_shell_control = bool(re.search(r"[;&|<>\n()`]", command))
if has_shell_control:
    add("B", "comando composto/redirecionado nao e analisavel com seguranca")
    for kind, value in records:
        sys.stdout.buffer.write(kind.encode() + b"\0" + value.encode() + b"\0")
    raise SystemExit(0)

try:
    words = shlex.split(command, posix=True)
except ValueError as error:
    add("B", f"shell invalido: {error}")
    words = []

def discard_assignments(items):
    while items and "=" in items[0] and not items[0].startswith(("/", "./", "../")):
        name, _, _ = items[0].partition("=")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            break
        # Uma denylist de variáveis nunca é completa: Git, runtimes e loaders
        # ganham novos hooks de configuração. O hook aceita somente o ambiente
        # limpo criado pelo bootstrap e recusa toda atribuição inline.
        add("B", f"alteracao de ambiente no comando nao e permitida: {name}")
        items.pop(0)

discard_assignments(words)
while words and os.path.basename(words[0]) in {"sudo", "command", "env", "nice", "nohup", "timeout"}:
    wrapper = os.path.basename(words.pop(0))
    if wrapper == "sudo":
        add("B", "sudo e mutante e nao pode ser analisado com autoridade local")
        words = []
        break
    if wrapper == "nice":
        while words and words[0].startswith("-"):
            option = words.pop(0)
            if option in {"-n", "--adjustment"}:
                if not words:
                    add("B", "nice sem valor para adjustment")
                    break
                words.pop(0)
            elif option == "--" or re.fullmatch(r"-n?-?[0-9]+", option) or option.startswith("--adjustment="):
                continue
            else:
                add("B", f"opcao de nice nao analisavel com seguranca: {option}")
                words = []
                break
        continue
    if wrapper == "nohup":
        if words and words[0] == "--":
            words.pop(0)
        elif words and words[0].startswith("-"):
            add("B", f"opcao de nohup nao analisavel com seguranca: {words[0]}")
            words = []
        continue
    if wrapper == "timeout":
        while words and words[0].startswith("-"):
            option = words.pop(0)
            if option in {"-k", "--kill-after", "-s", "--signal"}:
                if not words:
                    add("B", f"timeout sem valor para {option}")
                    break
                words.pop(0)
            elif option == "--" or option.startswith(("--kill-after=", "--signal=")):
                continue
            else:
                add("B", f"opcao de timeout nao analisavel com seguranca: {option}")
                words = []
                break
        if words:
            words.pop(0)  # duração
        else:
            add("B", "timeout sem duracao/comando")
        continue
    while words and words[0].startswith("-"):
        # Opcoes longas/curtas com argumento tornam a fronteira do comando
        # ambigua; falhe fechado em vez de adivinhar.
        option = words.pop(0)
        if option in {"-u", "--user", "-C", "--chdir", "-S", "--split-string"}:
            add("B", f"opcao de wrapper nao analisavel com seguranca: {option}")
            words = []
            break
    if not words:
        break
    discard_assignments(words)

if words:
    invoked = words[0]
    executable = "." if invoked == "." else os.path.basename(invoked)
    args = words[1:]
    simple_all = {"rm", "rmdir", "unlink", "touch", "mkdir", "truncate", "tee"}
    simple_last = {"cp", "install"}
    simple_all_with_mode = {"chmod", "chown", "chgrp"}
    unsafe = {"dd", "rsync", "patch", "perl", "python", "python3", "node", "ruby", "php", "bash", "sh", "zsh", "xargs", "source", ".", "eval", "exec"}
    targets = []

    cwd = os.path.realpath(os.getcwd())
    resolved_executable = os.path.realpath(invoked) if "/" in invoked else shutil.which(invoked)
    safe_readonly = {
        "echo", "printf", "true", "false", "test", "[", "pwd", "cd", "read", "type", "umask",
        "ls", "cat", "head", "tail", "wc", "grep", "rg", "cut", "sort", "uniq", "comm",
        "cmp", "diff", "stat", "file", "du", "df", "ps", "dirname", "basename", "realpath",
        "readlink",
    }
    known_analyzable = safe_readonly | simple_all | simple_last | simple_all_with_mode | unsafe | {
        "mv", "ln", "sed", "find", "tar", "zip", "unzip", "git", "gh", "kubectl", "helm",
        "terraform", "tofu", "docker", "aws", "gcloud", "az", "flyctl", "vercel", "netlify",
        "heroku", "railway", "npm", "pnpm", "yarn", "pip", "pip3", "gem", "cargo", "go",
        "make", "just", "task", "sdd-guard.sh", "sdd-fluxo.sh", "sdd-metricas.sh",
    }
    trusted_local = {
            os.path.realpath(os.path.join(project_root, "sdd", "governanca", name))
            for name in {"sdd-guard.sh", "sdd-fluxo.sh", "sdd-metricas.sh"}
        } | {
            os.path.realpath(os.path.join(project_root, "governanca", name))
            for name in {"sdd-guard.sh", "sdd-fluxo.sh", "sdd-metricas.sh"}
        }
    if resolved_executable:
        resolved_executable = os.path.realpath(resolved_executable)
        try:
            inside_worktree = os.path.commonpath((project_root, resolved_executable)) == project_root
        except ValueError:
            inside_worktree = True
        if inside_worktree and resolved_executable not in trusted_local:
            add("B", "executavel local arbitrario nao e analisavel com seguranca")
    elif executable not in known_analyzable:
        add("B", f"executavel nao resolvido nao e analisavel com seguranca: {executable}")

    if executable == "git":
        subcommand = ""
        for arg in args:
            if arg == "--":
                continue
            if arg == "--no-pager":
                continue
            if arg.startswith("-"):
                add("B", f"opcao global do git nao esta na allowlist: {arg}")
                break
            subcommand = arg
            break
        helper_options = {
            "--ext-diff", "--textconv", "--paginate", "--open-files-in-pager",
            "--exec-path", "--upload-pack", "--receive-pack", "--output",
        }
        for arg in args:
            option_name = arg.split("=", 1)[0]
            if option_name in helper_options or option_name == "--config-env" \
                    or arg == "-c" or arg.startswith("-c"):
                add("B", f"opcao git pode executar helper ou escrever fora do gate: {arg}")
        if subcommand in {"commit", "push", "merge"}:
            add("A", subcommand)
        if subcommand in {"checkout", "switch", "restore", "reset", "clean", "apply", "am", "cherry-pick", "rebase", "pull", "merge"}:
            add("B", f"git {subcommand} pode reescrever paths protegidos")
        elif subcommand not in {"", "add", "commit", "push", "status", "diff", "log", "show", "rev-parse", "ls-files", "grep", "blame", "remote", "fetch", "request-pull"}:
            add("B", f"git {subcommand} nao esta na allowlist; aliases nao sao confiaveis")
    elif executable == "gh":
        if "pr" in args:
            position = args.index("pr")
            if position + 1 < len(args) and args[position + 1] in {"create", "merge"}:
                add("A", "pull_request" if args[position + 1] == "create" else "merge")
            else:
                add("B", "gh fora de pr create/merge nao esta na allowlist")
        else:
            add("B", "gh fora de pr create/merge nao esta na allowlist")
    elif executable in simple_all:
        targets = [arg for arg in args if not arg.startswith("-")]
    elif executable == "mv":
        positional = []
        target_directory = ""
        index = 0
        while index < len(args):
            arg = args[index]
            if arg in {"-t", "--target-directory"}:
                if index + 1 >= len(args):
                    add("B", "mv sem valor para target-directory")
                    break
                target_directory = args[index + 1]
                index += 2
                continue
            if arg.startswith("--target-directory="):
                target_directory = arg.split("=", 1)[1]
                index += 1
                continue
            if not arg.startswith("-"):
                positional.append(arg)
            index += 1
        targets = positional + ([target_directory] if target_directory else [])
    elif executable == "ln":
        if any(arg in {"-t", "--target-directory"} or arg.startswith("--target-directory=") for arg in args):
            add("B", "destino alternativo de ln nao e analisavel com seguranca")
        positional = [arg for arg in args if not arg.startswith("-")]
        targets = positional[-1:] if positional else []
    elif executable in simple_last:
        if any(arg == "-t" or arg.startswith("--target-directory") for arg in args):
            add("B", f"destino alternativo de {executable} nao e analisavel com seguranca")
        positional = [arg for arg in args if not arg.startswith("-")]
        if positional:
            targets = [positional[-1]]
        else:
            add("B", f"destino de {executable} nao pode ser determinado")
    elif executable in simple_all_with_mode:
        positional = [arg for arg in args if not arg.startswith("-")]
        if any(arg == "--reference" or arg.startswith("--reference=") for arg in args):
            targets = positional
        else:
            targets = positional[1:] if len(positional) > 1 else []
    elif executable == "sed":
        if any(arg == "-i" or arg.startswith("-i") or arg == "--in-place" or arg.startswith("--in-place=") for arg in args):
            add("B", "sed -i nao e analisavel com seguranca")
    elif executable == "find":
        if any(arg in {"-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf", "-fls"} for arg in args):
            add("B", "find mutante nao e analisavel com seguranca")
    elif executable == "tar":
        operations = [arg.lstrip("-") for arg in args if arg and (arg.startswith("-") or re.fullmatch(r"[A-Za-z]+", arg))]
        if not operations or any(set(option) & set("xcArud") for option in operations) \
                or any(arg in {"--create", "--extract", "--append", "--update", "--delete", "--concatenate"} for arg in args):
            add("B", "tar mutante nao e analisavel com seguranca")
    elif executable in {"zip", "unzip"}:
        add("B", f"{executable} mutante nao e analisavel com seguranca")
    elif executable in unsafe:
        add("B", f"{executable} pode escrever paths dinamicamente")
    elif executable in {"npm", "pnpm", "yarn", "pip", "pip3", "gem", "cargo", "go"}:
        if "publish" in args or any(re.search(r"(?:deploy|publish|release|promote|migrate|rollback)", arg, re.I) for arg in args):
            add("A", "production")
        if args not in (["--version"], ["-v"]):
            add("B", f"{executable} pode executar scripts ou mutacoes nao analisaveis com seguranca")
    elif executable == "kubectl":
        production = any(arg in {"apply", "create", "delete", "edit", "patch", "replace", "scale", "set", "taint", "cordon", "uncordon", "drain"} for arg in args)
        if production:
            add("A", "production")
        if "rollout" in args and any(arg in {"restart", "resume", "pause", "undo"} for arg in args):
            add("A", "production")
            production = True
        if not production and not any(arg in {"get", "describe", "logs", "explain", "version", "api-resources", "api-versions", "cluster-info", "diff", "auth", "top"} for arg in args):
            add("B", "subcomando kubectl nao esta na allowlist")
    elif executable == "helm":
        production = any(arg in {"install", "upgrade", "uninstall", "rollback"} for arg in args)
        if production:
            add("A", "production")
        elif not any(arg in {"list", "status", "history", "show", "get", "version", "env", "search"} for arg in args):
            add("B", "subcomando helm nao esta na allowlist")
    elif executable in {"terraform", "tofu"}:
        production = any(arg in {"apply", "destroy", "import", "taint", "untaint"} for arg in args)
        if production:
            add("A", "production")
        if "state" in args and any(arg in {"mv", "rm", "push"} for arg in args[args.index("state") + 1:]):
            add("A", "production")
            production = True
        if not production and not any(arg in {"plan", "show", "validate", "version", "output", "graph", "providers"} for arg in args):
            add("B", f"subcomando {executable} nao esta na allowlist")
    elif executable == "docker":
        production = any(arg in {"push", "service", "stack"} for arg in args)
        if production:
            add("A", "production")
        if "compose" in args and any(arg in {"up", "down", "push", "restart"} for arg in args[args.index("compose") + 1:]):
            add("A", "production")
            production = True
        if not production and not any(arg in {"ps", "images", "inspect", "logs", "version", "info", "stats", "top", "history", "diff"} for arg in args):
            add("B", "subcomando docker nao esta na allowlist")
    elif executable in {"make", "just", "task"}:
        if any(re.search(r"(?:deploy|publish|release|promote|migrate|rollback)", arg, re.I) for arg in args):
            add("A", "production")
        add("B", f"{executable} executa receita local nao analisavel com seguranca")
    elif executable in {"aws", "gcloud", "az", "flyctl", "vercel", "netlify", "heroku", "railway"}:
        add("B", f"{executable} exige integração explícita de autoridade; comando genérico bloqueado")
    elif executable in {"sdd-guard.sh", "sdd-fluxo.sh", "sdd-metricas.sh"}:
        if any(".." in arg.split("/") for arg in args):
            add("B", "argumento de governanca contem traversal")
    elif executable in safe_readonly:
        pass
    else:
        add("B", f"executavel fora da allowlist nao e analisavel com seguranca: {executable}")

    for target in targets:
        components = target.split("/")
        if ".." in components:
            add("B", "destino mutante contem ..")
            continue
        if target.startswith("~") or any(marker in target for marker in ("$", "`", "*", "?", "[", "]", "{", "}")):
            add("B", "destino mutante contem expansao shell")
            continue
        add("T", target)

for kind, value in records:
    sys.stdout.buffer.write(kind.encode() + b"\0" + value.encode() + b"\0")
' "$command" "$root" >"$analysis"; then
    block "falha na analise fail-closed do comando Bash"
  fi

  analysis_fields=()
  mapfile -d '' -t analysis_fields <"$analysis" || block "analise Bash corrompida"
  [ $(( ${#analysis_fields[@]} % 2 )) -eq 0 ] || block "analise Bash incompleta"

  declare -A authority_actions=()
  block_reason=""
  targets=()
  for ((index = 0; index < ${#analysis_fields[@]}; index += 2)); do
    kind="${analysis_fields[$index]}"
    value="${analysis_fields[$((index + 1))]}"
    case "$kind" in
      A) authority_actions["$value"]=1 ;;
      B) [ -n "$block_reason" ] || block_reason="$value" ;;
      T) targets+=("$value") ;;
      *) block "tipo desconhecido na analise Bash" ;;
    esac
  done

  [ -z "$block_reason" ] || block "$block_reason"

  if [ "${#authority_actions[@]}" -gt 0 ]; then
    authority_feature="$(resolve_authority_feature)"
    authority_target="${SDD_AUTH_TARGET:-$(git -C "$root" branch --show-current 2>/dev/null || true)}"
    [ -n "$authority_target" ] || authority_target=HEAD
    for action in "${!authority_actions[@]}"; do
      case "$action" in
        merge) guard_or_block pre-merge "$authority_feature" ;;
        production) guard_or_block pre-production "$authority_feature" ;;
        *) guard_or_block authority-check "$authority_feature" "$action" "$authority_target" ;;
      esac
    done
  fi

  for target in "${targets[@]}"; do
    guard_or_block protect "$target"
  done
fi

exit 0
