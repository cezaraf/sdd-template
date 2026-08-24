# 13 — Consolidar contrato vivo

Conclua o incremento somente depois que o comportamento estiver confirmado no
alvo declarado.

> Leia `_comum.md` e todos os artefatos, inclusive PR/merge/deploy quando
> aplicáveis.

## Pré-condições

- todas as tasks concluídas;
- auditoria `PRONTO`;
- review/QA aplicáveis aprovados;
- sem P0/P1;
- `status: validado`;
- `alvo_contrato: branch`: merge confirmado;
- `alvo_contrato: producao`: deploy `VERIFICADO`;
- `alvo_contrato: local`: dispensa explícita e justificativa;
- working tree limpo ou ponto de restauração autorizado.

Verifique-as com o gate determinístico antes de qualquer escrita:

```bash
sdd/governanca/sdd-guard.sh pre-consolidate [feature]
```

Quando qualquer condição falhar, bloqueie sem alterar `sdd/contratos/`. O gate
emite um atestado efêmero em `.git/sdd-state`, ligado ao `HEAD` e apenas aos
domínios presentes em `impacto-contratual/`. Depois do sucesso, atualize
`fase: fechamento`; fase e status são necessários, mas sem o atestado o hook
continua bloqueando. O token expira rapidamente e deixa de valer quando o
incremento sai de `status: validado` ou é arquivado.

## Saídas

```text
sdd/contratos/[dominio]/contrato.md
sdd/incrementos/[feature]/relatorio-fechamento.md
sdd/historico/YYYY-MM-DD-[feature]/
sdd/historico/YYYY-MM-DD-[feature]/compozy-tasks/
```

## Aplicação

- `NOVO`: adicionar comportamento e cenários observáveis.
- `ALTERADO`: substituir o comportamento inteiro de forma coerente.
- `REMOVIDO`: remover somente comportamento existente e autorizado.
- Não copie detalhes de implementação para contrato vivo.
- Não ajuste o contrato para esconder divergência; volte e corrija a entrega.

## Contrato vivo

```markdown
# Contrato vivo — [Domínio]

## Propósito

## Comportamentos

### Comportamento: [nome]

O sistema deve [comportamento observável].

#### Cenário: [nome]

- DADO ...
- QUANDO ...
- ENTÃO ...
```

## Relatório

```markdown
# Relatório de consolidação — [feature]

## Resumo

- Status: CONSOLIDADO / BLOQUEADO
- Rigor / risco / autonomia:
- Alvo do contrato:
- Base / merge / versão:

## Impactos aplicados

| Domínio | NOVO | ALTERADO | REMOVIDO | Contrato final |
| --- | --- | --- | --- | --- |

## Evidências

| Task/SCN/TST | Review | QA | PR/merge | Deploy |
| --- | --- | --- | --- | --- |

## Gates e autorizações

## Métricas

[Saída de `sdd-metricas.sh [feature]`: lead times, retrabalho e aderência ao plano.]

## Exceções e riscos residuais

## Histórico
```

## Fechamento

1. rode `sdd/governanca/sdd-guard.sh pre-consolidate [feature]`;
2. atualize somente `fase: fechamento` no incremento ativo;
3. aplique os impactos autorizados nos domínios atestados;
4. registre `metricas.data_consolidado` e anexe as métricas ao relatório:
   `sdd/governanca/sdd-metricas.sh [feature] --marcar data_consolidado` e
   `sdd/governanca/sdd-metricas.sh [feature] --csv`;
5. gere o relatório e rode
   `sdd/governanca/sdd-metricas.sh [feature] --atualizar-relatorio`;
6. atualize `status: consolidado`, encerrando imediatamente a janela;
7. mova incremento e workflow para histórico;
8. rode `git diff --check` e gates rápidos;
9. commit/push somente com autorização;
10. siga para 14.
