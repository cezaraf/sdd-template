# 06 — Executar task

Este prompt é um guia para execução manual ou por agente. Quando possível, a
execução deve ser feita pelo Compozy:

```bash
compozy tasks run [feature] --ide codex --stream
```

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Seleção da task

Se o usuário fornecer uma task, execute essa task. Caso contrário, use a primeira
`task_NN.md` com `status: pending` cujas dependências estejam com
`status: completed`.

Ao iniciar a primeira task do incremento, atualize
`sdd/incrementos/[feature]/incremento.yaml` para `status: em_execucao`.

## Carga obrigatória de contexto

Leia o Contexto canônico do incremento (ver `_comum.md`) e, adicionalmente:

```text
.compozy/tasks/[feature]/auditoria-especificacao.md
.claude/rules/ ou AGENTS.md, se existirem
```

Obrigatoriedade de PRD/TechSpec por trilha: ver `_comum.md`.

Depois leia o código relevante antes de editar.

## Resumo obrigatório antes de implementar

```text
Task: task_NN — [título]
Incremento SDD: sdd/incrementos/[feature]
Contrato vivo relacionado: sdd/contratos/[dominio]/contrato.md
Impacto contratual: sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md
Feature: FEAT-XXX
Comportamento: [nome no impacto contratual]
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

- NÃO implemente sem `auditoria-especificacao.md` com `Status: PRONTO`. Se
  ausente ou com outro status, pare e execute `04-auditar-especificacao.md`.
- Implemente depois de planejar; não espere nova aprovação, salvo conflito real.
- Não implemente fora do escopo da task.
- Siga a política de git e as regras de segurança e testes de `_comum.md`.
- Não marque `status: completed` sem Definition of Done atendida (DoD do
  projeto ou fallback definido em `_comum.md`).
- Não altere `sdd/contratos/` fora do fechamento
  (`10-consolidar-contrato-vivo.md`); mudanças de comportamento entram em
  `sdd/incrementos/[feature]/impacto-contratual/`.
- Não considere uma task full-stack concluída se backend, frontend ou contrato
  entre camadas aplicável ficou sem implementação, teste ou justificativa.

## Implementação

1. Leia o código existente.
2. Altere a menor superfície coerente com a task.
3. Mantenha as decisões técnicas definidas na TechSpec. Se ela não existir,
   respeite as decisões registradas na task ou em ADR.
4. Respeite o impacto contratual como contrato comportamental do incremento.
5. Respeite validação, autorização, isolamento, auditoria e contratos.
6. Para task backend, implemente endpoints/serviços/persistência e contratos
   consumidos pelo frontend.
7. Para task frontend, implemente rotas/telas/estado e consumo do contrato
   backend real definido na TechSpec.
8. Atualize documentação afetada, mantendo `sdd/contratos/` para a etapa de fechamento.

## Testes obrigatórios

Para cada `SCN-*`:

- deve haver teste automatizado que cite o ID;
- o `.feature` deve ser ligado por runner BDD estrito quando o projeto usar BDD;
- quando aplicável, deve haver verificação de contrato API/cliente e de fluxo UI;
- serviços externos e mocks: siga as regras de segurança e testes de `_comum.md`.

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
2. Atualize `sdd/incrementos/[feature]/execucao.md` marcando a task correspondente.
3. Altere `status: completed` no frontmatter de `task_NN.md`.
4. Atualize a linha da task em `.compozy/tasks/[feature]/INDEX.md`.
5. Rode:

```bash
compozy tasks validate --name [feature]
compozy sync --name [feature]
```

Se restarem tasks com `status: pending`, informe a próxima elegível e repita
este prompt. Ao concluir todas, siga para 07/08 conforme o Mapa de rota por
trilha (`00-iniciar-incremento-sdd.md`).

## Resultado esperado

Informe:

- task executada;
- arquivos modificados;
- impactos contratuais usados ou ajustados;
- cenários cobertos;
- comandos executados e resultado;
- limitações ou testes não executados.
