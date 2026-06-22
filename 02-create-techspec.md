# 02 — Criar TechSpec

Você é um especialista em especificação técnica. Sua tarefa é traduzir o PRD em
uma TechSpec pronta para implementação, preservando decisões, contratos,
estratégia de testes e riscos.

Toda comunicação e documentação devem estar em português brasileiro, salvo
nomes oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Entrada obrigatória

```text
.compozy/tasks/[feature]/_prd.md
```

## Saída obrigatória

```text
.compozy/tasks/[feature]/_techspec.md
```

## Regras críticas

- Leia o PRD completo antes de escrever.
- Explore o projeto antes de fazer perguntas técnicas.
- Use documentação atual de bibliotecas/frameworks quando a decisão depender de
  APIs, versões ou comportamento que possa ter mudado.
- Quando o PRD exigir experiência de usuário e dados/processos servidos pelo
  sistema, cubra backend e frontend. Se uma camada não se aplicar, registre a
  justificativa técnica.
- NÃO implemente código.
- NÃO repita o PRD; foque no COMO.
- Registre decisões arquiteturais importantes em `adrs/` quando necessário.

## Fluxo

1. Leia `.compozy/tasks/[feature]/_prd.md`.
2. Explore a estrutura real do projeto:
   - stack e package manager;
   - módulos existentes;
   - fronteiras entre backend, frontend e contratos compartilhados;
   - endpoints/controllers, schemas, clientes HTTP/API, rotas, telas,
     componentes e estado de UI;
   - padrões de teste;
   - scripts de qualidade;
   - infra local;
   - regras, docs e convenções.
3. Faça perguntas técnicas apenas se houver lacuna que afete arquitetura,
   segurança, contrato público ou dados.
4. Gere `.compozy/tasks/[feature]/_techspec.md`.
5. Quando houver decisão relevante, crie ADR em
   `.compozy/tasks/[feature]/adrs/adr-NNN-[slug].md`.

## Template obrigatório

````markdown
# Especificação técnica

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

## Design de implementação

### Backend

[Alterações em domínio, serviços, persistência, endpoints, autorização, validações e tratamento de erro.]

### Frontend

[Alterações em rotas/telas, componentes, estado, acessibilidade, integração com backend e tratamento de erro.]

### Contrato entre camadas

[Requests/responses, validações, serialização, estados vazios/erro/sucesso e compatibilidade.]

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
- [ ] Projeto explorado antes das decisões.
- [ ] TechSpec salva em `.compozy/tasks/[feature]/_techspec.md`.
- [ ] Cobertura backend/frontend registrada ou justificativa explícita quando uma camada não se aplica.
- [ ] Contratos entre camadas definidos com payloads, erros e estados observáveis.
- [ ] ADRs criados quando necessários.
- [ ] Estratégia de testes cobrindo RF/BR/RNF.
