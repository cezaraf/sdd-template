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
- gates explícitos e CI;
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

## Assimilação arquitetural e TDD

O fluxo gera evidência técnica para o responsável compreender o sistema, não
apenas para provar que os testes passaram. Antes de codificar, o agente propõe
o mapa de módulos, diretórios, responsabilidades, arquivos e caminho principal
de execução. Mudanças materiais são discutidas, inclusive alternativas mais
simples. Durante a task, executa Outside-In TDD: RED documentado, GREEN mínimo
e REFACTOR com os testes verdes. Ao finalizar, compara a estrutura prevista
com os arquivos reais e explica onde investigar falhas típicas.

A ausência de hooks locais é deliberada: não existe interceptação automática
de cada chamada de ferramenta. O enforcement acontece nos comandos do guard,
na revisão do diff e em CI. Isso reduz atrito, mas exige disciplina para não
ignorar gates e branch protection.

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
- comandos explícitos do guard nas transições (sem hooks `PreToolUse` locais);
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
- guard e CI;
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
3. guard de contrato vivo/auditoria explícito + verificação no CI;
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

### Desbloqueio administrativo da governança

Este procedimento trata do bootstrap de autorização para mudanças nos controles
SDD. **Não é uma instrução para ignorar checks vermelhos ou tornar o
`authority checker` permissivo.**

### Por que o PR #5 ainda falha

A execução `pull_request_target` usa o workflow, o guard e a policy
**da branch-base** (não as versões propostas no PR). Na configuração base
atual, `authority.check_command` e `authority.check_sha256` estão vazios
em `governanca/policies.yaml.example`. Assim, o comando
`protect-ci` recusa alterações de `install.sh`, `evals/`, scripts de
governança e workflows com a decisão `governance_change`, mesmo quando o
dono do projeto aprova verbalmente o trabalho. Essa recusa é intencional.

### O que o administrador do repositório precisa decidir

1. Definir uma **fonte externa verificável de aprovação**, com escopo de
   mudança, SHA do commit e identidade autorizadora. Um comentário ou um campo
   `aprovado: true` dentro da própria branch candidata não são fontes
   independentes.
2. Provisionar um executável `authority checker` confiável **fora do
   checkout**, executável no runner do CI e **com SHA-256 fixado na policy
   da base**. O checker deve recusar solicitações sem aprovação válida ou
   quando `SDD_AUTH_GATE`, `SDD_AUTH_HEAD` e `SDD_AUTH_TARGET` não coincidirem
   com o registro aprovado; a aprovação de `governance_change` é específica
   para um escopo, não uma permissão global.
3. Incorporar o provisionamento ao **workflow confiável da base**. A política
   deve referenciar o caminho absoluto desse executável e seu digest,
   por meio de `authority.check_command` e
   `authority.check_sha256`. Como o próprio workflow/policy estão
   protegidos, a primeira ativação requer um procedimento administrativo
   explícito e auditável (bootstrap separado), antes de tentar aprovar o
   PR funcional.
4. Exigir os checks de CI na regra de proteção de `main`, revisar o diff e
   o histórico de aprovação do bootstrap e só então repetir o `SDD guard`.
   Sem isso, a branch principal pode receber alterações mesmo que o guard
   esteja vermelho, o que tornaria o controle meramente informativo.

### Checklist de aceitação

- A policy confiável da `main` aponta para um checker existente fora do
  worktree, com SHA-256 idêntico ao arquivo executado.
- Uma tentativa sem aprovação externa **falha**, inclusive quando o PR
  contém alterações no próprio guard, na policy ou no workflow.
- Uma aprovação explícita para o SHA e caminhos de um PR específico libera
  apenas aqueles alvos; mudança posterior de SHA exige nova autorização.
- `Template checks` e `SDD guard` passam para o mesmo SHA do PR aprovado.
- O instalador retira os registros `PreToolUse` SDD antes de apagar
  `sdd/governanca/sdd-hook-claude.sh`, inclusive sob falha parcial, sem
  modificar hooks de terceiros.

### Limite da migração dos hooks

O arquivo `governanca/sdd-hook-claude.sh` permanece no *repositório do
template* durante a transição apenas porque a versão antiga do workflow
confiável exige sua presença. **Ele não é instalado como hook ativo pelo
novo instalador.** Após a promoção administrativamente autorizada do
workflow novo, a remoção definitiva do arquivo legado pode ocorrer em uma
segunda alteração revisada, com os mesmos gates.

Não use `exit 0` incondicional, não edite o workflow do PR para fingir que
a policy da base mudou e não trate o status de administrador no GitHub como
prova criptográfica de uma aprovação externa que ainda não foi implantada.

