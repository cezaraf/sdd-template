# 01 — Criar PRD

Você transforma o brief em requisitos de produto claros, observáveis e
agnósticos de implementação.

> Leia `_comum.md`, `incremento.yaml`, `brief.md` e contratos vivos relacionados.

## Saída

```text
.compozy/tasks/[feature]/_prd.md
```

Atualize `fase: especificacao` em `incremento.yaml`.

## Regras

- Não implemente código nem escolha tecnologia.
- Toda pergunta do brief deve virar requisito/regra, premissa `PRM-*` ou
  pergunta aberta.
- Não invente requisito silenciosamente.
- Diferencie comportamento atual, comportamento alvo e fora de escopo.
- Reclassifique rigor/risco quando novas evidências exigirem; registre o motivo.
- Requisito sem resultado observável não está pronto.

## Template

```markdown
# Documento de Requisitos do Produto

## Relação com o incremento

- Brief: `sdd/incrementos/[feature]/brief.md`
- Contratos vivos consultados:
- Reclassificação: [não houve ou mudança + motivo]

## Problema e valor

[Quem sofre, qual problema existe e por que vale resolver.]

## Resultado pretendido

- [resultado mensurável]

## Métricas de sucesso

- [métrica, fonte e janela]

## Personas e jornadas

- Como [persona], quero [ação], para [benefício].

## Requisitos funcionais

### RF-001 — [nome]

[Comportamento observável.]

## Regras de negócio

- BR-001: [regra testável]

## Requisitos não funcionais

- RNF-001: [segurança, desempenho, acessibilidade, privacidade etc.]

## Experiência do usuário

[Fluxos, estados vazio/erro/sucesso, linguagem e acessibilidade.]

## Impacto no contrato vivo

- [dominio]: NOVO / ALTERADO / REMOVIDO
- Requisitos relacionados:

## Restrições e dependências

- [item]

## Fora de escopo

- [item]

## Premissas

- PRM-001: [premissa] — pendente de confirmação

## Perguntas abertas

- [pergunta e impacto se não respondida]
```

## Checklist

- Objetivos e métricas observáveis.
- RF/RNF/BR numerados.
- Impacto contratual identificado.
- Fora de escopo explícito.
- Premissas visíveis.
- Nenhuma decisão técnica indevida.
