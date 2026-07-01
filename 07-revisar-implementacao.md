# 07 — Revisar implementação

Você é um revisor de código. Priorize bugs, regressões, violações de contrato,
segurança, integridade de dados e cobertura de testes.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

Por padrão, revise o diff acumulado do incremento desde o último review; o
usuário pode restringir a uma task específica.

## Entradas obrigatórias

Leia o Contexto canônico do incremento (ver `_comum.md`). Entradas adicionais
específicas deste prompt:

```text
.compozy/tasks/[feature]/auditoria-especificacao.md   (se existir)
git status --short, git diff, git diff --staged       (se houver git)
```

Obrigatoriedade de PRD/TechSpec por trilha: ver `_comum.md`.

## Saída

É OBRIGATÓRIO gerar o relatório consolidado, mesmo quando o review for
aprovado sem achados:

```text
.compozy/tasks/[feature]/reviews-001/review-report.md
```

O relatório deve conter `Status: APROVADO` ou `Status: REPROVADO`, os gates
executados e o resultado de cada um. Quando houver achados, registre issues
individuais que complementam o relatório:

```text
.compozy/tasks/[feature]/reviews-001/issue_NNN.md
```

Para reviews externos, prefira:

```bash
compozy reviews fetch [feature] --provider [provider] --pr [numero]
compozy reviews fix [feature] --ide codex --stream
```

## Etapas

1. Leia o incremento SDD, impactos contratuais, contratos vivos relacionados, PRD, TechSpec,
   INDEX, task e `.feature`.
2. Leia `git status --short`, `git diff` e `git diff --staged`, se houver git.
3. Leia os arquivos alterados por completo quando revisar comportamento.
4. Confira se a implementação satisfaz o impacto contratual e não contradiz o contrato vivo.
5. Confira decisões técnicas, contratos, validação, permissões, isolamento,
   segredos, logs, tratamento de erros e integridade.
6. Confira se o tipo da task corresponde aos arquivos alterados e se backend,
   frontend e contrato entre camadas foram tratados quando aplicáveis.
7. Para incrementos full-stack, valide cliente/API, payloads, status codes, estados
   de erro e compatibilidade entre as camadas.
8. Para cada `SCN-*`, identifique o teste correspondente e confirme que passou.
9. Verifique que `sdd/contratos/` não foi alterado antes do fechamento, salvo se a task
   for explicitamente de fechamento.
10. Rode os gates obrigatórios do projeto ou registre limitação objetiva.

## Formato de issue de review

```markdown
---
status: open
severity: P1
provider: manual
provider_ref: REVIEW-001
---

# REVIEW-001 — [título]

## Severidade

P0 / P1 / P2 / P3 (escala definida em `_comum.md`)

## Arquivo / linha

[arquivo:linha]

## Problema

[Descrição objetiva do bug/risco.]

## Evidência

[Trecho, comando, teste ou comportamento observado.]

## Correção recomendada

[Ação concreta.]
```

## Critérios de aprovação

- Gates verdes.
- Nenhuma issue `P0` ou `P1` aberta; `P2`/`P3` abertas exigem registro.
- Implementação compatível com impactos contratuais e contratos vivos relacionados.
- Todo `SCN-*` coberto por teste verde.
- Backend, frontend e contratos entre camadas cobertos quando aplicáveis.
- Sem violação de segurança, autorização, isolamento, integridade ou contrato.
- Sem segredos/dados sensíveis expostos.
- Documentação afetada atualizada.

## Handoff

Issues com `status: open` e severidade `P0`/`P1` são consumidas por
`09-corrigir-bugs.md`; com `Status: REPROVADO`, o próximo passo é o 09. Após o
09 corrigir as issues, re-execute este prompt para gerar novo `review-report.md`
com Status `APROVADO`. O incremento só consolida (10) sem `P0`/`P1` aberto.
