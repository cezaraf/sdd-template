# SDD Template para Compozy

Template agnóstico de projeto para conduzir um fluxo SDD/BDD com artefatos
executáveis pelo Compozy.

## Uso

Copie estes arquivos para a raiz do projeto alvo ou use-os como prompts de
referência:

```bash
cp /data/desenvolvimento/sdd-template/0*.md /caminho/do/projeto/
mkdir -p /caminho/do/projeto/.compozy
cp /data/desenvolvimento/sdd-template/compozy-config.toml.example /caminho/do/projeto/.compozy/config.toml
```

Fluxo recomendado:

1. `01-create_prd.md` gera `.compozy/tasks/[feature]/_prd.md`.
2. `02-create-techspec.md` gera `.compozy/tasks/[feature]/_techspec.md`.
3. `03-create-tasks.md` gera `task_NN.md`, `feature/NNN__task.feature` e `INDEX.md`.
4. `04-check-specification.md` audita PRD, TechSpec e tasks.
5. `05-create-install-rules-skills.md` gera governança local do projeto.
6. `compozy tasks validate --name [feature]` valida os metadados v2.
7. `compozy sync --name [feature]` registra o workflow no daemon.
8. `compozy tasks run [feature] --ide codex --stream` executa as tasks pendentes.

## Garantia backend/frontend

Para features full-stack, os artefatos precisam deixar explícito:

- TechSpec com backend, frontend, contratos entre camadas e testes de ambas as
  partes.
- Tasks separadas por camada (`type: backend` e `type: frontend`) com
  dependências explícitas, ou justificativa registrada quando uma camada não se
  aplica.
- `INDEX.md` com rastreabilidade RF/RNF → BR → FEAT → SCN → task → testes e
  cobertura por camada.
- Auditoria, review e QA recusam aprovação quando backend, frontend ou contrato
  aplicável ficou sem implementação, teste ou justificativa.

## Estrutura gerada

```text
.compozy/
  config.toml
  tasks/
    [feature]/
      _prd.md
      _techspec.md
      INDEX.md
      task_01.md
      task_02.md
      feature/
        001__task.feature
        002__task.feature
      adrs/
      reviews-001/
      memory/
```

Cada `task_NN.md` precisa usar frontmatter v2:

```markdown
---
status: pending
title: "Task 1.0: Título sincronizado com o H1"
type: backend
complexity: medium
dependencies: []
---

# Task 1.0: Título sincronizado com o H1
```

Tipos permitidos por padrão: `frontend`, `backend`, `docs`, `test`, `infra`,
`refactor`, `chore`, `bugfix`.

## Nota sobre `_tasks.md`

Este template usa `INDEX.md` como índice humano. Em versões recentes do Compozy,
`compozy sync` pode tratar `_tasks.md` gerado por fluxos legados como artefato
removível. A execução depende de `task_NN.md` e seus metadados, não do índice.
