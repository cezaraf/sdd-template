# 11 — Validar PR e merge

Acompanhe checks, reviews e mudanças do PR até ele estar apto para merge.

> Leia `_comum.md`, pacote do PR, diff atual, checks e comentários.

## Regras

- Não considere o review local substituto dos checks/reviews do PR.
- Qualquer mudança de código após review/QA invalida as evidências afetadas;
  reexecute 07/08 de forma proporcional.
- Resolva comentários com causa e evidência, não por concordância automática.
- P0/P1, checks vermelhos ou threads bloqueantes impedem merge.
- Merge exige gate humano explícito, mesmo em autonomia alta.
- O registro em `incremento.yaml` não comprova a origem do gate. O checker
  externo configurado em `authority.check_command` deve validar review/ator,
  escopo e head SHA antes de `pre-merge` ficar verde.

## Saída

```text
.compozy/tasks/[feature]/pr/merge-report.md
```

## Relatório

```markdown
# Validação de PR e merge — [feature]

## PR

- Número/URL:
- Base branch:
- Head SHA validado:

## Checks

| Check | Resultado | Evidência |
| --- | --- | --- |

## Reviews e threads

| Item | Decisão | Alteração | Revalidação |
| --- | --- | --- | --- |

## Gate humano de merge

- Requerido: sim
- Status: PENDENTE / APROVADO / REJEITADO
- Aprovado por:
- Escopo:
- Data:

## Gates técnicos

- P0/P1:
- Review reexecutado:
- QA reexecutado:
- `sdd/governanca/sdd-guard.sh pre-merge [feature]`:

## Resultado

- Status: PRONTO_PARA_MERGE / BLOQUEADO / MERGED
- Merge SHA:
```

No arquivo final, mantenha um único `Status` exato. Depois do merge, use
`MERGED` e registre um SHA verificável; não deixe a lista de alternativas.
O guard exige que `Head SHA validado` seja o mesmo `Evidence SHA` de review/QA,
que `Merge SHA` contenha esse commit e que o checker externo confirme a origem
do merge. Texto sem esses vínculos não comprova merge.

## Transição

- Pronto, mas sem aprovação: manter `fase: merge`.
- Merge realizado: `pr.status: merged`, registrar SHA e rodar
  `sdd/governanca/sdd-metricas.sh [feature] --marcar data_merge`.
- `alvo_contrato: branch`: próximo passo 13.
- `alvo_contrato: producao`: próximo passo 12.
