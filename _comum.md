# Regras comuns do fluxo SDD

Este arquivo é a fonte única das regras compartilhadas pelos prompts `00` a
`14`. Todo prompt do fluxo deve lê-lo antes de executar.

## Princípio

O SDD transforma intenção em comportamento verificável. Documentos não existem
para aumentar cerimônia: cada artefato deve reduzir ambiguidade, limitar
autoridade, permitir automação ou produzir evidência.

## Idioma

Toda comunicação e documentação em português brasileiro (`pt-BR`), exceto
nomes oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Terminologia

- **Incremento**: unidade completa de entrega, da triagem à consolidação.
- **Brief**: retrato imutável da solicitação original e da classificação inicial.
- **PRD**: contrato de produto — problema, valor, requisitos, regras e limites.
- **TechSpec**: contrato técnico — arquitetura, contratos, riscos e estratégia de
  testes.
- **Plano de execução**: `sdd/incrementos/[feature]/execucao.md`; descreve
  arquivos esperados, ordem, riscos, provas e gates antes do código.
- **Contrato vivo**: comportamento consolidado do sistema em
  `sdd/contratos/[dominio]/contrato.md`.
- **Impacto contratual**: comportamento `NOVO`, `ALTERADO` ou `REMOVIDO`
  planejado no incremento.
- **Gate**: decisão registrável que autoriza a próxima transição.
- **Parecer do agente**: verificação baseada em evidência; não substitui decisão
  humana quando esta for exigida.
- **Eval do harness**: caso de regressão que verifica o comportamento dos
  prompts, skills, agents, policies e hooks.

## Dimensões de governança

As dimensões abaixo são independentes. Não use `rigor` como sinônimo de risco ou
autonomia.

### Rigor documental

- `small`: uma capacidade local, poucas superfícies e solução conhecida; PRD
  enxuto e plano curto.
- `medium`: mais de uma superfície, contrato entre camadas, UX relevante ou
  decisões técnicas que precisam ser preservadas; PRD e TechSpec enxutos.
- `large`: múltiplas capacidades, domínios ou times, alta ambiguidade,
  sequenciamento complexo ou várias alternativas arquiteturais; fluxo completo.

Segurança, privacidade, billing, migração e dados sensíveis elevam o **risco** e
podem tornar TechSpec/review obrigatórios, mas não determinam sozinhos o tamanho
documental.

### Risco

- `baixo`: falha reversível, impacto local, sem contrato público.
- `medio`: regressão relevante, integração ou impacto em usuários.
- `alto`: segurança, autorização, integridade, migração, indisponibilidade,
  contrato público ou grande blast radius.
- `regulado`: dados sensíveis, obrigação legal/regulatória, auditoria formal ou
  ambiente com segregação obrigatória.

### Autonomia

- `assistido`: o agente propõe e executa tarefas locais; qualquer commit, push,
  PR, merge ou deploy exige autorização explícita.
- `autonomo_ate_pr`: uma autorização registrada no gate pode cobrir
  implementação, testes, commits e abertura de PR; merge e deploy continuam
  exigindo gate próprio.
- `autonomo_ate_staging`: além do anterior, pode implantar em staging quando o
  gate do incremento autorizar; produção sempre exige autorização específica.
- `producao_com_gate`: o agente pode preparar tudo, mas cada deploy em produção
  exige aprovação humana recente, escopo delimitado e rollback definido.

### Alvo do contrato vivo

- `branch`: representa o comportamento consolidado na branch alvo após merge.
- `producao`: representa somente comportamento confirmado em produção.
- `local`: permitido apenas para experimentos sem PR/deploy; exige justificativa.

## Matriz mínima de gates humanos

Gate humano é obrigatório quando houver ao menos um dos fatores:

- risco `alto` ou `regulado`;
- alteração de contrato público, autorização, billing, dados ou migração;
- autonomia acima de `assistido`;
- merge em branch protegida;
- deploy em produção;
- exceção a gate vermelho;
- remoção de comportamento do contrato vivo.

A aprovação deve registrar pessoa, data, escopo e evidência. Uma aprovação para
especificação não autoriza automaticamente merge ou produção.

## Precedência dos artefatos

Quando houver conflito, não escolha silenciosamente. Use esta ordem:

1. decisão explícita e atual do usuário, registrada no incremento;
2. contrato vivo para descrever o comportamento atual;
3. impacto contratual aprovado para descrever o comportamento alvo;
4. PRD para o `O QUÊ` e o `POR QUÊ`;
5. TechSpec e ADRs para o `COMO`;
6. plano de execução e tasks para ordem, limites e provas;
7. implementação e testes como evidência — nunca como fonte automática de
   verdade quando contradisserem os contratos.

