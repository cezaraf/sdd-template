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

## Preparação arquitetural (antes de editar)

Apresente o mapa mínimo: módulo, pastas, componentes e responsabilidades
existentes, arquivos previstos e caminho de execução. Justifique qualquer
abstração nova por necessidade atual. Em decisão arquitetural material,
interrompa e valide a escolha com o usuário; não peça aprovação a cada teste.

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
2. Siga Outside-In TDD quando houver comportamento testável:
   - **RED:** crie primeiro o teste derivado de cenário aprovado, execute-o e
     registre a falha esperada (não confunda erro de infraestrutura com RED);
   - **GREEN:** implemente a menor superfície coerente até o teste passar;
   - **REFACTOR:** simplifique mantendo toda a suíte verde.
   Para tarefas não testáveis por código, justifique exceção e outra prova.
3. Respeite TechSpec, ADRs, impacto contratual e plano.
4. Não altere `sdd/contratos/`.
5. Para desvio de arquivo/arquitetura/contrato:
   - pare;
   - registre revisão do plano;
   - reexecute auditoria se material.
6. Vincule cada `SCN-*` ao teste automatizado correspondente e não altere
   critérios de aceite apenas para fazer passar o código.
7. Rode feedback loops curtos durante a implementação.
8. Rode todos os gates reais antes de concluir.
9. Compare arquivos previstos versus reais e registre um tour curto do fluxo:
   ponto de entrada, componentes percorridos, responsabilidades e onde começar
   a depurar uma falha típica. Não omita desvios nem decisões relevantes.

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
- registre comandos e evidências RED/GREEN/REFACTOR, arquivos reais,
  decisões e roteiro de diagnóstico em `## Evidências produzidas` da task;
- rode `compozy tasks validate` e `compozy sync`.

Quando todas as tasks estiverem concluídas, mantenha `status: em_execucao` e
registre `fase: review` para trilhas com review, ou `fase: qa` quando o review
for dispensado.

## Git

Commit/push somente quando o gate registrado autorizar o escopo. Caso contrário,
deixe o working tree preparado e informe a evidência.
