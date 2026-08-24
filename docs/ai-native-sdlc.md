# Arquitetura AI-native do SDD Template

## Objetivo

Esta evolução mantém o núcleo do SDD — contratos vivos, BDD, rastreabilidade,
auditoria, review e QA — e adiciona a camada que faltava para um SDLC AI-native:

```text
artefatos como estado
+ gates como autoridade
+ policies como enforcement
+ evidências como critério de transição
+ produção como parte do loop
+ incidentes como evals
```

## Duas camadas

### Kernel de especificação e evidência

Responsável por:

- intenção e requisitos;
- arquitetura e contratos;
- plano e tasks;
- BDD e testes;
- auditoria, review e QA;
- contrato vivo;
- histórico.

### Control plane operacional

Responsável por:

- máquina de estados;
- autoridade por risco/autonomia;
- hooks e CI;
- branches/worktrees;
- PR, merge e deploy;
- health checks e rollback;
- evals do harness;
- promoção de aprendizados.

O kernel deve permanecer agnóstico de fornecedor. Claude Code, Codex, OpenCode,
Compozy, GitHub e outros são adaptadores.

## Por que separar rigor, risco e autonomia

Misturar essas dimensões produz decisões ruins:

- mudança pequena pode ter risco alto;
- feature grande pode ser segura e reversível;
- documentação completa não autoriza deploy;
- autonomia alta não reduz a necessidade de evidência.

O processo agora registra as quatro dimensões em `incremento.yaml`.

## Gate duplo

Cada transição sensível pode ter:

1. **parecer do agente**: confirma consistência e evidência;
2. **gate humano**: concede autoridade e aceita trade-offs.

Exemplo:

```yaml
gates:
  especificacao:
    parecer_agente:
      status: pronto
      agente: cz-auditor-especificacao
      evidencia: .compozy/tasks/x/auditoria-especificacao.md
    gate_humano:
      requerido: true
      status: aprovado
      aprovado_por: cezar
      escopo: "implementar tasks 01–04; sem PR ou deploy"
      data: 2026-08-23
```

A aprovação é escopada. Não existe “aprovou uma vez, autorizou tudo”.

## Plano como artefato executável

O `execucao.md` reduz a distância entre especificação e código. Ele permite
verificar automaticamente:

- se o agente editou arquivos fora do esperado;
- se a ordem respeitou dependências;
- se contratos/dados tiveram rollback;
- se todos os riscos possuem mitigação;
- se as provas foram realmente produzidas;
- se o diff exige reauditoria.

O plano é revisável, não imutável. Toda revisão registra motivo e impacto.

## Enforcement

### Consultivo

- `_comum.md`;
- prompts;
- `AGENTS.md`/`CLAUDE.md`;
- rules;
- skills;
- ADRs.

### Determinístico

- `sdd/governanca/policies.yaml` (caminhos protegidos, segredos, autoridade);
- `sdd/governanca/sdd-guard.sh` (gates, `protect`, `protect-ci`, segredos);
- `sdd/governanca/sdd-hook-claude.sh` como hook `PreToolUse`, instalado
  automaticamente em `.claude/settings.json`;
- `.github/workflows/sdd-guard.yml` (guard/evals extraídos da base sobre o diff
  candidato, sem executar scripts propostos pelo PR privilegiado);
- branch protection;
- permissões e credenciais temporárias;
- gates do ambiente.

A janela de escrita do contrato vivo exige três condições simultâneas:
`status: validado`, `fase: fechamento` e atestado efêmero emitido por
`pre-consolidate`, vinculado ao `HEAD` e aos domínios impactados. Estado sozinho
não libera a escrita. No CI, `protect-ci` troca o token local por uma decisão
externa `contract_change`.

O CI resolve policy, guard e evals a partir do commit base, materializados fora
do worktree. Assim o PR não escolhe o próprio checker nem executa controles
candidatos sob `pull_request_target`; mudanças no trust root exigem
`governance_change` externo.

Gates humanos também exigem prova externa. `authority.check_command` aponta
para um executável protegido fora do worktree; o YAML é somente registro. Sem
checker ou com `quality_commands` vazios e sem waiver, o guard falha fechado.

Regra crítica sem enforcement deve ser tratada como dívida de governança.

## Autonomia progressiva