## Contexto canônico do incremento

Salvo instrução específica, leia integralmente:

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
sdd/incrementos/[feature]/execucao.md
sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
sdd/contratos/[dominio]/contrato.md
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/_techspec.md        (quando exigida)
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
sdd/governanca/policies.yaml                (quando existir)
AGENTS.md / CLAUDE.md / regras locais       (quando existirem)
```

## Estado do incremento

`status` é o estado macro:

```text
proposto → especificado → em_execucao → validado → consolidado
                         ↘ bloqueado ↗
```

`fase` detalha a posição operacional:

```text
triagem
→ especificacao
→ planejamento
→ auditoria
→ implementacao
→ review
→ qa
→ validacao
→ pr
→ merge
→ deploy
→ verificacao
→ fechamento
→ aprendizado
```

Regras:

- `bloqueado` sempre deve ter `bloqueio.motivo`, `bloqueio.gate` e
  `bloqueio.como_desbloquear`.
- `validado` significa review e QA aprovados; não significa merged ou deployed.
- `consolidado` só é permitido pelo passo `13`.
- Para `alvo_contrato: branch`, a consolidação exige merge confirmado.
- Para `alvo_contrato: producao`, exige deploy e verificação de produção.
- Para `alvo_contrato: local`, exige justificativa e dispensa explícita de
  PR/deploy no relatório de fechamento.

## Formato canônico de gate

```yaml
parecer_agente:
  status: pendente # pendente | pronto | precisa_ajustes | bloqueado
  agente: ""
  evidencia: ""
  data: ""
gate_humano:
  requerido: false
  status: dispensado # pendente | aprovado | rejeitado | dispensado
  aprovado_por: ""
  escopo: ""
  data: ""
