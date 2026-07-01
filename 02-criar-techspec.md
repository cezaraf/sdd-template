# 02 — Criar TechSpec

Você é um especialista em especificação técnica. Sua tarefa é traduzir o PRD em
uma TechSpec pronta para implementação, preservando decisões, contratos,
estratégia de testes, riscos e decisões arquiteturais do incremento SDD.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Entrada obrigatória

```text
sdd/incrementos/[feature]/brief.md
.compozy/tasks/[feature]/_prd.md
```

## Saída obrigatória

```text
.compozy/tasks/[feature]/_techspec.md
```

## Regras críticas

- Leia o PRD completo antes de escrever.
- Leia `sdd/incrementos/[feature]/brief.md` e contratos vivos relacionados antes de
  desenhar a solução.
- Explore o projeto antes de fazer perguntas técnicas.
- Use documentação atual de bibliotecas/frameworks quando a decisão depender de
  APIs, versões ou comportamento que possa ter mudado.
- Quando o PRD exigir experiência de usuário e dados/processos servidos pelo
  sistema, cubra backend e frontend. Se uma camada não se aplicar, registre a
  justificativa técnica.
- NÃO implemente código.
- NÃO repita o PRD; foque no COMO.
- Não altere `sdd/contratos/` fora do fechamento
  (`10-consolidar-contrato-vivo.md`); mudanças de comportamento entram em
  `sdd/incrementos/[feature]/impacto-contratual/`.
- Registre decisões arquiteturais em `.compozy/tasks/[feature]/adrs/`. Crie ADR
  quando a decisão: (a) escolher entre 2+ alternativas viáveis de
  arquitetura/biblioteca/padrão; (b) alterar contrato público ou esquema de
  dados; (c) introduzir dependência ou tecnologia de custo irreversível.

## Fluxo

1. Leia `sdd/incrementos/[feature]/brief.md` e
   `.compozy/tasks/[feature]/_prd.md`.
2. Leia `sdd/contratos/` para entender comportamento atual consolidado.
3. Explore a estrutura real do projeto:
   - stack e package manager;
   - módulos existentes;
   - fronteiras entre backend, frontend e contratos compartilhados;
   - endpoints/controllers, schemas, clientes HTTP/API, rotas, telas,
     componentes e estado de UI;
   - padrões de teste;
   - scripts de qualidade;
   - infra local;
   - regras, docs e convenções.
4. Faça perguntas técnicas apenas se houver lacuna que afete arquitetura,
   segurança, contrato público ou dados.
5. Gere `.compozy/tasks/[feature]/_techspec.md`.
6. Crie ADR em `.compozy/tasks/[feature]/adrs/adr-NNN-[slug].md` quando a
   decisão: (a) escolher entre 2+ alternativas viáveis de
   arquitetura/biblioteca/padrão; (b) alterar contrato público ou esquema de
   dados; (c) introduzir dependência ou tecnologia de custo irreversível.

## Template obrigatório

````markdown
# Especificação técnica

## Relação com incremento SDD

- Brief: `sdd/incrementos/[feature]/brief.md`
- Contratos vivos consultados: [sdd/contratos/...]
- Impactos contratuais previstos: [sdd/incrementos/[feature]/impacto-contratual/[dominio]/contrato.md]

## Resumo executivo

[Visão técnica da abordagem e principais decisões.]

## Arquitetura do sistema

### Componentes

- **[Componente]** — [responsabilidade].

### Fluxo de dados

[Descrição de entradas, transformações, persistência e saídas.]

### Fronteiras backend/frontend

- **Backend** — [módulos, endpoints, jobs, persistência, permissões e erros.]
- **Frontend** — [rotas/telas, componentes, estado, cliente de API e estados de UX.]
- **Contratos compartilhados** — [DTOs, schemas, eventos, versionamento e compatibilidade.]

## Arquitetura de implementação

### Backend

[Alterações em domínio, serviços, persistência, endpoints, autorização, validações e tratamento de erro.]

### Frontend

[Alterações em rotas/telas, componentes, estado, acessibilidade, integração com backend e tratamento de erro.]

### Contrato entre camadas

[Requests/responses, validações, serialização, estados vazios/erro/sucesso e compatibilidade.]

### Estratégia de impacto contratual

- **[dominio]** — NOVO / ALTERADO / REMOVIDO: [requisitos e cenários que devem mudar.]

### Interfaces e contratos

```typescript
[Interfaces relevantes, se aplicável.]
```

### Modelos de dados

[Entidades, relações, índices e regras de integridade.]

### Endpoints / comandos / jobs

[Contratos públicos e internos.]

## Integrações

- **[Serviço]** — [auth, timeout, retry, erros, mocks de teste].

## Segurança, privacidade e isolamento

[Ameaças relevantes, autorização, tenancy, segredos, validação.]

## Observabilidade

[Logs, métricas, tracing, auditoria e correlação.]

## Estratégia de testes

### Unitários

- [Comportamento isolado.]
- [Backend: regras de domínio, serviços, validações e autorização.]
- [Frontend: componentes, estado, formatação, acessibilidade e tratamento de erro.]

### Integração

- [Contratos, banco, filas, dependências locais.]
- [Contrato backend/frontend: cliente, payloads, status codes, erros e compatibilidade.]

### E2E / BDD

- [Jornadas e cenários críticos.]
- [Fluxos full-stack UI -> API -> persistência/efeito observável, quando aplicável.]

## Sequenciamento de implementação

1. [Primeira capacidade independente.]
2. [Segunda capacidade independente.]

## Riscos e mitigação

- **Risco:** [descrição]. **Mitigação:** [ação].

## ADRs

- [ADR-001 — título] ou "Nenhum ADR necessário".
````

## Checklist

- [ ] PRD lido integralmente.
- [ ] Brief e contratos vivos relacionados lidos.
- [ ] Projeto explorado antes das decisões.
- [ ] TechSpec salva em `.compozy/tasks/[feature]/_techspec.md`.
- [ ] Decisões arquiteturais registradas na TechSpec.
- [ ] Impactos contratuais previstos por domínio.
- [ ] Cobertura backend/frontend registrada ou justificativa explícita quando uma camada não se aplica.
- [ ] Contratos entre camadas definidos com payloads, erros e estados observáveis.
- [ ] ADRs criados para toda decisão que atende ao critério objetivo
      (alternativas viáveis, contrato público/esquema de dados ou dependência
      de custo irreversível).
- [ ] Estratégia de testes cobrindo RF/BR/RNF.