Aumente autonomia somente quando houver evidência histórica:

```text
assistido
→ autonomo_ate_pr
→ autonomo_ate_staging
→ producao_com_gate
```

Critérios sugeridos:

- taxa de retrabalho;
- falhas detectadas no review;
- bugs pós-merge;
- rollback;
- evals do harness;
- aderência ao plano;
- custo/latência do processo.

## Contrato vivo e alvo

Antes, o contrato podia ser atualizado após QA local mesmo quando a intenção era
descrever produção. Agora o alvo é explícito:

- `local`: experimento validado localmente;
- `branch`: comportamento merged;
- `producao`: comportamento implantado e verificado.

Isso elimina a ambiguidade “o sistema faz isso onde?”.

## Loop operacional

```text
sdd-watch.sh detecta desvio (1σ/2σ/3σ, sem LLM)
→ 2σ: agente correlaciona evidências em modo somente-leitura
→ 3σ: runbook pré-aprovado e/ou incidente aberto
→ passo 00 pela rota `incidente` cria o incremento
→ correção cria regressão
→ deploy é verificado (passo 12)
→ incidente vira eval no passo 14 quando recorrente ou caro
```

LLM não é o detector primário de disponibilidade: métricas, checks e faixas de
controle detectam; o agente ajuda a diagnosticar. Dentro do fluxo,
`sdd-fluxo.sh` responde qual é o próximo passo autorizado usando `pre-specify`
e `pre-validate`, e aplica apenas transições já sustentadas pelo guard (`--run`).

## Métricas

`sdd-metricas.sh` lê o bloco `metricas:` do incremento (com fallback no git) e
produz indicadores leading (tempos de ciclo) e lagging (reauditorias, revisões
de plano, issues, bugs, `P0`/`P1`, aderência ao plano). A série vai para
`sdd/metricas.csv` por upsert no fechamento; a seção do relatório é atualizada
idempotentemente. Marcos temporais são write-once e plano sem paths produz
aderência indeterminada, nunca razão `N/0`. Sem série histórica, não se promove
autonomia.

## Evals do harness

O runner é `evals/run-evals.sh`: tier 1 determinístico (fixtures + guard, roda
em CI a cada PR) e tier 2 agêntico com executor e oracle em sandboxes
`bubblewrap`, sem acesso ao projeto fonte, homes, ambiente ou sockets do host.
Cada caso agêntico declara IDs de critérios; o oracle
deve cobrir exatamente todos eles. Sem qualquer processo há `SKIP` explícito e
`--all` termina não zero; evidência não vazia não é verdict.
A qualidade do tier 1 é medida por mutação — desativar uma checagem do guard
tem de deixar a suíte vermelha.

Evals não são testes do produto. Elas verificam se o processo continua
produzindo decisões seguras quando mudam:

- prompts;
- modelo;
- context window;
- skills;
- agents;
- hooks;
- policies;
- tool permissions.

Cada incidente relevante deve responder:

> Qual eval teria impedido ou detectado isto antes?

## Migração

1. reinstale o template;
2. adicione `fase` e `classificacao` aos incrementos ativos;
3. gere/revise `execucao.md`;
4. migre `policies.yaml` para version 2, configure checker externo e comandos de qualidade;
5. rode as evals canônicas;
6. aplique os novos passos 10–14 apenas a entregas ainda não consolidadas;
7. não altere histórico antigo.

## Adoção recomendada

Comece por:

1. plano persistido;
2. gate duplo;
3. guard de contrato vivo/auditoria + hook no harness;
4. evals tier 1 no CI;
5. PR/merge dentro do fluxo;
6. alvo `branch`;
7. métricas por incremento;
8. produção, detector operacional e rota de incidente após estabilizar.

O objetivo não é maximizar cerimônia. É aumentar autonomia sem perder
autoridade, evidência ou capacidade de rollback.


## Referência externa

A camada operacional foi informada pelo playbook
[The AI-native software development lifecycle](https://claude.com/blog/the-ai-native-sdlc-playbook),
da Anthropic. O SDD Template não replica o playbook: preserva seu kernel de
contratos vivos, BDD e rastreabilidade e adota as ideias de artefatos como
estado, gates explícitos, enforcement determinístico, evals e loop operacional.
