# 08 — Executar QA

Valide a entrega como consumidor do sistema, não apenas como leitor do código.

> Rode em contexto isolado. Leia `_comum.md`, contratos, plano, tasks, cenários,
> review e ambiente do projeto.

## Saídas

```text
.compozy/tasks/[feature]/qa/task_NN-qa-report.md
.compozy/tasks/[feature]/bugs.md               (quando houver bug)
```

Atualize `fase: qa`.

## Estratégia

Preferência:

1. E2E automatizado existente;
2. API/CLI/runner real;
3. UI assistida;
4. inspeção limitada, registrada como `NAO_VERIFICADO`.

Nunca transforme incapacidade de executar em aprovação.

## Checklist por cenário

- entrada e pré-condições;
- fluxo UI/API/CLI;
- efeito observável/persistência;
- contrato entre camadas;
- segurança/isolamento;
- acessibilidade/desempenho quando aplicável;
- evidência reproduzível;
- comportamento atual e alvo.

## Relatório

```markdown
# Relatório de QA — [feature/task]

## Resumo

- Status: APROVADO / REPROVADO
- Ambiente:
- Evidence SHA: [mesmo commit da implementação usado pelo review]
- Limitações:

## Cenários

| Comportamento | SCN | TST | Fluxo | Resultado | Evidência |
| --- | --- | --- | --- | --- | --- |

## Cobertura por superfície

| Superfície | Verificação | Resultado | Evidência |
| --- | --- | --- | --- |

## Segurança / acessibilidade / desempenho

| Verificação | Resultado | Evidência |
| --- | --- | --- |

## Bugs

| BUG | Severidade | Status |
| --- | --- | --- |
```

Resultados válidos: `PASSOU`, `FALHOU`, `NAO_VERIFICADO`.

No relatório final, substitua `APROVADO / REPROVADO` por um único valor exato.
Qualquer cenário `NAO_VERIFICADO` impede `APROVADO`.
Review e QA devem apontar para o mesmo `Evidence SHA`. Mudança de implementação
depois desse commit invalida ambos e exige nova execução independente.

Em `bugs.md`, cada entrada deve começar por `## BUG-NNN` e conter exatamente:

```markdown
- Severidade: P0
- Status: aberto
```

Severidades válidas são `P0` a `P3`; status pode usar maiúsculas/minúsculas,
mas heading ou campos malformados fazem o gate falhar fechado.

## Métricas

Quando review e QA estiverem aprovados e não houver `P0`/`P1` aberto, a entrega
vira `validado`. Registre o marco e deixe o driver propor o próximo passo:

```bash
sdd/governanca/sdd-metricas.sh [feature] --marcar data_validado
sdd/governanca/sdd-fluxo.sh [feature]        # --run aplica a transição
```

## Transição

- Bug/P0/P1/SCN crítico não verificado: `REPROVADO`, seguir para 09.
- Review e QA aprovados, sem P0/P1:
  `status: validado`, `fase: pr` quando houver PR, senão `fase: validacao`.
- `fase: fechamento` só começa no passo 13, depois de `pre-consolidate`; estado
  sozinho não autoriza escrita no contrato vivo.
