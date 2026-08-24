# 06 — Executar task

Execute uma task aprovada com escopo controlado e feedback rápido.

> Leia `_comum.md`, o contexto canônico, a auditoria, o plano e o código real.

## Pré-condições

- auditoria com `Status: PRONTO`;
- gate humano aprovado/dispensado quando exigido;
- `status: especificado` na primeira task ou `em_execucao` nas seguintes;
- dependências da task concluídas;
- base do plano compatível com o repositório atual.

Se a base mudou de forma material, rebaseie o plano e reexecute o passo 04.

## Seleção

Use a task informada ou a primeira `pending` com dependências `completed`.

Ao iniciar a primeira task:

```yaml
status: em_execucao
fase: implementacao
```

## Resumo antes de editar

```text
Task:
Base ref/SHA:
Rigor / risco / autonomia:
Contrato atual:
Impacto alvo:
RF/RNF / BR / FEAT / SCN / TST:
Arquivos esperados:
Contratos/dados afetados:
Riscos e sinais de parada:
Gates aplicáveis:
```

## Execução

1. Leia os arquivos afetados por completo.
2. Implemente a menor superfície coerente.
3. Respeite TechSpec, ADRs, impacto contratual e plano.
4. Não altere `sdd/contratos/`.
5. Para desvio de arquivo/arquitetura/contrato:
   - pare;
   - registre revisão do plano;
   - reexecute auditoria se material.
6. Escreva teste que cite cada `SCN-*`.
7. Rode feedback loops curtos durante a implementação.
8. Rode todos os gates reais antes de concluir.

## Enforcement

Antes de editar cada task:

```bash
sdd/governanca/sdd-guard.sh pre-implement [feature] task_NN
sdd/governanca/sdd-metricas.sh [feature] --marcar data_primeira_task  # só na primeira task
```

Depois de marcar subtasks e o frontmatter como concluídos, mas antes de declarar
a task encerrada:

```bash
sdd/governanca/sdd-guard.sh pre-complete [feature] task_NN
```

## Fechamento da task

Somente com DoD atendida:

- marque subtasks;
- marque apenas os checkboxes operacionais de `execucao.md`; mudança material de
  plano exige revisão e reauditoria;
- altere frontmatter para `status: completed`;
- atualize somente o status operacional no `INDEX.md`;
- registre comandos e evidências em `## Evidências produzidas` da task;
- rode `compozy tasks validate` e `compozy sync`.

Quando todas as tasks estiverem concluídas, mantenha `status: em_execucao` e
registre `fase: review` para trilhas com review, ou `fase: qa` quando o review
for dispensado.

## Git

Commit/push somente quando o gate registrado autorizar o escopo. Caso contrário,
deixe o working tree preparado e informe a evidência.
