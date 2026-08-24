# 02 — Criar TechSpec

Você traduz o PRD em arquitetura implementável, preservando contratos, riscos e
estratégia de prova.

> Leia `_comum.md`, brief, PRD, contratos vivos e explore o código real antes de
> decidir.

## Saídas

```text
.compozy/tasks/[feature]/_techspec.md
.compozy/tasks/[feature]/adrs/adr-NNN-[slug].md   (quando aplicável)
```

## Regras

- Não implemente código.
- Não repita o PRD; foque no `COMO`.
- Use documentação atual quando APIs/versões puderem ter mudado.
- Cubra backend, frontend e contratos entre camadas quando aplicáveis.
- Registre timeout, retry, idempotência, autorização, isolamento, observabilidade
  e rollback quando relevantes.
- Crie ADR quando houver alternativas viáveis, mudança de contrato público,
  esquema de dados ou dependência de custo irreversível.
- Não altere `sdd/contratos/`; descreva o impacto ativo.

## Template

```markdown
# Especificação técnica

## Contexto

- Brief:
- PRD:
- Contratos vivos:
- Impactos previstos:

## Resumo da abordagem

[Arquitetura e principais decisões.]

## Código existente explorado

- Módulos/pacotes:
- Padrões existentes:
- Comandos de qualidade:
- Restrições encontradas:

## Componentes e responsabilidades

- **[componente]** — [responsabilidade]

## Fluxo de dados

[Entrada → validação → domínio → persistência/integração → saída.]

## Backend

[Domínio, serviços, persistência, endpoints, jobs, autorização e erros.]

## Frontend

[Rotas, telas, componentes, estado, acessibilidade e erros.]

## Contratos entre camadas

[Requests, responses, eventos, schemas, status codes, compatibilidade e versão.]

## Dados e migração

[Entidades, índices, integridade, rollout, backfill e rollback.]

## Integrações

- **[serviço]** — auth, timeout, retry, idempotência, circuit breaker e mocks.

## Segurança e privacidade

[Ameaças, validação, RBAC, tenancy, segredos e auditoria.]

## Observabilidade e operação

[Logs, métricas, traces, alertas, health checks e runbook.]

## Estratégia de testes

- Unitários:
- Integração:
- Contrato:
- BDD/E2E:
- Performance/segurança:
- Verificação pós-deploy:

## Sequenciamento

1. [capacidade independente]

## Riscos e mitigação

- **Risco:** ... **Mitigação:** ... **Sinal de rollback:** ...

## Alternativas descartadas

- [alternativa e motivo]

## ADRs

- [ADR ou "Nenhum"]
```

## Checklist

A TechSpec deve permitir que outro agente implemente sem redescobrir
arquitetura, contratos, riscos ou provas.
