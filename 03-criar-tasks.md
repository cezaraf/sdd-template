# 03 — Criar tasks BDD executáveis pelo Compozy

Você é um especialista em decomposição de trabalho orientada por contratos
canônicos, BDD/Gherkin e execução via Compozy.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Entradas obrigatórias

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
.compozy/tasks/[feature]/_prd.md
```

Para incrementos `medium` e `large`, leia também:

```text
.compozy/tasks/[feature]/_techspec.md
```

Obrigatoriedade de PRD/TechSpec por trilha: ver `_comum.md`. Em incrementos
`small` sem TechSpec, registre as decisões técnicas simples nos detalhes da
task ou em ADR, quando necessário.

## Saídas obrigatórias

```text
sdd/incrementos/[feature]/execucao.md
sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_01.md
.compozy/tasks/[feature]/task_02.md
.compozy/tasks/[feature]/feature/001__task.feature
.compozy/tasks/[feature]/feature/002__task.feature
```

Crie também, quando necessário:

```text
.compozy/tasks/[feature]/adrs/
.compozy/tasks/[feature]/memory/
.compozy/tasks/[feature]/reviews-001/
```

## Regras críticas

- NÃO implemente código.
- NÃO escreva testes implementados.
- Faça perguntas de esclarecimento apenas quando PRD, TechSpec ou impactos
  contratuais não permitirem decompor com segurança; caso contrário, registre
  as premissas assumidas e prossiga.
- Não altere `sdd/contratos/` fora do fechamento
  (`10-consolidar-contrato-vivo.md`); mudanças de comportamento entram em
  `sdd/incrementos/[feature]/impacto-contratual/`.
- Cada task deve ser independente, pequena o suficiente para execução por agente
  e rastreável a RF/BR/RNF e cenários `SCN-*`.
- IDs `FEAT`, `SCN`, `TST`, `RF`/`RNF` e `BR` seguem o "Esquema de
  identificadores" de `_comum.md`.
- Cada comportamento novo, alterado ou removido deve aparecer em impacto contratual com
  `Comportamentos novos`, `Comportamentos alterados` ou `Comportamentos removidos`.
- Cada task deve ter exatamente um arquivo `task_NN.md`.
- Cada task com comportamento deve ter um `.feature` em `# language: pt`.
- Cada `task_NN.md` deve validar no Compozy.
- Quando `_techspec.md` indicar impacto em backend e frontend, gere tasks dos
  dois tipos (`type: backend` e `type: frontend`) com dependências explícitas.
- Não esconda trabalho frontend em task backend, ou trabalho backend em task
  frontend. Se uma entrega for indivisível, registre a justificativa na task e
  no `INDEX.md`.

## Frontmatter obrigatório de `task_NN.md`

O `title` deve ser exatamente igual ao primeiro H1.

```markdown
---
status: pending
title: "Task N.0: [título]"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task N.0: [título]
```

Valores permitidos:

- `status`: `pending` ou `completed`
- `type`: `frontend`, `backend`, `docs`, `test`, `infra`, `refactor`,
  `chore`, `bugfix`
- `complexity`: `low`, `medium`, `high`
- `dependencies`: lista de IDs `task_NN` ou `[]`

## Estrutura de cada task

