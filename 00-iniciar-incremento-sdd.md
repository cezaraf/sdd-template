# 00 — Iniciar incremento SDD

Você inicia um incremento canônico antes de qualquer implementação.

> Leia `_comum.md` integralmente.

## Entradas

Receba ou infira com evidência:

- nome/slug da entrega;
- problema, oportunidade ou bug;
- usuários e sistemas afetados;
- resultado pretendido;
- restrições inegociáveis;
- urgência, reversibilidade e blast radius;
- superfícies: UI, API, CLI, job, dados, integração, infra ou documentação;
- necessidade de PR, merge e deploy.

Faça perguntas somente quando a lacuna impedir classificação segura. Quando for
possível prosseguir, registre a suposição como `PRM-NNN`.

## Origem

O incremento nasce de três rotas equivalentes:

- `ideia`: alguém descreve o problema;
- `ticket`: item já registrado em outra ferramenta;
- `incidente`: desvio detectado pelo monitoramento determinístico
  (`sdd/governanca/sdd-watch.sh`, banda 2σ/3σ) ou por falha em produção.

Na rota `incidente`, o brief nasce da evidência, não da opinião: anexe a saída
do detector, a issue/alerta, o SHA implantado e a janela de tempo. Trate
reversão/rollback já executado como fato registrado, não como escopo a decidir.
Incidente com recorrência ou custo alto obriga eval no passo 14.

## Saídas

```text
sdd/incrementos/[feature]/incremento.yaml
sdd/incrementos/[feature]/brief.md
sdd/incrementos/[feature]/impacto-contratual/
.compozy/tasks/[feature]/
```

## Regras críticas

- Não implemente código.
- Não crie PRD, TechSpec ou tasks detalhadas.
- O brief congela após este passo.
- Não classifique como risco baixo quando houver segurança, autorização,
  billing, migração, dados sensíveis, contrato público ou operação destrutiva.
- `rigor`, `risco`, `autonomia` e `alvo_contrato` são dimensões diferentes.
- Autonomia não concede autorização implícita: registre o gate.
- Consulte contratos vivos relacionados antes de classificar uma mudança.

## Classificação

### Rigor

- `small`: uma capacidade, poucas superfícies e solução conhecida.
- `medium`: mais de uma superfície, contrato entre camadas, UX relevante ou
  decisões técnicas que precisam ser preservadas.
- `large`: múltiplas capacidades/domínios/times, alta ambiguidade,
  sequenciamento complexo ou várias alternativas arquiteturais.

Classifique segurança, privacidade, billing, migração e dados sensíveis em
`risco`; esses fatores podem exigir TechSpec/review mesmo com rigor `small`.

### Risco

Use `baixo`, `medio`, `alto` ou `regulado`, conforme `_comum.md`.

### Autonomia

Use `assistido`, `autonomo_ate_pr`, `autonomo_ate_staging` ou
`producao_com_gate`.

### Alvo do contrato

Use `local`, `branch` ou `producao`.

## Rota

Monte a rota aplicando cumulativamente estas regras:

| Condição | Etapas obrigatórias |
| --- | --- |
| Todo incremento | 00 → 01 → 03 → 04 → 06 → 08 → 13 → 14 |
| Rigor `medium`/`large` ou risco `alto`/`regulado` | adicionar 02 e 07 |
| Risco `medio` | adicionar 07; adicionar 02 quando houver decisão técnica relevante |
| Contrato público, autorização, billing, dados ou migração | adicionar 02 e 07 |
| Alvo `branch` | adicionar 07 → 10 → 11 antes do 13 |
| Alvo `producao` | adicionar 02 → 07 → 10 → 11 → 12 antes do 13 |

Exemplos:

- `small` + risco `baixo` + alvo `local`: 00 → 01 → 03 → 04 → 06 → 08 → 13 → 14;
- `small` + risco `baixo` + alvo `branch`: 00 → 01 → 03 → 04 → 06 → 07 → 08 → 10 → 11 → 13 → 14;
- `small` + risco `alto` + alvo `branch`: inclui 02, 07 e gate humano;
- qualquer alvo `producao`: inclui 02, 07, 10, 11 e 12.

