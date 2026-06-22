# 05 — Criar governança local de execução

Você é responsável por criar ou atualizar a governança local do projeto:
`AGENTS.md`, regras, skills e documentação operacional necessárias para que
agentes executem tasks Compozy com segurança e consistência.

Toda comunicação e documentação devem estar em português brasileiro, salvo
nomes oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Entradas obrigatórias

```text
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/_techspec.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
```

## Saídas esperadas

Crie ou atualize, conforme o projeto:

```text
AGENTS.md
CLAUDE.md
.claude/rules/
.claude/skills/
.mcp.json
```

## Regras críticas

- Não altere comportamento de produto.
- Não crie segredo em arquivo.
- Não prometa CI se o projeto só tem gate local.
- Não aponte agentes para caminhos legados quando o workflow canônico é
  `.compozy/tasks/[feature]`.

## Conteúdo mínimo de AGENTS.md / CLAUDE.md

Inclua:

- descrição curta do projeto;
- stack e comandos reais;
- Definition of Done;
- estrutura Compozy canônica;
- mapa de backend, frontend, contratos compartilhados e comandos de teste por
  camada, quando o projeto for full-stack;
- como validar e executar:

```bash
compozy tasks validate --name [feature]
compozy sync --name [feature]
compozy tasks run [feature] --ide codex --stream
```

- regras de idioma/documentação;
- regras de segurança e segredos;
- regra de leitura obrigatória de `_prd.md`, `_techspec.md`, `INDEX.md`,
  `task_NN.md` e `.feature`;
- política de git: sem commit/push/PR sem autorização explícita.

## Rules recomendadas

Crie regras curtas e normativas para:

- idioma;
- leitura de contexto;
- precedência e conflitos;
- dependências Compozy;
- limite de escopo;
- arquitetura e contratos;
- cobertura backend/frontend e contratos entre camadas;
- persistência e versionamento;
- RBAC/isolamento, se aplicável;
- segredos/dados sensíveis;
- sanitização/SSRF/XSS, se aplicável;
- integração com IA, se aplicável;
- estratégia de testes;
- BDD estrito;
- review/QA;
- registro e correção de bugs;
- Definition of Done;
- documentação e git;
- observabilidade;
- acessibilidade.

## Skills locais recomendadas

Crie apenas quando o projeto precisar:

- `gerar-teste-bdd-estrito`
- `validar-definition-of-done`
- `auditoria-de-acessibilidade`
- skills de domínio específicas do projeto

Cada skill deve ter `SKILL.md`, escopo claro, entradas, passos, saídas e
critérios de conclusão.

## MCP

Configure MCPs somente quando necessários. Para documentação atual de libs,
prefira Context7 se disponível. Nunca grave segredos em `.mcp.json`; use env vars.

## Checklist

- [ ] AGENTS.md/CLAUDE.md apontam para `.compozy/tasks/[feature]`.
- [ ] Rules citam `task_NN.md` e frontmatter Compozy.
- [ ] Governança orienta tasks backend/frontend e validação de contratos quando aplicável.
- [ ] Skills têm instruções executáveis e curtas.
- [ ] Nenhum segredo foi escrito.
- [ ] `compozy tasks validate --name [feature]` permanece verde.
