# 09 — Corrigir bugs

Você é responsável por corrigir bugs registrados, atacando causa raiz,
adicionando regressão e revalidando o fluxo afetado.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Entradas obrigatórias

```text
.compozy/tasks/[feature]/bugs.md                  (se existir)
.compozy/tasks/[feature]/reviews-001/issue_*.md   (com `status: open`)
```

Issues de review `P0`/`P1` abertas são consumidas aqui. Leia também o Contexto
canônico do incremento (ver `_comum.md`).

Obrigatoriedade de PRD/TechSpec por trilha: ver `_comum.md`.

## Saída

```text
.compozy/tasks/[feature]/bugfix-report.md
```

## Regras críticas

- Corrija causa raiz, não sintoma.
- Identifique se a causa está no backend, frontend ou contrato entre camadas;
  não corrija apenas o consumidor quando o contrato ou provedor estiver errado.
- Identifique se a causa é código, teste, impacto contratual, TechSpec ou requisito
  ambíguo; corrija o artefato correto.
- Todo bug corrigido precisa de teste de regressão que falharia sem a correção.
- Não altere `sdd/contratos/` fora do fechamento (`10-consolidar-contrato-vivo.md`);
  ajuste o impacto ativo em `sdd/incrementos/[feature]/impacto-contratual/`.
- Siga a política de git e as regras de segurança e testes de `_comum.md`.

## Fluxo

1. Leia `bugs.md` e as issues de review com `status: open`; se não houver bug
   nem issue aberta, informe e não altere código.
2. Leia o incremento SDD, impactos contratuais, o contrato vivo, PRD, TechSpec, task e `.feature`
   relacionados.
3. Reproduza o problema com teste falhando ou fluxo controlado quando possível.
4. Corrija na camada correta ou ajuste o artefato de especificação ativo quando
   a causa for ambiguidade/erro de contrato.
5. Adicione regressão.
6. Rode gates do projeto.
7. Atualize cada bug com status e evidência; ao corrigir issue de review,
   atualize o frontmatter da issue para `status: fixed` com evidência.
8. Gere `bugfix-report.md`.

## Planejamento por bug

```text
BUG:
Severidade: [P0|P1|P2|P3] (escala em `_comum.md`)
Task/Cenário:
Camada afetada: backend/frontend/contrato/outro
Componente provável:
Artefato SDD afetado:
Causa raiz:
Arquivos a modificar:
Estratégia de correção:
Teste de regressão:
Riscos:
```

## Atualização de bugs.md

```markdown
- Status: Corrigido
- Causa raiz: [descrição]
- Correção aplicada: [descrição]
- Impacto contratual atualizado: [sim/não/caminho]
- Testes de regressão: [nomes]
- Validação: [comandos]
```

## Relatório final

```markdown
# Relatório de Bugfix

## Resumo

- Total de bugs tratados:
- Bugs corrigidos:
- Bugs pendentes:
- Testes de regressão criados:

## Detalhes

| Bug | Severidade | Camada | Status | Causa raiz | Correção | Testes |
| --- | --- | --- | --- | --- | --- | --- |

## Contratos e impactos

- Impactos contratuais ajustados:
- Divergências resolvidas:

## Validação

- Lint:
- Typecheck:
- Build:
- Testes:
- E2E:

## Riscos restantes

[listar ou "nenhum"]
```

## Fechamento

Após as correções, re-execute `08-executar-qa.md` para os cenários reprovados.
Quando as correções tratarem issues de review, re-execute também
`07-revisar-implementacao.md` para gerar novo `review-report.md` com Status
`APROVADO`. O incremento só segue para `10-consolidar-contrato-vivo.md` com QA
e review aprovados e sem `P0`/`P1` aberto.

Se a correção completar uma task, atualize também a linha dela no `INDEX.md` e
rode:

```bash
compozy tasks validate --name [feature]
compozy sync --name [feature]
```
