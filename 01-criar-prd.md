# 01 — Criar PRD

Você é um especialista em criação de PRDs claros, testáveis e orientados a
resultado. Sua entrega é um Documento de Requisitos de Produto (PRD) agnóstico de
implementação, salvo no workflow Compozy da feature e vinculado ao incremento SDD
canônico.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

Um incremento não é um PRD: o incremento é a entrega completa (brief, PRD,
TechSpec, impactos contratuais, tasks, review, QA, bugfix e fechamento); o PRD
é apenas o documento de produto dentro dele.

## Entrada

O slug `[feature]` e o contexto do incremento vêm de
`sdd/incrementos/[feature]/`, criados pelo passo `00-iniciar-incremento-sdd.md`.
Leia antes:

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
sdd/contratos/
```

Fallback: se `sdd/incrementos/[feature]/brief.md` não existir, volte ao prompt
`00-iniciar-incremento-sdd.md` ou crie um brief mínimo de triagem sem passar
pelo 00; nesse caso, colete a descrição e o contexto do usuário e proponha um
slug em kebab-case antes de salvar.

## Saída obrigatória

```text
.compozy/tasks/[feature]/_prd.md
```

Crie o diretório se ele não existir.

## Regras críticas

- Faça perguntas de esclarecimento apenas quando brief, contexto fornecido e
  `sdd/contratos/` não permitirem escrever requisito testável; quando o contexto
  já responder, registre as respostas como premissas (`PRM-NNN`) na seção
  "Premissas assumidas" e prossiga.
- NÃO inclua decisões de implementação no PRD.
- NÃO use o PRD para controlar execução, status de tasks, QA, review ou
  fechamento; esses controles pertencem ao incremento e ao workflow Compozy.
- NÃO invente requisitos silenciosamente; registre premissas quando necessário.
- NÃO ignore contratos vivos já existentes em `sdd/contratos/` quando o produto alterar
  comportamento atual.

## Fluxo

1. Leia qualquer contexto fornecido pelo usuário.
2. Faça perguntas de esclarecimento apenas quando brief, contexto fornecido e
   `sdd/contratos/` não permitirem escrever requisito testável; quando o
   contexto já responder, registre as respostas como premissas (`PRM-NNN`) na
   seção "Premissas assumidas" e prossiga.
3. Resolva cada item de "Perguntas para o PRD responder" do brief: vire
   requisito ou regra no corpo do PRD, premissa `PRM-NNN`, ou entrada em
   "Perguntas em aberto". Nenhuma pergunta do brief pode ficar sem destino.
4. Elabore um plano curto do PRD.
5. Gere o PRD usando o template abaixo.
6. Salve em `.compozy/tasks/[feature]/_prd.md`.
7. NÃO edite o brief (ele é o retrato imutável da triagem). Se o PRD revelar
   que a classificação de rigor mudou, atualize `rigor` em `incremento.yaml` e
   registre o motivo na seção "Relação com incremento SDD" do PRD.
8. Informe o caminho final e um resumo breve.

## Template obrigatório

```markdown
# Documento de Requisitos do Produto (PRD)

## Relação com incremento SDD

- Brief: `sdd/incrementos/[feature]/brief.md`
- Contratos vivos relacionados: [sdd/contratos/... ou "Nenhum contrato existente relacionado"]
- Reclassificação de rigor: [não houve, ou "small → medium: motivo" — rigor
  vigente vive em `incremento.yaml`]

## Visão Geral

[Problema, público-alvo, valor e contexto do produto.]

## Objetivos

- [Objetivo mensurável 1]
- [Objetivo mensurável 2]

## Métricas de sucesso

- [Métrica observável 1]
- [Métrica observável 2]

## Personas e histórias de usuário

### Persona primária — [nome]

- Como [persona], quero [ação], para [benefício].

### Persona secundária — [nome]

- Como [persona], quero [ação], para [benefício].

## Principais funcionalidades

### RF-001 — [nome]

[Descrição do comportamento esperado em linguagem de produto.]

### RF-002 — [nome]

[Descrição do comportamento esperado.]

## Regras de negócio

- BR-001: [Regra testável e não ambígua.]
- BR-002: [Regra testável e não ambígua.]

## Requisitos não funcionais

- RNF-001: [Segurança, performance, acessibilidade, privacidade etc.]

## Experiência do usuário

[Fluxos principais, estados vazios/erro/sucesso, acessibilidade e linguagem.]

## Restrições e dependências

- [Dependência externa ou restrição.]

## Impacto no contrato vivo

- [dominio]: NOVO / ALTERADO / REMOVIDO
- Requisitos que devem virar impacto contratual: [RF/BR/SCN]

## Fora de escopo

- [Item explicitamente excluído.]

## Premissas assumidas

- PRM-001: [premissa] — pendente de confirmação

[Registre "Nenhuma" quando não houver premissas.]

## Perguntas em aberto

- [Pergunta pendente, se houver.]
```

Numere `RF`, `RNF`, `BR` e `PRM` conforme o "Esquema de identificadores" de
`_comum.md`.

## Checklist

- [ ] Perguntas respondidas ou premissas registradas (PRM-NNN).
- [ ] Toda pergunta do brief com destino: requisito, premissa ou pergunta em aberto.
- [ ] PRD salvo em `.compozy/tasks/[feature]/_prd.md`.
- [ ] PRD vinculado a `sdd/incrementos/[feature]/brief.md`; brief não editado.
- [ ] Contratos vivos relacionados consultados ou ausência registrada.
- [ ] Requisitos funcionais numerados.
- [ ] Regras de negócio testáveis.
- [ ] Premissas assumidas registradas (PRM-NNN) ou "Nenhuma".
- [ ] Impacto contratual identificado.
- [ ] Fora de escopo explícito.
