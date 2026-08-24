# 10 — Preparar pull request

Prepare um PR como pacote verificável de intenção, plano, implementação e
evidência.

> Leia `_comum.md`, o incremento completo, diff, histórico git e gates.

## Pré-condições

- `status: validado`;
- review/QA exigidos aprovados;
- sem P0/P1;
- working tree conhecido;
- base ref/SHA e branch alvo confirmados.

## Autoridade

Sem autorização explícita para commit/push/PR:

- não execute essas ações;
- gere apenas o pacote e a descrição pronta.

Com gate de PR compatível e aprovado, crie branch/commits/PR somente no
escopo registrado. O gate de PR não autoriza merge.

## Saídas

```text
.compozy/tasks/[feature]/pr/pr-package.md
.compozy/tasks/[feature]/pr/pr-body.md
```

Atualize `fase: pr`.

## Pacote

```markdown
# Pacote de PR — [feature]

## Intenção

## Mudanças

## Contratos afetados

## Plano versus diff

| Item planejado | Evidência no diff | Desvio |
| --- | --- | --- |

## Rastreabilidade

| RF/BR/SCN/TST | Implementação | Teste |
| --- | --- | --- |

## Gates

## Review e QA

## Migração / rollout / rollback

## Riscos residuais

## Autorizações

## Commits / branch / PR
```

## PR body

Inclua resumo, motivação, escopo, fora de escopo, testes, evidências, riscos,
rollback e checklist de revisão.

## Transição

- PR aberto: registrar número, URL, head SHA e `pr.status: aberto`.
- Sem autorização: registrar `pr.status: pacote_pronto`.
- Próximo passo: 11.
