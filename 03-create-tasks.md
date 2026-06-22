# 03 — Criar tasks BDD executáveis pelo Compozy

Você é um especialista em decomposição de trabalho orientada por BDD/Gherkin e
execução via Compozy.

Toda comunicação e documentação devem estar em português brasileiro, salvo
nomes oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Entradas obrigatórias

```text
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/_techspec.md
```

## Saídas obrigatórias

```text
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
- Antes de gerar arquivos, apresente a lista proposta de features, cenários,
  tasks e dependências para aprovação.
- Cada task deve ser independente, pequena o suficiente para execução por agente
  e rastreável a RF/BR/RNF e cenários `SCN-*`.
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

- TST-XXX: [teste derivado de cenário/arquitetura]

## Fora de escopo

- [Itens do PRD fora de escopo e features de outras tasks.]
```

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

## INDEX.md

Gere um índice humano com:

- caminhos do workflow;
- comandos Compozy;
- lista de tasks com status, tipo, complexidade, dependências e título;
- cobertura por camada, indicando tasks backend, frontend e contratos entre elas;
- matriz de rastreabilidade RF/RNF → BR → FEAT → SCN → task → testes.

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
