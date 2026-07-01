# 05 — Criar governança local de execução

Você é responsável por criar ou atualizar a governança local do projeto:
`AGENTS.md`, regras, skills e documentação operacional necessárias para que
agentes executem incrementos SDD e tasks Compozy com segurança e consistência.
Este passo é setup de governança do projeto, não etapa do fluxo por incremento.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Modos de execução

Escolha um:

- **Bootstrap do projeto** (sem `[feature]`): primeira execução, antes de
  qualquer incremento existir. Cria a governança a partir da realidade do
  repositório.
- **Atualização por incremento** (com `[feature]`): um incremento revelou
  lacuna de governança (regra ausente, comando desatualizado, camada nova).
  Atualiza a governança usando os artefatos do incremento como evidência.

## Entradas por modo

Bootstrap do projeto:

```text
sdd/contratos/                       (se existir)
README/scripts/manifests do projeto  (stack e comandos reais)
estrutura de diretórios do repositório
```

Atualização por incremento — leia também:

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

Condicional — quando existir (trilhas `medium` e `large`; ver `_comum.md`):

```text
.compozy/tasks/[feature]/_techspec.md
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
- Não permita atualização direta de `sdd/contratos/` durante implementação comum; a
  consolidação do contrato vivo acontece no fechamento.

## Conteúdo mínimo de AGENTS.md / CLAUDE.md

Inclua:

- descrição curta do projeto;
- stack e comandos reais;
- Definition of Done;
- estrutura SDD canônica: `sdd/contratos`, `sdd/incrementos`, `sdd/historico`;
- estrutura Compozy canônica;
- regra de precedência entre contrato vivo, impacto contratual e task executável;
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
  `task_NN.md`, `.feature`, `sdd/incrementos/[feature]` e contratos vivos relacionados;
- política de fechamento: só `10-consolidar-contrato-vivo.md` consolida impactos em
  `sdd/contratos/`;
- política de git (frase canônica de `_comum.md`): "Sem commit, push ou PR
  sem autorização explícita do usuário."

## Rules recomendadas

Formato: um arquivo kebab-case por rule em `.claude/rules/` (ex.: `idioma.md`,
`contratos-vivos.md`), com no máximo ~10 linhas, frase imperativa e exceção
quando houver. O conteúdo das rules pode citar `_comum.md` como fonte: os
projetos-alvo recebem `_comum.md` junto na instalação.

Obrigatórias:

- idioma;
- leitura de contexto;
- precedência de artefatos;
- contratos vivos;
- fechamento;
- política de git (frase canônica de `_comum.md`);
- Definition of Done.

Condicionais — crie somente quando o gatilho existir no projeto:

- dependências Compozy — quando tasks declararem dependências no frontmatter;
- trilhas de rigor — quando o projeto usar mais de uma trilha (`small`,
  `medium`, `large`);
- limite de escopo — quando houver histórico de alteração fora da task ou
  incrementos `large`;
- TechSpec e decisões técnicas — quando a trilha exigir TechSpec (`medium`
  e `large`);
- cobertura backend/frontend e contratos entre camadas — quando o projeto
  for full-stack;
- persistência e versionamento — quando houver migrações ou dados
  versionados;
- RBAC/isolamento — quando houver múltiplos papéis ou multi-tenancy;
- segredos/dados sensíveis — quando o projeto lidar com credenciais ou
  dados pessoais;
- sanitização/SSRF/XSS — quando houver entrada de usuário renderizada ou
  chamadas a URLs externas;
- integração com IA — quando o produto consumir LLMs ou serviços de IA;
- estratégia de testes — quando os gates do projeto divergirem do padrão de
  `_comum.md`;
- BDD estrito — quando os cenários `SCN-*` forem o contrato de teste do
  projeto;
- review/QA — quando houver critérios de review/QA além dos prompts 07/08;
- registro e correção de bugs — quando houver rastreador próprio ou
  convenções extras de registro;
- documentação — quando o projeto exigir documentação além dos artefatos
  SDD;
- observabilidade — quando logs, métricas ou tracing forem exigidos em
  produção;
- acessibilidade — quando houver UI voltada a usuário final.

## Skills locais recomendadas

Crie apenas quando o projeto precisar:

- `gerar-teste-bdd-estrito`
- `validar-definition-of-done`
- `validar-impacto-contratual`
- `consolidar-incremento-sdd`
- `auditoria-de-acessibilidade`
- skills de domínio específicas do projeto

Cada skill deve ter `SKILL.md`, escopo claro, entradas, passos, saídas e
critérios de conclusão.

## MCP

Configure MCPs somente quando necessários. Para documentação atual de libs,
prefira Context7 se disponível. Nunca grave segredos em `.mcp.json`; use env vars.

## Checklist

- [ ] AGENTS.md/CLAUDE.md apontam para `.compozy/tasks/[feature]`.
- [ ] AGENTS.md/CLAUDE.md explicam `sdd/contratos`, `sdd/incrementos` e `sdd/historico`.
- [ ] Rules impedem atualização direta de `sdd/contratos/` antes do fechamento.
- [ ] Rules citam `task_NN.md` e frontmatter Compozy.
- [ ] Governança orienta tasks backend/frontend e validação de contratos quando aplicável.
- [ ] Skills têm instruções executáveis e curtas.
- [ ] Nenhum segredo foi escrito.
- [ ] No modo atualização por incremento: `compozy tasks validate --name [feature]`
      permanece verde (não se aplica ao bootstrap).