```

Não marque `aprovado` sem decisão explícita. Quando `requerido: false`, use
`status: dispensado`; quando `true`, use `pendente`, `aprovado` ou `rejeitado`.
`dispensado` exige justificativa.

## Rota e artefatos obrigatórios

O conjunto de etapas deriva de rigor, risco e alvo; não apenas do rigor:

- todos: brief, PRD, plano/tasks, impacto contratual, auditoria, implementação,
  testes, QA, consolidação e avaliação de aprendizados;
- TechSpec: obrigatória para `medium`/`large`, risco `alto`/`regulado`, mudança
  de contrato público, autorização, billing, dados ou migração;
- review independente: obrigatório para `medium`/`large`, risco diferente de
  `baixo` ou qualquer entrega com PR/merge;
- PR/merge: obrigatório para alvo `branch` ou `producao`;
- deploy/verificação: obrigatório para alvo `producao`;
- ADR: quando o critério objetivo do passo 02 for atendido.

Toda dispensa deve ser registrada no plano e auditada. Uma classificação
`small` nunca dispensa controles exigidos pelo risco ou pelo alvo.

## Escala de severidade

- **P0 — bloqueante**: corrupção/perda de dados, falha de segurança grave,
  violação de contrato vivo, indisponibilidade crítica ou ação irreversível.
- **P1 — alta**: comportamento contratual incorreto, cenário crítico reprovado
  ou ausência de controle essencial sem workaround razoável.
- **P2 — média**: defeito com workaround; deve ser registrado.
- **P3 — baixa**: cosmético, dívida localizada ou melhoria.

`P0` e `P1` abertos bloqueiam merge, deploy e consolidação. `P2`/`P3` exigem
registro e decisão de aceite.

## Definition of Done

Uma task só está concluída quando:

1. critérios de sucesso e limites da task foram atendidos;
2. todo `SCN-*` possui teste automatizado verde citando o ID;
3. lint, typecheck, build, testes e E2E aplicáveis passaram;
4. contratos entre camadas e compatibilidade foram verificados;
5. `compozy tasks validate --name [feature]` passou;
6. o diff permanece dentro do plano aprovado, ou a revisão do plano foi
   registrada;
7. nenhuma regra crítica, segredo ou caminho protegido foi violado;
8. evidências foram registradas no artefato correto.

## Identificadores

Numeração sequencial dentro do incremento:

- `RF-NNN`, `RNF-NNN`, `BR-NNN`, `PRM-NNN`;
- `FEAT-NNN`, `SCN-NNN`, `TST-NNN`;
- `AUD-NNN`, `REVIEW-NNN`, `BUG-NNN`, `OPS-NNN`, `EVAL-NNN`.

Cadeia esperada:

```text
RF/RNF → BR → FEAT → Comportamento → SCN → task → TST → evidência
```

## Loop operacional

O fluxo não depende de alguém lembrar qual é o próximo passo:

```text
sdd/governanca/sdd-fluxo.sh [feature]          # próximo passo autorizado
sdd/governanca/sdd-fluxo.sh [feature] --run    # aplica transições determinísticas
sdd/governanca/sdd-guard.sh <gate> [feature]   # gates determinísticos
sdd/governanca/sdd-metricas.sh [feature]       # indicadores do incremento
sdd/evals/run-evals.sh --tier1                 # regressão do harness
sdd/governanca/sdd-watch.sh                    # detecção operacional (2σ/3σ)
```

`--run` só executa transições sustentadas por evidência (`proposto →
especificado` com auditoria `PRONTO`; `em_execucao → validado` com review, QA e
sem `P0`/`P1`). Ele nunca concede gate humano, nunca faz commit, push, merge ou
deploy. Um desvio de 3σ no detector entra no fluxo pela rota `incidente` do
passo `00` e fecha o loop.

## Métricas do incremento

O bloco `metricas:` do `incremento.yaml` é a fonte canônica dos indicadores
(leading: tempos de ciclo; lagging: retrabalho, bugs e aderência ao plano).
Cada passo registra seu marco com
`sdd-metricas.sh [feature] --marcar <campo>`; o passo `13` consolida a série em
`sdd/metricas.csv`. Sem série histórica não se aumenta autonomia.

## Enforcement determinístico

Regras críticas não devem depender apenas de texto no prompt. Quando o projeto
permitir, instale hooks/CI para:

- impedir alteração de `sdd/contratos/` antes do passo `13`;
- impedir implementação sem auditoria `PRONTO`;
- impedir conclusão sem gates e evidências;
- impedir merge/deploy com `P0`/`P1`;
- impedir segredos e acesso a arquivos protegidos;
- executar formatadores, lint e validações;
- validar transições de `status`/`fase`.

O template fornece `governanca/sdd-guard.sh` (gates, `protect`, `protect-ci` e
scanner de segredos), `governanca/sdd-hook-claude.sh` (hook `PreToolUse`
instalado pelo instalador), `governanca/policies.yaml.example`,
`.github/workflows/sdd-guard.yml` e as evals em `evals/`.

A janela de escrita de `sdd/contratos/` é estreita por construção. O gate
`pre-consolidate` emite um atestado efêmero em `.git/sdd-state`, vinculado a
feature, `HEAD`, validade curta e domínios declarados em `impacto-contratual/`.
Só esses domínios podem ser escritos enquanto o atestado estiver válido.
`status: validado` e `fase: fechamento` descrevem o estado, mas não liberam a
escrita sozinhos. No CI, onde o token local não existe, `protect-ci` exige uma
decisão externa específica para `contract_change`.

## Política de git e autoridade

Sem commit, push, PR, merge ou deploy sem autorização explícita compatível com
a autonomia registrada. O YAML registra a decisão, mas não prova sua origem.
Quando o gate é humano, `authority.check_command` deve apontar para um checker
executável absoluto, fora do worktree, fixado por `authority.check_sha256`, que
valide feature, gate, `HEAD` e escopo recebidos em `SDD_AUTH_*`. Sem checker ou
com digest divergente, a operação falha fechada. Produção sempre exige gate
específico e recente.

No CI, o checker é resolvido pela policy extraída do commit base em
`SDD_TRUSTED_POLICIES` e o guard/evals executados também são extraídos da base,
nunca escolhidos pelo próprio PR. O checkout candidato não persiste credenciais;
alterar o trust root exige aprovação externa de `governance_change`.

Auditoria, review e QA registram um único `Evidence SHA` verificável. Review e
QA apontam para o mesmo commit da implementação; mudança de código posterior
invalida ambos. O checker externo confirma `audit_evidence`, `review_evidence` e
`qa_evidence`, e a cobertura agregada deve fechar todos os `SCN-*`/`TST-*`.

`quality_commands` deve conter os comandos reais do projeto. Lista vazia não é
verde: exige dispensa confirmada pelo mesmo checker externo.

## Segurança e testes

- Não use serviços externos reais em testes automatizados.
- Mocks somente nas fronteiras externas.
- Não exponha segredos em logs, fixtures, snapshots ou relatórios.
- Não desative lint, typecheck ou testes para obter resultado verde.
- Operações destrutivas exigem backup/rollback e autorização explícita.
