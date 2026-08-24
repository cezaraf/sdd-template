# 03 — Criar plano e tasks BDD

Você converte PRD/TechSpec em um plano persistido e tasks pequenas, rastreáveis
e executáveis.

> Leia `_comum.md` e todo o contexto canônico disponível.

## Saídas

```text
sdd/incrementos/[feature]/execucao.md
sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
```

Atualize `fase: planejamento`.

## Regras críticas

- Não implemente código ou testes.
- Cada comportamento alterado deve existir no impacto contratual.
- Cada task deve cobrir RF/BR/RNF, comportamento, `SCN-*` e `TST-*`.
- Backend e frontend devem ser tasks separadas quando a TechSpec indicar duas
  superfícies; dependências devem ser explícitas.
- O plano registra a base (`base_ref`/`base_sha`), rota efetiva, arquivos
  esperados, ordem, riscos, alternativas e provas.
- Depois de a auditoria aprovar, mudança material de escopo/plano exige revisão
  do plano e nova auditoria.
- Rode `compozy tasks validate --name [feature]` e corrija até passar.

## Frontmatter de task

```yaml
---
status: pending
title: "Task N.0: [título]"
type: backend
complexity: medium
dependencies: []
---
```

Valores de `type`: `frontend`, `backend`, `docs`, `test`, `infra`, `refactor`,
`chore`, `bugfix`.

## Estrutura de task

```markdown
# Task N.0: [título]

## Rastreabilidade

- FEAT-XXX:
- RF/RNF:
- BR:
- Comportamento:
- SCN:
- TST:
- Impacto contratual:

## Limites

- Dentro do escopo:
- Fora do escopo:
- Arquivos esperados:
- Contratos afetados:

## Dependências

- [task ou "Nenhuma"]

## Subtasks

- [ ] Implementar a menor superfície coerente.
- [ ] Aplicar validação, autorização e tratamento de erro.
- [ ] Implementar testes unitários/integração/contrato.
- [ ] Ligar cada `SCN-*` a teste automatizado.
- [ ] Atualizar documentação afetada, sem consolidar contrato vivo.

## Critérios de sucesso

- [resultado observável]
- Gates verdes.
- Diff compatível com o plano.

## Evidências esperadas

- [comando, teste, screenshot, payload ou métrica]

## Evidências produzidas

[preenchida durante a execução; esta é a única seção livre para anexar provas
sem mudar o conteúdo material auditado da task]
```

## Gherkin

```gherkin
# language: pt

@FEAT-XXX
Funcionalidade: [nome]

  Regra: BR-XXX - [regra]

    @SCN-XXX
    Cenário: [nome]
      Dado [contexto]
      Quando [ação]
      Então [resultado observável]
```

## Impacto contratual

```markdown
# Impacto contratual — [Domínio]

## Comportamentos novos

### Comportamento: [nome]

O sistema deve [comportamento observável].

#### Cenário: [nome]

- DADO ...
- QUANDO ...
- ENTÃO ...

## Comportamentos alterados

### Comportamento: [nome atual]

O sistema deve [novo comportamento].

(Antes: [resumo fiel do contrato vivo])

## Comportamentos removidos

### Comportamento: [nome]

[Motivo, impacto e autorização necessária.]
```

Inclua apenas seções aplicáveis.

## Template de `execucao.md`

```markdown
# Plano de execução — [feature]

## Identidade da base

- Base ref:
- Base SHA:
- Gerado em:
- Revisão do plano: 1

## Rota efetiva

- TechSpec: obrigatória/dispensada — [motivo]
- Review: obrigatório/dispensado — [motivo]
- PR/merge: obrigatório/dispensado — [motivo]
- Deploy/verificação: obrigatório/dispensado — [motivo]

## Objetivo operacional

[Resultado que o conjunto de tasks deve produzir.]

## Ordem de implementação

| Ordem | Task | Dependências | Resultado independente |
| --- | --- | --- | --- |

## Arquivos e superfícies esperadas

| Task | Arquivo/diretório | Tipo de mudança | Motivo |
| --- | --- | --- | --- |

## Contratos e dados

| Contrato/dado | Mudança | Compatibilidade | Rollback |
| --- | --- | --- | --- |

## Pontos de risco

| ID | Risco | Probabilidade | Impacto | Mitigação | Sinal de parada |
| --- | --- | --- | --- | --- | --- |

## Alternativas descartadas

- [alternativa]: [motivo]

## Provas de conclusão

| TST/SCN | Evidência | Comando/fluxo | Resultado esperado |
| --- | --- | --- | --- |

## Checklist de tasks

- [ ] `task_01` — [título]

## Gates

- [ ] Auditoria de especificação e plano
- [ ] Gate humano, quando exigido
- [ ] `compozy tasks validate --name [feature]`
- [ ] lint/typecheck/build/test/e2e
- [ ] review
- [ ] QA
- [ ] PR/merge, quando aplicável
- [ ] deploy/verificação, quando aplicável
- [ ] fechamento

## Aprovação do plano

### Parecer do agente

- Status: PENDENTE
- Evidência:

### Gate humano

- Requerido: sim/não
- Status: PENDENTE
- Aprovado por:
- Escopo:
- Data:

## Revisões do plano

| Revisão | Data | Motivo | Impacto | Reauditoria |
| --- | --- | --- | --- | --- |
```

## `INDEX.md`

Inclua tasks, status, dependências, impactos, cobertura por camada e matriz:

```text
RF/RNF → BR → FEAT → Comportamento → SCN → task → TST
```

Finalize com `compozy sync --name [feature]`.
