# 09 — Corrigir bugs e achados

Corrija causa raiz, crie regressão e revalide as superfícies afetadas.

> Leia `_comum.md`, bugs, issues de review e contexto canônico.

## Entrada

```text
.compozy/tasks/[feature]/bugs.md
.compozy/tasks/[feature]/reviews-001/issue_*.md
```

## Saída

```text
.compozy/tasks/[feature]/bugfix-report.md
```

## Regras

- Reproduza antes de corrigir quando possível.
- Identifique se a causa está em requisito, contrato, plano, backend, frontend,
  dados, integração, teste ou operação.
- Corrija o artefato certo, não apenas o sintoma.
- Toda correção precisa de teste que falharia sem ela.
- Não consolide contrato vivo.
- Mudança material de escopo/contrato exige revisão do plano e auditoria.
- Atualize issue/bug com causa, correção, regressão e evidência.

## Relatório

```markdown
# Relatório de bugfix

## Resumo

- Bugs/achados tratados:
- Corrigidos:
- Pendentes:
- Revisão do plano necessária:

## Detalhes

| ID | Severidade | Causa raiz | Camada | Correção | Regressão | Status |
| --- | --- | --- | --- | --- | --- | --- |

## Gates

- lint:
- build:
- testes:
- E2E:
- compozy:

## Riscos restantes
```

## Roteamento

- Reexecute 07 para issues de review.
- Reexecute 08 para bugs/SCN.
- Só retorne a `status: validado` após review/QA aprovados.
