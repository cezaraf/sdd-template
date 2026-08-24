# 05 — Instalar governança executável

Este passo cria ou atualiza a governança local do projeto. Não é executado a
cada incremento, exceto quando uma entrega revelar lacuna.

> Leia `_comum.md`.

## Modos

- `bootstrap`: deriva governança do repositório.
- `atualizacao`: usa um incremento como evidência para corrigir rules, skills,
  policies, hooks ou evals.

## Entradas

```text
README, scripts, manifests, CI e estrutura do projeto
sdd/contratos/
sdd/governanca/policies.yaml                 (quando existir)
sdd/evals/
AGENTS.md / CLAUDE.md / regras existentes
```

No modo atualização, leia também o incremento completo.

## Saídas possíveis

```text
AGENTS.md
CLAUDE.md
.claude/rules/
.claude/skills/
.claude/settings.json                        (hooks PreToolUse do guard)
.mcp.json
sdd/governanca/policies.yaml
sdd/governanca/sdd-guard.sh                  (gates, protect, scan-secrets)
sdd/governanca/sdd-fluxo.sh                  (driver do loop)
sdd/governanca/sdd-metricas.sh               (indicadores)
sdd/governanca/sdd-watch.sh + watch.yaml     (detector operacional)
sdd/evals/run-evals.sh + sdd/evals/cases/
.github/workflows/sdd-guard.yml              (quando GitHub Actions existir)
.github/workflows/sdd-watch.yml              (quando houver métrica monitorável)
```

O instalador já entrega guard, hook do Claude Code, driver de fluxo, métricas,
runner de evals e exemplos do detector. Este passo adapta o que é específico do
projeto: comandos reais em `policies.yaml`, caminhos protegidos adicionais,
métricas de `watch.yaml` e evals novas.

## Princípio

Use o mecanismo correto:

- **documentação/rule/skill** para orientação contextual;
- **policy/hook/CI** para bloqueio determinístico;
- **eval** para regressão do harness;
- **gate humano** para julgamento e autoridade.

Não tente resolver segurança crítica apenas com prompt.

## Policies mínimas

- caminhos protegidos;
- comandos reais de lint/build/test/E2E;
- regras de transição;
- matriz de gates por risco/autonomia;
- política de segredos;
- política de git/PR/merge/deploy;
- requisito de rollback;
- exceções registráveis.

`authority.check_command` deve ser um executável absoluto fora do worktree,
fixado pelo SHA-256 lowercase em `authority.check_sha256`. Ele recebe
`SDD_AUTH_FEATURE`, `SDD_AUTH_GATE`, `SDD_AUTH_HEAD` e
`SDD_AUTH_TARGET`, consulta a fonte protegida do projeto (por exemplo, review do
PR, environment ou approval service) e retorna `0` somente para decisão válida
e vinculada ao SHA. Texto em `incremento.yaml` não é prova de autoridade.

Preencha `quality_commands` com comandos reais. Se todas as listas ficarem
vazias, `pre-complete`, `pre-validate`, `pre-merge` e `pre-consolidate` exigirão
waiver do checker externo. Isso é fail-closed intencional.

## Verificação obrigatória do enforcement

Antes de encerrar o passo, prove que o enforcement existe de fato:

```bash
sdd/governanca/sdd-guard.sh validate-policy
sdd/evals/run-evals.sh --tier1                       # invariantes do harness
sdd/governanca/sdd-guard.sh protect sdd/contratos/x  # deve bloquear (exit 2)
sdd/governanca/sdd-guard.sh scan-secrets <arquivo>   # deve bloquear segredo
```

Valide também uma decisão negada pelo checker e confirme que termina bloqueada.
No CI, mudanças em contrato usam `protect-ci` e exigem o gate externo
`contract_change`; o token local de consolidação nunca é copiado para o runner.
O workflow deve extrair a policy do commit base para `SDD_TRUSTED_POLICIES`.
Não use a policy do próprio PR como raiz de confiança. O primeiro bootstrap é
uma operação administrativa separada.

Regra crítica sem teste que a exercite é dívida de governança, não controle.

## Evals mínimas

Crie casos que provem que o agente:

1. não classifica segurança como risco baixo nem confunde risco com rigor;
2. exige TechSpec/review quando risco ou alvo demandarem;
3. não implementa sem auditoria `PRONTO`;
4. mantém rastreabilidade completa;
5. não altera contrato vivo antes do passo 13;
6. detecta camada full-stack ausente;
7. usa `NAO_VERIFICADO` quando QA não executa;
8. bloqueia P0/P1;
9. exige regressão em bugfix;
10. respeita autoridade de git/deploy;
11. promove incidentes recorrentes a eval.

## Regras críticas

- Não escreva segredos.
- Não prometa gate inexistente.
- Não sobrescreva governança específica do projeto sem preservar decisões.
- Faça `policies.yaml` refletir comandos reais.
- Hooks devem falhar de forma legível e indicar como desbloquear.
- Evals precisam de entrada, expectativa e evidência de aprovação.

## Checklist

- Orientação e enforcement estão separados.
- Caminhos protegidos realmente são verificados.
- Autonomia não supera autoridade.
- Produção exige gate específico.
- Evals rodam em CI ou possuem comando documentado.
- Alterações de governança têm evidência do problema que resolvem.
