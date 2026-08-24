# 07 — Revisar implementação

Você é um revisor independente. Priorize bugs, regressões, contratos, segurança,
integridade, operação e provas.

> Rode em contexto isolado. Leia `_comum.md`, o plano aprovado, contratos,
> tasks, testes e o diff completo.

## Saídas

```text
.compozy/tasks/[feature]/reviews-001/review-report.md
.compozy/tasks/[feature]/reviews-001/issue_NNN.md
```

Atualize `fase: review`.

## Verificações

- diff versus arquivos e limites do plano;
- comportamento versus impacto contratual;
- contrato vivo não alterado antecipadamente;
- RF/BR/SCN/TST cobertos;
- contratos backend/frontend e compatibilidade;
- segurança, autorização, tenancy, segredos e integridade;
- migração, rollback, observabilidade e tratamento de falhas;
- testes verdes e capazes de falhar sem a implementação;
- desvio de escopo ou implementação acidental;
- documentação afetada.

## Issue

```markdown
---
status: open
severity: P1
provider: manual
provider_ref: REVIEW-001
---

# REVIEW-001 — [título]

## Arquivo / linha

## Problema

## Evidência

## Impacto

## Correção recomendada
```

## Relatório

Inclua:

```markdown
# Review de implementação — [feature]

## Resumo

- Status: APROVADO / REPROVADO
- Evidence SHA: [commit exato da implementação revisada]

## Parecer do agente

## Escopo do diff

## Gates executados

## Achados P0–P3

## Cobertura por SCN/TST

| Comportamento | SCN | TST | Evidência | Resultado |
| --- | --- | --- | --- | --- |

## Desvios do plano

## Riscos residuais
```

Substitua a alternativa de `Status` por um único valor exato. Não mantenha
`APROVADO / REPROVADO` no relatório final.

`Evidence SHA` deve apontar para o commit da implementação, já com tasks e
testes concluídos. Alteração de código após esse SHA invalida o review; somente
relatórios e estado operacional do incremento podem ser acrescentados.

## Critério

- P0/P1 aberto: `REPROVADO`, seguir para 09.
- P2/P3: registrar decisão.
- Aprovado: `fase: qa`.
- Review não autoriza merge.