O passo `05` é governança do projeto e roda no bootstrap ou quando o incremento
revelar uma lacuna. Registre toda dispensa no bloco `rota`.

## Template de `incremento.yaml`

```yaml
id: [feature]
status: proposto
fase: triagem
criado_em: YYYY-MM-DD
responsavel: ""

classificacao:
  rigor: medium
  risco: medio
  autonomia: assistido
  alvo_contrato: branch
  motivo: ""

superficies: []
dominios: []
contratos_lidos: []
premissas: []

rota:
  techspec: obrigatoria # obrigatoria | dispensada
  review: obrigatoria # obrigatoria | dispensada
  pr_merge: obrigatoria # obrigatoria | dispensada
  deploy: dispensada # obrigatoria | dispensada
  justificativas_de_dispensa: []

incremento_canonico:
  brief: sdd/incrementos/[feature]/brief.md
  execucao: sdd/incrementos/[feature]/execucao.md
  impacto_contratual: sdd/incrementos/[feature]/impacto-contratual/

execucao:
  workflow: .compozy/tasks/[feature]
  prd: .compozy/tasks/[feature]/_prd.md
  techspec: .compozy/tasks/[feature]/_techspec.md
  base_ref: ""
  base_sha: ""

gates:
  especificacao:
    parecer_agente:
      status: pendente
      agente: cz-auditor-especificacao
      evidencia: ""
      data: ""
    gate_humano:
      requerido: false
      status: dispensado
      aprovado_por: ""
      escopo: ""
      data: ""
  pr:
    gate_humano:
      requerido: true
      status: pendente
      aprovado_por: ""
      escopo: ""
      data: ""
  merge:
    gate_humano:
      requerido: true
      status: pendente
      aprovado_por: ""
      escopo: ""
      data: ""
  producao:
    gate_humano:
      requerido: true
      status: pendente
      aprovado_por: ""
      escopo: ""
      data: ""

pr:
  numero: null
  url: ""
  status: nao_iniciado
  head_sha: ""

deploy:
  ambiente: ""
  status: nao_iniciado
  versao: ""
  evidencia: []
  rollback: ""

metricas:
  data_triagem: ""        # preencher com a data/hora UTC desta triagem
  data_especificado: ""
  data_primeira_task: ""
  data_validado: ""
  data_merge: ""
  data_deploy: ""
  data_consolidado: ""
  reauditorias: 0
  revisoes_plano: 0

incidente:
  origem: ""              # alerta, check, issue ou relato
  evidencia: []           # links/caminhos da detecção
  janela: ""              # período observado

bloqueio:
  motivo: ""
  gate: ""
  como_desbloquear: ""

fechamento:
  target: sdd/historico/YYYY-MM-DD-[feature]
```

## Template de `brief.md`

```markdown
# Brief: [nome]

## Identificação

- Incremento: [feature]
- Origem: [ideia, ticket, incidente]
- Evidência da origem: [link do alerta/issue/detector, quando incidente]
- Data: YYYY-MM-DD
- Solicitação bruta: [1–3 linhas ou referência]

## Intenção

[O problema e o resultado pretendido em linguagem simples.]

## Usuários e sistemas afetados

- [item]

## Restrições inegociáveis

- [item ou "Nenhuma conhecida"]

## Classificação inicial

- Rigor:
- Risco:
- Autonomia:
- Alvo do contrato:
- Motivo:

## Superfícies e blast radius

- Superfícies:
- Reversibilidade:
- Pior efeito plausível:

## Contexto consultado

- Contratos vivos:
- Evidências:
- Lacunas:

## Capacidades candidatas

- [dominio]: NOVO / ALTERADO / REMOVIDO

## Perguntas para o PRD responder

- [pergunta]

## Decisões adiadas para TechSpec

- [decisão]
```

## Fechamento

Informe a classificação, a rota escolhida e o próximo comando. Não altere o
brief nos passos seguintes.
