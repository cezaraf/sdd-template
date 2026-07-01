# Regras comuns do fluxo SDD

Este arquivo é a fonte única das regras compartilhadas pelos prompts `00` a `10`.
Todo prompt do fluxo exige a leitura deste arquivo antes da execução. Ele é
instalado junto com os prompts no projeto-alvo.

## Idioma

Toda comunicação e documentação em português brasileiro (pt-BR), exceto nomes
oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Terminologia

- **Incremento**: a entrega completa — brief, PRD, TechSpec, impactos
  contratuais, tasks, review, QA, bugfix e fechamento. O PRD é apenas o
  documento de produto dentro do incremento.
- **`[feature]`**: slug do incremento em kebab-case, usado em caminhos e
  comandos Compozy. Não confundir com `FEAT-NNN` (funcionalidade no PRD) nem
  com arquivos `.feature` (Gherkin).
- **Brief** (`sdd/incrementos/[feature]/brief.md`): retrato imutável da triagem
  — origem, intenção, classificação inicial, capacidades candidatas e perguntas
  para o PRD. Congela após o passo 00; nunca contém requisitos, regras,
  métricas ou escopo detalhado (pertencem ao PRD) nem rastreia artefatos
  (pertence a `incremento.yaml` e `execucao.md`). Analogia: o brief é a ficha
  de abertura do chamado; o PRD é o diagnóstico. O valor do brief é exatamente
  não mudar — responder, meses depois, "por que este incremento existiu e por
  que foi classificado assim".
- **Contrato vivo** (`sdd/contratos/[dominio]/contrato.md`): fonte de verdade
  do comportamento atual e consolidado do sistema, por domínio.
- **Impacto contratual**
  (`sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md`):
  mudança de comportamento planejada por esta entrega. Formato canônico
  definido em `03-criar-tasks.md`.

## Contexto canônico do incremento

Salvo instrução específica do prompt, leia integralmente:

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
sdd/incrementos/[feature]/execucao.md
sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
sdd/contratos/[dominio]/contrato.md
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/_techspec.md        (quando exigida pela trilha)
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
```

Cada prompt lista apenas as entradas adicionais específicas dele.

## Artefatos obrigatórios por trilha

PRD é obrigatório para todos os incrementos, inclusive `small` (enxuto).
TechSpec é obrigatória para `medium` e `large`. Para `small`, a TechSpec pode
ser ausente somente quando `_prd.md`, impactos contratuais, tasks e `.feature`
cobrem o contrato de execução. O `brief.md` serve apenas como triagem do
incremento e nunca substitui o PRD.

## Escala de severidade (P0–P3)

Escala única para auditoria (04), review (07), QA (08) e bugs (09):

- **P0 — bloqueante**: corrupção de dados, falha de segurança, contrato vivo
  violado, perda funcional sem workaround.
- **P1 — alta**: comportamento contratual incorreto, cenário `SCN-*` reprovado,
  sem workaround razoável.
- **P2 — média**: defeito com workaround; registrar decisão.
- **P3 — baixa**: cosmético ou melhoria.

`P0` e `P1` abertos bloqueiam a consolidação (10). `P2` e `P3` não bloqueiam,
mas exigem registro.

## Definition of Done (fallback)

Quando `AGENTS.md` ou `.claude/rules/` não definirem DoD própria, uma task só
está concluída quando:

1. os critérios de sucesso da `task_NN.md` foram atendidos;
2. todo `SCN-*` da task tem teste automatizado verde citando o ID;
3. os gates do projeto passaram (lint, typecheck, build, testes, E2E aplicável);
4. `compozy tasks validate --name [feature]` passou;
5. nenhuma regra crítica foi violada (contratos, segredos, escopo).

## Esquema de identificadores

Numeração sequencial a partir de `001`, única dentro do incremento:

- `RF-NNN` / `RNF-NNN`: requisitos funcionais / não funcionais (PRD).
- `BR-NNN`: regra de negócio (PRD).
- `PRM-NNN`: premissa assumida na ausência de resposta do usuário (PRD).
- `FEAT-NNN`: funcionalidade de produto derivada do PRD; mapeia um ou mais RF;
  listada no `INDEX.md`.
- `SCN-NNN`: cenário BDD; não reinicia a numeração por arquivo `.feature`; cada
  `SCN` vive em exatamente um `.feature` e é citado por pelo menos um teste.
- `TST-NNN`: teste planejado, derivado de cenário ou contrato.
- `REVIEW-NNN`: issue de review (07).
- `BUG-NNN`: bug registrado (08/09).

Cadeia de rastreabilidade: `RF/RNF → BR → FEAT → Comportamento → SCN → task → testes`.

## Ciclo de vida do incremento

Campo `status` do `incremento.yaml`:

```text
proposto → especificado → em_execucao → consolidado
                     (qualquer etapa) → bloqueado
```

- `proposto`: criado pelo passo 00.
- `especificado`: definido pelo passo 04 quando a auditoria resulta `PRONTO`.
- `em_execucao`: definido pelo passo 06 ao iniciar a primeira task.
- `consolidado`: definido pelo passo 10 antes de mover para `sdd/historico/`.
- `bloqueado`: definido por 04 ou 10 quando um gate impede o avanço.

## Contratos vivos

Não altere `sdd/contratos/` fora do fechamento (`10-consolidar-contrato-vivo.md`);
mudanças de comportamento entram em
`sdd/incrementos/[feature]/impacto-contratual/`.

## Política de git

Sem commit, push ou PR sem autorização explícita do usuário.

## Segurança e testes

- Não use serviços externos reais em testes automatizados; mocks somente nas
  fronteiras externas.
- Não exponha segredos em logs, fixtures, snapshots ou relatórios.
- Não suprima lint, typecheck ou teste para "passar".
