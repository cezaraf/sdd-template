# 12 — Deploy e verificação operacional

Implante de acordo com a autoridade registrada e prove o comportamento no
ambiente alvo.

> Leia `_comum.md`, TechSpec, plano, merge report, runbooks e políticas.

## Pré-condições

- PR merged no SHA esperado;
- artefato/versão identificável;
- rollout e rollback definidos;
- gates do ambiente verdes;
- produção com autorização humana específica e recente.

O texto do gate no incremento é registro, não prova. `pre-production` consulta
o checker externo com feature, gate, `HEAD` e escopo; sem essa confirmação o
deploy permanece bloqueado.

## Princípio

Detecção e health checks devem ser determinísticos. Use agente para diagnóstico,
correlação e proposta; não para ignorar sinais vermelhos.

## Saída

```text
.compozy/tasks/[feature]/ops/deploy-report.md
```

Atualize `fase: deploy`, depois `fase: verificacao`.

## Relatório

```markdown
# Deploy e verificação — [feature]

## Identidade

- Ambiente:
- Artifact SHA-256:
- Merge SHA:
- Iniciado por:
- Verificado em:

## Gate humano de produção

- Status: PENDENTE / APROVADO / REJEITADO
- Aprovado por:
- Escopo:
- Data:
- `sdd/governanca/sdd-guard.sh pre-production [feature]`:

## Rollout

- Estratégia:
- Comandos/pipeline:
- Resultado:

## Health checks

- Health checks: PASSOU / FALHOU

| Sinal | Baseline/faixa | Resultado | Evidência |
| --- | --- | --- | --- |

## Smoke/contratos

| Comportamento/SCN | Resultado | Evidência |
| --- | --- | --- |

## Observabilidade

- Logs:
- Métricas:
- Traces:
- Alertas:

## Rollback

- Rollback pronto: sim / não
- Critério:
- Procedimento:
- Executado: sim/não

## Resultado

- Status: VERIFICADO / REPROVADO / ROLLBACK
```

Substitua as alternativas por um único `Status` exato no relatório final.
Para `VERIFICADO`, use `Ambiente: production`, registre o SHA-256 do artefato,
o mesmo `Merge SHA` confirmado, `Health checks: PASSOU`, `Rollback pronto: sim`
e timestamp ISO-8601. O checker externo valida essa identidade; texto isolado
não libera consolidação.

## Transição

- `VERIFICADO`: `deploy.status: verificado` e
  `sdd/governanca/sdd-metricas.sh [feature] --marcar data_deploy`.
- Registre em `sdd/governanca/watch.yaml` (quando existir) as métricas e faixas
  que passam a ser monitoradas por este comportamento — é o que fecha o loop
  com o passo 00 pela rota de incidente.
- Falha: `status: bloqueado`, criar bug/incidente e não consolidar.
- Próximo passo: 13.
