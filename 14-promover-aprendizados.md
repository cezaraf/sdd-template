# 14 — Promover aprendizados

Transforme evidências da entrega em melhorias permanentes do harness sem
poluir regras com casos isolados.

> Leia `_comum.md`, relatório de fechamento, bugs, review, QA, PR, deploy e
> incidentes relacionados.

## Objetivo

Decidir o que deve virar:

- contrato vivo;
- regra/policy/hook;
- skill;
- ADR;
- runbook;
- eval de regressão;
- métrica/alerta;
- nada, quando for caso pontual já resolvido.

## Saída

```text
sdd/aprendizados/YYYY-MM-DD-[feature].md
```

Opcionalmente atualize `sdd/evals/`, `sdd/governanca/`, skills ou runbooks.

## Entrada quantitativa

Leia as métricas do incremento antes de decidir:

```bash
sdd/governanca/sdd-metricas.sh [feature]
```

Use-as para separar percepção de evidência: retrabalho alto de especificação
(`reauditorias`), baixa aderência ao plano ou `P0`/`P1` recorrentes indicam
lacuna de harness, não azar. Aumento de autonomia (`assistido` →
`autonomo_ate_pr` → …) só se sustenta com série histórica em `sdd/metricas.csv`.

## Critérios de promoção

Promova quando houver:

- falha repetível ou cara;
- ambiguidade que gerou retrabalho;
- ação que deveria ter sido bloqueada deterministicamente;
- incidente de produção;
- divergência entre modelos/harnesses;
- conhecimento estável e reutilizável.

Não promova preferência pessoal ou detalhe específico sem recorrência.

## Relatório

```markdown
# Aprendizados — [feature]

## Sinais observados

| Evidência | Impacto | Recorrência |
| --- | --- | --- |

## Decisões

| Item | Destino | Mudança | Validação |
| --- | --- | --- | --- |

## Evals criadas/atualizadas

| EVAL | Falha que previne | Expectativa |
| --- | --- | --- |

## Policies/hooks/skills

## Métricas e operação

| Indicador | Valor | Leitura |
| --- | --- | --- |

Quando o aprendizado vier de incidente, registre também a faixa de controle
criada/ajustada em `sdd/governanca/watch.yaml` e a eval que passaria a
detectá-lo antes.

## Itens não promovidos

- [item e motivo]
```

Atualize `fase: aprendizado` apenas no histórico/relatório; o incremento
permanece `consolidado`.
