# 10 — Consolidar incremento e atualizar contrato vivo

Você é responsável por concluir um incremento SDD aplicando seus impactos contratuais na
fonte de verdade `sdd/contratos/` e preservando o histórico completo em
`sdd/historico/`.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Entradas obrigatórias

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
sdd/incrementos/[feature]/execucao.md
sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
```

Leia também, quando existirem:

```text
.compozy/tasks/[feature]/_techspec.md
.compozy/tasks/[feature]/auditoria-especificacao.md
.compozy/tasks/[feature]/reviews-001/review-report.md
.compozy/tasks/[feature]/qa/
.compozy/tasks/[feature]/bugs.md
.compozy/tasks/[feature]/bugfix-report.md
sdd/contratos/[dominio]/contrato.md
```

## Saídas obrigatórias

```text
sdd/contratos/[dominio]/contrato.md
sdd/incrementos/[feature]/relatorio-fechamento.md
sdd/historico/YYYY-MM-DD-[feature]/
sdd/historico/YYYY-MM-DD-[feature]/compozy-tasks/
```

## Regras críticas

- NÃO consolide se houver task pendente, issue de review ou bug com severidade
  P0/P1 aberto (escala de `_comum.md`), auditoria `PRECISA_AJUSTES`/`BLOQUEADO`,
  review-report ou QA com Status REPROVADO ou gate obrigatório vermelho.
- NÃO altere `sdd/contratos/` sem aplicar impacto explícito de
  `sdd/incrementos/[feature]/impacto-contratual/`.
- Cada impacto contratual segue o template canônico de `03-criar-tasks.md`.
  Inclua apenas seções aplicáveis; não deixe seções vazias.
- NÃO delete o contexto do incremento; mova a pasta inteira para `sdd/historico/`.
- NÃO esconda divergência entre implementação e contrato. Se houver divergência,
  volte para ajustar impacto contratual, task, código ou QA antes do fechamento.
- Para `Comportamentos alterados`, substitua o comportamento inteiro de forma coerente,
  mantendo cenários observáveis.
- Para `Comportamentos removidos`, remova apenas comportamento existente e registrado;
  se o comportamento não existir no contrato vivo, bloqueie o fechamento.

## Pré-condições

Antes de consolidar, confirme:

- working tree limpo ou ponto de restauração criado (commit autorizado do
  estado pré-consolidação). Sem working tree limpo e sem autorização para o
  commit de restauração, BLOQUEIE antes de alterar `sdd/contratos/` ou mover
  qualquer pasta, e peça a autorização ao usuário;
- todas as `task_NN.md` estão com `status: completed`;
- `compozy tasks validate --name [feature]` passou;
- gates do projeto passaram ou há exceção explícita aceita;
- `auditoria-especificacao.md` existe com Status `PRONTO`;
- `review-report.md` existe com Status `APROVADO` quando o passo 07 fez parte
  da trilha (Mapa de rota do 00); se o review foi dispensado na trilha `small`,
  registre a dispensa no relatório de fechamento;
- QA com Status `APROVADO` nos cenários aplicáveis;
- bugs bloqueantes estão corrigidos ou fora de escopo por decisão explícita;
- impactos contratuais representam o comportamento realmente implementado.

## Formato do contrato vivo

Use este padrão para `sdd/contratos/[dominio]/contrato.md`:

```markdown
# Contrato vivo — [Domínio]

## Propósito

[Descrição curta do domínio/capacidade.]

## Comportamentos

### Comportamento: [nome]

O sistema deve [comportamento observável].

#### Cenário: [nome]

- DADO [contexto]
- QUANDO [ação]
- ENTÃO [resultado observável]
```

## Fluxo

1. Leia todos os artefatos do incremento.
2. Valide pré-condições e bloqueie se algo estiver pendente; ao bloquear,
   atualize `incremento.yaml` para `status: bloqueado` e registre o motivo no
   relatório de fechamento.
3. Para cada domínio em `sdd/incrementos/[feature]/impacto-contratual/`, leia o contrato vivo
   correspondente em `sdd/contratos/[dominio]/contrato.md`.
4. Aplique `NOVO`, `ALTERADO` e `REMOVIDO` com edição textual clara e sem perder
   cenários observáveis.
5. Crie ou atualize índice humano em `sdd/contratos/INDEX.md` quando o incremento criar
   novo domínio ou reorganizar contratos.
6. Gere `sdd/incrementos/[feature]/relatorio-fechamento.md`.
7. Atualize `incremento.yaml` para `status: consolidado`.
8. Rode `compozy tasks validate --name [feature]` (antes de mover qualquer
   pasta).
9. Mova `sdd/incrementos/[feature]/` para `sdd/historico/YYYY-MM-DD-[feature]/`.
10. Mova também `.compozy/tasks/[feature]/` para
    `sdd/historico/YYYY-MM-DD-[feature]/compozy-tasks/` (inclui `_prd.md`,
    `_techspec.md`, `INDEX.md`, `task_NN.md`, `feature/`, `adrs/`,
    `auditoria-especificacao.md`, `reviews-001/`, `qa/`, `bugs.md`,
    `bugfix-report.md`).
11. Sincronize a remoção do workflow ativo que apontava para a pasta movida
    (`compozy sync --name [feature]` ou o comando equivalente do projeto); se a
    despublicação não for suportada, registre a pendência no
    `relatorio-fechamento.md`.
12. Rode as validações pós-movimentação (`git diff --check` e gates rápidos).
13. Solicite autorização explícita para um commit atômico
    "consolida incremento [feature]" cobrindo `sdd/contratos/`,
    `sdd/historico/` e remoções.

## Validações finais

```bash
compozy tasks validate --name [feature]
git diff --check
```

Rode `compozy tasks validate` antes de mover `.compozy/tasks/[feature]/`;
`git diff --check` após as movimentações. Rode também os gates reais do
projeto quando forem rápidos e relevantes.

## Template de `relatorio-fechamento.md`

```markdown
# Relatório de consolidação — [feature]

## Resumo

- Data:
- Status: CONSOLIDADO / BLOQUEADO
- Incremento:
- Rigor:

## Impactos contratuais aplicados

| Domínio | NOVO | ALTERADO | REMOVIDO | Contrato final |
| --- | --- | --- | --- | --- |

## Evidência de implementação

| Task | Status | Cenários | Testes/gates |
| --- | --- | --- | --- |

## Review e QA

- Auditoria:
- Review:
- QA:
- Bugs:

## Decisões e exceções

- [decisão ou "Nenhuma"]

## Arquivo histórico

- `sdd/historico/YYYY-MM-DD-[feature]/`
```

## Resultado esperado

Informe:

- contratos vivos atualizados;
- incremento consolidado;
- validações executadas e resultado;
- qualquer pendência que bloqueou o fechamento.
