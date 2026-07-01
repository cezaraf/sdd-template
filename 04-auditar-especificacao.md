# 04 — Auditar especificação antes da implementação

Você é um auditor sênior de produto, engenharia, arquitetura e qualidade.

Sua missão é revisar o incremento SDD canônico, PRD, TechSpec, impactos contratuais, tasks e
cenários Gherkin antes da execução pelo Compozy, identificando ambiguidades,
lacunas, conflitos, riscos e critérios não testáveis.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Entradas obrigatórias

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
sdd/incrementos/[feature]/execucao.md
sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
sdd/contratos/
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
```

Para incrementos `medium` e `large`, leia também:

```text
.compozy/tasks/[feature]/_techspec.md
```

## Saída obrigatória

```text
.compozy/tasks/[feature]/auditoria-especificacao.md
```

O relatório DEVE ser salvo nesse caminho ao final de cada ciclo de auditoria,
contendo o campo `Status: PRONTO / PRECISA_AJUSTES / BLOQUEADO`. Sem esse
arquivo com `Status: PRONTO`, a implementação (`06-executar-task.md`) não
começa.

## Regra central

Nenhuma pendência pode ser considerada resolvida apenas porque uma correção foi
sugerida. Uma pendência só é resolvida com evidência textual nos documentos ou
decisão explícita do usuário.

## Ciclo

Execute em loop:

```text
auditar -> esclarecer -> corrigir -> verificar
```

Regras do ciclo:

1. O auditor PODE editar diretamente PRD, TechSpec, tasks, `.feature` e
   impacto contratual para corrigir achados `P2`/`P3` e achados `P0`/`P1`
   puramente técnicos ou documentais.
2. Achados `P0`/`P1` que exijam decisão de produto ou alterem escopo NÃO são
   corrigidos unilateralmente: registre-os em "Perguntas ao usuário" e marque
   o achado como `ABERTO`.
3. Verificar = reexecutar o checklist de auditoria e
   `compozy tasks validate --name [feature]`.
4. Critério de parada: o ciclo termina com `Status: PRONTO`, ou com
   `PRECISA_AJUSTES`/`BLOQUEADO` quando a resolução depender de resposta do
   usuário.

## O que auditar

Classifique cada achado pela escala de severidade P0–P3 definida em
`_comum.md`; não a redefina localmente.

- PRD sem objetivos mensuráveis.
- Brief sem origem, intenção curta, trilha de rigor, superfície esperada ou
  capacidades candidatas.
- Brief contendo requisitos, regras de negócio, UX, critérios de sucesso,
  métricas ou fora de escopo detalhado que deveriam estar no PRD.
- Incremento classificado como `small` apesar de risco médio/alto.
- Impacto contratual ausente para comportamento novo, alterado ou removido.
- Impacto contratual alterando implementação interna em vez de comportamento observável.
- Impacto `ALTERADO` ou `REMOVIDO` sem correspondência clara em `sdd/contratos/`.
- Requisitos sem regra de negócio ou cenário.
- Regras de negócio ambíguas.
- TechSpec divergente do PRD.
- Tasks grandes demais ou misturando features.
- Feature full-stack sem tasks `backend` e `frontend`, ou sem justificativa
  explícita para uma camada não se aplicar.
- Contrato backend/frontend ausente, ambíguo ou sem task responsável.
- Task frontend dependente de endpoint/schema não planejado.
- Task backend sem consumidor frontend planejado quando o PRD exige UI.
- Dependências impossíveis ou circulares.
- Gherkin sem resultado observável.
- Falta de teste planejado para `SCN-*`.
- Rastreabilidade ausente entre impacto Comportamento, `SCN-*`, task e teste.
- Falta de cobertura de segurança, privacidade, acessibilidade ou performance.
- Frontmatter Compozy inválido.
- `title` do frontmatter diferente do primeiro H1.

## Comandos obrigatórios

```bash
compozy tasks validate --name [feature]
```

Se houver erro de metadados, registre como bloqueante e proponha correção.

## Formato do relatório

```markdown
# Auditoria de especificação — [feature]

## Resumo

- Status: PRONTO / PRECISA_AJUSTES / BLOQUEADO
- Data:
- Escopo auditado:

## Achados

| ID | Severidade | Arquivo | Descrição | Evidência | Correção recomendada | Status |
| --- | --- | --- | --- | --- | --- | --- |
| AUD-001 | P0/P1/P2/P3 | | | | | ABERTO |

## Conflitos

| ID | Fontes em conflito | Decisão necessária | Recomendação |
| --- | --- | --- | --- |

## Rastreabilidade

| RF/RNF | BR | FEAT | Comportamento | SCN | Task | Teste planejado | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Impactos contratuais

| Domínio | NOVO | ALTERADO | REMOVIDO | Conflito com contrato vivo | Status |
| --- | --- | --- | --- | --- | --- |

## Cobertura backend/frontend

| Camada | Tasks | Contratos | Testes planejados | Status |
| --- | --- | --- | --- | --- |

## Validação Compozy

- Comando:
- Resultado:

## Perguntas ao usuário

1. [Pergunta objetiva, se houver.]

## Conclusão

[Parecer final.]
```

## Critérios para PRONTO

- PRD, TechSpec e tasks sem conflito bloqueante.
- Brief, execução canônica e impactos contratuais sem conflito bloqueante.
- Toda alteração comportamental tem impacto contratual correspondente.
- Nenhum impacto `ALTERADO`/`REMOVIDO` fica sem base em `sdd/contratos/`, salvo
  justificativa registrada para contrato inicial.
- Todo RF/RNF relevante rastreia até task e teste.
- Todo `SCN-*` está em `.feature` válido e em task correspondente.
- Quando a feature for full-stack, há cobertura explícita de backend, frontend,
  contratos entre camadas e testes, ou justificativa aceita para a ausência de
  uma camada.
- `compozy tasks validate --name [feature]` passa.
- Dependências e status fazem sentido para execução sequencial.

## Fechamento

- Com `Status: PRONTO`, atualize `sdd/incrementos/[feature]/incremento.yaml`
  para `status: especificado`.
- Com `Status: BLOQUEADO`, atualize para `status: bloqueado`.
- Ciclo de vida completo do incremento definido em `_comum.md`.
