# 09 — Corrigir bugs

Você é responsável por corrigir bugs registrados, atacando causa raiz,
adicionando regressão e revalidando o fluxo afetado.

Toda comunicação e documentação devem estar em português brasileiro, salvo
nomes oficiais de tecnologias, comandos, identificadores e campos de protocolo.

## Entradas obrigatórias

```text
.compozy/tasks/[feature]/bugs.md
.compozy/tasks/[feature]/_prd.md
.compozy/tasks/[feature]/_techspec.md
.compozy/tasks/[feature]/INDEX.md
.compozy/tasks/[feature]/task_NN.md
.compozy/tasks/[feature]/feature/NNN__task.feature
```

## Saída

```text
.compozy/tasks/[feature]/bugfix-report.md
```

## Regras críticas

- Corrija causa raiz, não sintoma.
- Identifique se a causa está no backend, frontend ou contrato entre camadas;
  não corrija apenas o consumidor quando o contrato ou provedor estiver errado.
- Todo bug corrigido precisa de teste de regressão que falharia sem a correção.
- Não suprima lint/typecheck/teste para passar.
- Não use serviços externos reais em teste automatizado.
- Não exponha segredos.
- Não faça commit, push ou PR sem autorização explícita.

## Fluxo

1. Leia `bugs.md`; se não houver bug aberto, informe e não altere código.
2. Leia PRD, TechSpec, task e `.feature` relacionados.
3. Reproduza o problema com teste falhando ou fluxo controlado quando possível.
4. Corrija na camada correta.
5. Adicione regressão.
6. Rode gates do projeto.
7. Atualize cada bug com status e evidência.
8. Gere `bugfix-report.md`.

## Planejamento por bug

```text
BUG:
Severidade:
Task/Cenário:
Camada afetada: backend/frontend/contrato/outro
Componente provável:
Causa raiz:
Arquivos a modificar:
Estratégia de correção:
Teste de regressão:
Riscos:
```

## Atualização de bugs.md

```markdown
- Status: Corrigido
- Causa raiz: [descrição]
- Correção aplicada: [descrição]
- Testes de regressão: [nomes]
- Validação: [comandos]
```

## Relatório final

```markdown
# Relatório de Bugfix

## Resumo

- Total de bugs tratados:
- Bugs corrigidos:
- Bugs pendentes:
- Testes de regressão criados:

## Detalhes

| Bug | Severidade | Camada | Status | Causa raiz | Correção | Testes |
| --- | --- | --- | --- | --- | --- | --- |

## Validação

- Lint:
- Typecheck:
- Build:
- Testes:
- E2E:

## Riscos restantes

[listar ou "nenhum"]
```

## Fechamento

Se a correção completar uma task:

```bash
compozy tasks validate --name [feature]
compozy sync --name [feature]
```