```markdown
---
status: pending
title: "Task N.0: [título]"
type: backend
complexity: medium
dependencies: []
---

# Task N.0: [título]

## Feature atendida

- FEAT-XXX: [nome]

## Impacto contratual relacionado

- Domínio: [dominio]
- Impacto: `sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md`
- Tipo de impacto: NOVO / ALTERADO / REMOVIDO

## Camada e integração

- Tipo: `backend` / `frontend` / `docs` / `test` / `infra` / `refactor` / `chore` / `bugfix`
- Backend afetado: [módulos, endpoints, jobs, persistência ou "Não se aplica"]
- Frontend afetado: [rotas, telas, componentes, estado de UI ou "Não se aplica"]
- Contrato entre camadas: [DTO/API/evento/schema ou "Não se aplica"]

## Arquivo Gherkin relacionado

- `feature/NNN__task.feature`

## Visão geral

[Entrega e valor de negócio.]

## Requisitos cobertos

- RF-XXX
- RNF-XXX
- Comportamento: [nome no impacto contratual]

## Regras de negócio cobertas

- BR-XXX: [regra]

## Cenários BDD cobertos

- SCN-XXX: [cenário]

## Dependências

- [task_NN ou "Nenhuma"]

## Subtasks

- [ ] N.1 Implementar comportamento na camada declarada conforme TechSpec
- [ ] N.2 Atualizar contratos compartilhados e compatibilidade com a outra camada
- [ ] N.3 Aplicar validações, permissões e tratamento de erro
- [ ] N.4 Ligar o `.feature` por teste BDD executável em modo estrito
- [ ] N.5 Implementar testes unitários
- [ ] N.6 Implementar testes de integração
- [ ] N.7 Implementar E2E, se aplicável
- [ ] N.8 Para task backend: validar endpoints/serviços, persistência, autorização e payloads consumidos pelo frontend
- [ ] N.9 Para task frontend: validar rotas/telas, estados de UI, acessibilidade e consumo do contrato backend

## Detalhes de implementação

Consultar `_techspec.md`. Não repetir detalhes extensos aqui.

## Critérios de sucesso

- Cenários `SCN-*` verdes.
- Regras de negócio aplicadas.
- Segurança, privacidade e isolamento respeitados.
- `lint`, `typecheck`, `build`, `test` e E2E aplicável verdes.

## Testes planejados

- TST-XXX: [teste derivado de cenário/contrato]

## Fora de escopo

- [Itens do PRD fora de escopo e features de outras tasks.]
```

Ao gerar cada task, inclua N.8 apenas quando `type: backend` e N.9 apenas
quando `type: frontend`; para os demais tipos, remova ambas. Remova (não deixe
desmarcadas) subtasks não aplicáveis.

## Template Gherkin

```gherkin
# language: pt

@FEAT-XXX
Funcionalidade: [nome]
  Como [persona/sistema]
  Quero [ação]
  Para [benefício]

  Regra: BR-XXX - [regra]

    @SCN-XXX
    Cenário: [nome]
      Dado [contexto]
      Quando [ação]
      Então [resultado observável]
```

## Template de impacto contratual

Este é o template canônico de impacto contratual;
`10-consolidar-contrato-vivo.md` referencia este formato.

```markdown
# Impacto contratual - [Domínio]

## Comportamentos novos

### Comportamento: [nome]

O sistema deve [comportamento observável].

#### Cenário: [nome]

- DADO [contexto]
- QUANDO [ação]
- ENTÃO [resultado observável]

## Comportamentos alterados

### Comportamento: [nome existente]

O sistema deve [novo comportamento observável].

(Antes: [resumo do comportamento anterior])

#### Cenário: [nome]

- DADO [contexto]
- QUANDO [ação]
- ENTÃO [resultado observável]

## Comportamentos removidos

### Comportamento: [nome existente]

[Motivo da remoção e impacto esperado.]
```

Inclua apenas seções aplicáveis. Não deixe cabeçalhos vazios.

## INDEX.md

Gere um índice humano com:

- caminhos do incremento SDD canônico;
- caminhos do workflow;
- comandos Compozy;
- lista de tasks com status, tipo, complexidade, dependências e título
  (`06-executar-task.md` e `09-corrigir-bugs.md` atualizam a linha da task no
  `INDEX.md` ao concluir);
- impactos contratuais por domínio e tipo de incremento;
- cobertura por camada, indicando tasks backend, frontend e contratos entre elas;
- matriz de rastreabilidade RF/RNF → BR → FEAT → Comportamento → SCN → task →
  testes.

## `sdd/incrementos/[feature]/execucao.md`

Gere um checklist canônico resumido, com links para as tasks Compozy:

```markdown
# Tasks: [feature]

## Rastreabilidade canônica

| Item | Domínio | Comportamento | SCN | Compozy task | Teste planejado |
| --- | --- | --- | --- | --- | --- |

## Checklist

- [ ] `task_01` — [título]
- [ ] `task_02` — [título]

## Gates

- [ ] `compozy tasks validate --name [feature]`
- [ ] lint/typecheck/build/test/e2e aplicáveis
- [ ] review
- [ ] QA
- [ ] fechamento
```

## Validação obrigatória

Depois de criar os arquivos:

```bash
compozy tasks validate --name [feature]
```

Corrija até a saída ser:

```text
all tasks valid
```

Depois rode:

```bash
compozy sync --name [feature]
```
