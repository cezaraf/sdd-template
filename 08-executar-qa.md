# 08 — QA da task

Você é responsável por validar a entrega como consumidor do sistema, exercitando
UI, API, CLI ou efeitos observáveis definidos pela task.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

## Entradas obrigatórias

Leia o Contexto canônico do incremento (ver `_comum.md`).

Obrigatoriedade de PRD/TechSpec por trilha: ver `_comum.md`.

## Saída

```text
.compozy/tasks/[feature]/qa/task_NN-qa-report.md
```

Se encontrar bugs, registre:

```text
.compozy/tasks/[feature]/bugs.md
```

## Etapas

1. Leia o incremento SDD, impactos contratuais, o contrato vivo relacionado, PRD, TechSpec, task e
   cenários `SCN-*`.
2. Monte checklist de QA por cenário:
   - fluxo;
   - entrada/payload;
   - resultado esperado;
   - cobertura por camada: UI, API, CLI ou efeito observável aplicável;
   - contrato frontend/backend, quando houver;
   - Comportamento no impacto contratual;
   - compatibilidade com comportamento já descrito em `sdd/contratos/`;
   - verificação de segurança/isolamento;
   - acessibilidade/performance, quando aplicável;
   - evidência.
3. Prepare ambiente local conforme o projeto. Estratégia, em ordem de
   preferência: testes E2E automatizados existentes > chamadas diretas à API
   (curl/cliente HTTP) > CLI > inspeção manual assistida da UI. Consulte
   README/scripts do repositório para subir o ambiente.
4. Execute fluxos por UI/API/CLI.
5. Para incremento full-stack, valide ao menos uma jornada UI -> API -> efeito
   observável/persistência para cada cenário aplicável.
6. Rode gates relevantes.
7. Registre bugs com reprodução objetiva e severidade P0–P3 (ver `_comum.md`).

Válvula de escape: se um cenário não puder ser exercitado (ambiente não sobe,
UI inacessível ao agente, dependência externa indisponível), registre limitação
objetiva no relatório — motivo e o que seria necessário — e marque o cenário
como NAO_VERIFICADO (nunca como PASSOU).

## Template do relatório

```markdown
# Relatório de QA — task_NN

## Resumo

- Data:
- Status: APROVADO / REPROVADO
- Cenários verificados:
- Bugs encontrados:

## Ambiente

- Comandos executados:
- Dados de teste:
- Dependências mockadas:

## Cenários verificados

| Comportamento | Cenário | Fluxo | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| [Comportamento] | SCN-XXX | | PASSOU/FALHOU/NAO_VERIFICADO | |

## Impactos contratuais

| Domínio | Impacto | Verificação | Resultado |
| --- | --- | --- | --- |

## Cobertura backend/frontend

| Camada | Verificação | Resultado | Evidência |
| --- | --- | --- | --- |

## Segurança e isolamento

| Verificação | Resultado | Observações |
| --- | --- | --- |

## Acessibilidade / performance

| Verificação | Resultado | Observações |
| --- | --- | --- |

## Bugs

| Bug | Severidade | Status |
| --- | --- | --- |

## Conclusão

[Parecer final.]
```

## Template de bug

```markdown
## BUG-XXX — [título]

- Severidade: P0/P1/P2/P3
- Task relacionada:
- Cenário relacionado:
- Ambiente:
- Passos para reproduzir:
- Resultado esperado:
- Resultado observado:
- Evidência:
- Status: Aberto
```

## Critérios de aprovação

QA só aprova quando todos os `SCN-*` aplicáveis passaram, impactos contratuais foram
validados como comportamento observável, backend/frontend e contratos entre
camadas aplicáveis foram exercitados, gates relevantes estão verdes, não há bug
bloqueante, e segurança/acessibilidade/performance aplicáveis foram verificadas.

## Roteamento

Se o Status for REPROVADO, registre os bugs em `bugs.md` e acione
`09-corrigir-bugs.md`. Após as correções, re-execute este QA para os cenários
reprovados e gere novo relatório. O incremento só segue para
`10-consolidar-contrato-vivo.md` com QA APROVADO.
