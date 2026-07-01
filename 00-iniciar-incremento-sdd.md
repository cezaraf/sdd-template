# 00 — Iniciar incremento SDD

Você é responsável por iniciar um incremento SDD canônico, escolhendo o nível de
rigor adequado e criando a pasta versionada da entrega antes de qualquer
implementação.

> Leia `_comum.md` (neste diretório) antes de executar este prompt. Ele define
> idioma, terminologia, contexto canônico, severidade P0–P3, Definition of Done,
> identificadores, ciclo de status, política de git e contratos vivos.

Um incremento não é um PRD: o incremento é a entrega completa (brief, PRD,
TechSpec, impactos contratuais, tasks, review, QA, bugfix e fechamento); o PRD
é apenas o documento de produto dentro dele.

## Entrada

Receba do usuário:

- nome ou slug da feature (`[feature]`, em kebab-case);
- descrição inicial do problema, oportunidade ou bug;
- contexto de produto, técnico e restrições conhecidas;
- urgência, risco, usuários afetados e superfície esperada: UI, API, CLI, job,
  dados, integração ou documentação.

Se o slug não for fornecido, proponha um slug em kebab-case antes de salvar.

## Saídas obrigatórias

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
```

Crie também os diretórios:

```text
sdd/incrementos/[feature]/impacto-contratual/
.compozy/tasks/[feature]/
```

## Regras críticas

- NÃO implemente código.
- NÃO crie PRD, TechSpec ou tasks detalhadas nesta etapa.
- NÃO trate `brief.md` ou `incremento.yaml` como substitutos do PRD; eles apenas
  iniciam e organizam a entrega.
- O brief congela após esta etapa: prompts seguintes não o editam. Requisitos,
  regras, métricas, UX e escopo pertencem ao PRD; rastreamento operacional
  (rigor vigente, caminhos, status) pertence a `incremento.yaml` e `execucao.md`.
- NÃO classifique como `small` se houver contrato público, migração, segurança,
  privacidade, billing, permissão, dados sensíveis, feature full-stack ambígua,
  risco operacional alto ou impacto cross-team.
- Use `sdd/contratos/` como fonte de comportamento atual quando existir.
- Se a entrega alterar comportamento ainda sem contrato vivo, registre isso como
  lacuna e planeje `Comportamentos novos`.

## Trilhas de rigor

Escolha uma:

- `small`: entrega local, baixo risco, sem contrato público novo, sem migração,
  sem fluxo full-stack ambíguo. Exige PRD enxuto e pode seguir com impacto
  contratual, tasks simples, gates e fechamento.
- `medium`: entrega de produto clara, risco moderado, algum contrato entre
  camadas ou UX relevante. Exige PRD e TechSpec enxutos.
- `large`: feature grande, produto novo, regra de negócio relevante, múltiplas
  camadas, segurança, privacidade, dados, migração ou stakeholders. Exige fluxo
  completo.

## Mapa de rota por trilha

| Trilha   | Sequência de prompts                                                                                    |
|----------|---------------------------------------------------------------------------------------------------------|
| `small`  | 00 → 01 (PRD enxuto) → 03 → 04 (leve) → 06 → 08 → 10; pula 02; 07 opcional conforme risco; 09 somente se houver bug. |
| `medium` | 00 → 01 → 02 → 03 → 04 → 06 → 07 → 08 → 10; 09 quando houver bug.                                        |
| `large`  | Fluxo completo 00 → 10.                                                                                  |

Nota: `05-instalar-rules-skills.md` é setup de governança do projeto: roda uma
vez por projeto (ou quando a governança mudar), não a cada incremento.

## Fluxo

1. Leia a solicitação do usuário.
2. Consulte `sdd/contratos/` se já existir comportamento relacionado.
3. Faça perguntas objetivas somente se a classificação de rigor, escopo ou risco
   não puder ser decidida com segurança.
4. Escolha `small`, `medium` ou `large` e justifique em uma frase.
5. Crie `sdd/incrementos/[feature]/incremento.yaml`.
6. Crie `sdd/incrementos/[feature]/brief.md`.
7. Informe os próximos prompts conforme o Mapa de rota por trilha.

## Template de `incremento.yaml`

```yaml
id: [feature]
status: proposto # proposto | especificado | em_execucao | consolidado | bloqueado
rigor: small
criado_em: YYYY-MM-DD
responsavel: ""
dominios: []
contratos_lidos: []
incremento_canonico:
  brief: sdd/incrementos/[feature]/brief.md
  execucao: sdd/incrementos/[feature]/execucao.md
  impacto_contratual: sdd/incrementos/[feature]/impacto-contratual/
execucao:
  compozy_workflow: .compozy/tasks/[feature]
  prd: .compozy/tasks/[feature]/_prd.md
  techspec: .compozy/tasks/[feature]/_techspec.md
fechamento:
  target: sdd/historico/YYYY-MM-DD-[feature]
```

## Template de `brief.md`

```markdown
# Brief: [nome do incremento]

## Identificação

- Incremento: [feature]
- Origem do pedido: [usuário, ticket, documento, reunião ou caminho do arquivo]
- Data: YYYY-MM-DD
- Solicitação bruta: [1 a 3 linhas ou link para o pedido original]

## Intenção em uma frase

[Abertura curta do incremento. Não liste requisitos, regras de negócio,
critérios de sucesso, UX ou fora de escopo detalhado.]

## Classificação inicial

- Rigor inicial: small / medium / large (fonte operacional vigente: `incremento.yaml`)
- Motivo do rigor: [uma frase objetiva]
- Tipo de entrega: feature / bugfix / refactor / docs / infra / chore
- Superfície esperada: UI / API / CLI / job / dados / integração / documentação

## Leitura de contexto na triagem

- Contratos vivos consultados: [sdd/contratos/... ou "Nenhum contrato existente relacionado"]
- Evidências lidas: [arquivos, links, logs, telas ou "Somente solicitação inicial"]
- Lacunas conhecidas no contrato vivo: [se houver]

## Capacidades candidatas (hipótese da triagem)

- [dominio]: NOVO / ALTERADO / REMOVIDO

[A lista confirmada vive no PRD, seção "Impacto no contrato vivo"; o detalhe
vive em `impacto-contratual/`. Não sincronize esta hipótese depois.]

## Perguntas para o PRD responder

- [Pergunta de produto, regra, usuário, métrica, UX ou fora de escopo que ainda
  precisa ser respondida no PRD.]

## Decisões adiadas para TechSpec

- [Decisão técnica, contrato, integração, dados ou teste que não deve ser
  resolvido no brief.]
```

O brief é o retrato da triagem e não é editado pelos prompts seguintes. Os
artefatos exigidos da entrega derivam do Mapa de rota por trilha e dos caminhos
em `incremento.yaml` — não os liste no brief.

## Checklist

- [ ] `incremento.yaml` criado.
- [ ] `brief.md` criado.
- [ ] Trilha de rigor escolhida e justificada.
- [ ] Superfície esperada registrada.
- [ ] Capacidades candidatas listadas como hipótese.
- [ ] Perguntas para o PRD responder registradas.
- [ ] Brief não duplica conteúdo que pertence ao PRD nem rastreia artefatos.
- [ ] Próximos prompts informados conforme o Mapa de rota por trilha.
