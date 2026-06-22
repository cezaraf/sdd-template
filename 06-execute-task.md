# 06 — Executar task

Este prompt é um guia para execução manual ou por agente. Quando possível, a
execução deve ser feita pelo Compozy:

```bash
compozy tasks run [feature] --ide codex --stream
```

Toda comunicação e documentação devem estar em português brasileiro, salvo
nomes oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Seleção da task

Se o usuário fornecer uma task, execute essa task. Caso contrário, use a primeira
`task_NN.md` com `status: pending` cujas dependências estejam com
`status: completed`.

## Carga obrigatória de contexto

Leia integralmente:

```text
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/_techspec.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
.claude/rules/ ou AGENTS.md, se existirem
```

Depois leia o código relevante antes de editar.

## Resumo obrigatório antes de implementar

```text
Task: task_NN — [título]
Feature: FEAT-XXX
Requisitos: RF/RNF-XXX
Regras de negócio: BR-XXX
Cenários: SCN-XXX
Camada da task:
Componentes afetados:
Backend afetado:
Frontend afetado:
Contratos afetados:
Contrato backend/frontend:
Dependências:
Riscos:
```

## Regras críticas

- Implemente depois de planejar; não espere nova aprovação, salvo conflito real.
- Não implemente fora do escopo da task.
- Não use serviços externos reais em testes automatizados.
- Não exponha segredos em logs, fixtures, snapshots ou relatórios.
- Não faça commit, push ou PR sem autorização explícita.
- Não marque `status: completed` sem Definition of Done verde.
- Não considere uma task full-stack concluída se backend, frontend ou contrato
  entre camadas aplicável ficou sem implementação, teste ou justificativa.

## Implementação

1. Leia o código existente.
2. Altere a menor superfície coerente com a task.
3. Mantenha a arquitetura definida na TechSpec.
4. Respeite validação, autorização, isolamento, auditoria e contratos.
5. Para task backend, implemente endpoints/serviços/persistência e contratos
   consumidos pelo frontend.
6. Para task frontend, implemente rotas/telas/estado e consumo do contrato
   backend real definido na TechSpec.
7. Atualize documentação afetada.

## Testes obrigatórios

Para cada `SCN-*`:

- deve haver teste automatizado que cite o ID;
- o `.feature` deve ser ligado por runner BDD estrito quando o projeto usar BDD;
- quando aplicável, deve haver verificação de contrato API/cliente e de fluxo UI;
- mocks somente nas fronteiras externas.

Rode os comandos reais do projeto, conforme AGENTS/README:

```bash
npm run lint
npm run typecheck
npm run build
npm test
npm run test:e2e
```

Adapte ao package manager do projeto.

## Fechamento

Só depois dos gates verdes:

1. Atualize checkboxes internas da task, se houver.
2. Altere `status: completed` no frontmatter de `task_NN.md`.
3. Rode:

```bash
compozy tasks validate --name [feature]
compozy sync --name [feature]
```

## Resultado esperado

Informe:

- task executada;
- arquivos modificados;
- cenários cobertos;
- comandos executados e resultado;
- limitações ou testes não executados.
