# Guia para leigos — entendendo o fluxo SDD

Este guia explica o processo para quem nunca trabalhou com SDD
(Spec-Driven Development), contratos vivos ou agentes de IA. Ele é
**explicativo, não normativo**: se algo aqui divergir dos prompts numerados ou
de [`_comum.md`](../_comum.md), os prompts mandam.

## O problema que isto resolve

Todo sistema envelhece do mesmo jeito: o código sabe o que o sistema faz, mas
as pessoas esquecem. A documentação fica velha, o time muda, e a IA que ajuda
a programar não tem como saber o que o sistema *promete* fazer — só o que o
código *parece* fazer.

O SDD ataca isso com uma regra simples: **nenhuma mudança de comportamento
acontece sem antes ser escrita, e todo comportamento entregue vira registro
permanente**. O registro permanente é o contrato vivo: um manual oficial do
sistema, sempre atualizado, que pessoas e agentes leem antes de mexer em
qualquer coisa.

## As quatro pastas

Tudo se organiza em quatro lugares, cada um respondendo a uma pergunta:

```text
sdd/contratos/    → o que o sistema faz HOJE (o manual oficial)
sdd/incrementos/  → o que estamos entregando AGORA
.compozy/tasks/   → o que o agente EXECUTA (planos, tasks, testes)
sdd/historico/    → o que JÁ FOI entregue (arquivo morto, nunca apagado)
```

## Os documentos e suas analogias

| Documento | Analogia | O que responde |
| --- | --- | --- |
| `brief.md` | Ficha de abertura do chamado | De onde veio o pedido? Qual o tamanho? Congela após a triagem. |
| `_prd.md` (PRD) | Diagnóstico | O que o produto precisa fazer e por quê? Sem decidir tecnologia. |
| `_techspec.md` (TechSpec) | Planta da obra | Como a engenharia vai construir? Onde mexer? |
| `task_NN.md` | Ordem de serviço | Um pedaço pequeno e verificável do trabalho. |
| `NNN__task.feature` (Gherkin) | Roteiro de ensaio | Cenários em linguagem humana: DADO, QUANDO, ENTÃO. |
| `impacto-contratual/` | Proposta de alteração do manual | Depois desta entrega, o que muda no comportamento? |
| `sdd/contratos/` | Manual oficial | O que o sistema promete fazer, por domínio. |
| `incremento.yaml` | Etiqueta da pasta | Identificação, trilha, status e onde está cada artefato. |
| `sdd/historico/` | Arquivo morto | Tudo de entregas passadas, com contexto completo. |

O detalhe importante: o **impacto contratual** é separado do código de
propósito. A task diz onde mexer no código; o impacto diz o que muda para o
usuário ou para o sistema. No fechamento, o impacto é aplicado ao manual
oficial — assim o manual nunca fica para trás.

## Uma entrega do começo ao fim

Imagine o pedido: *"quero filtrar tarefas por status"*.

1. **Triagem (passo 00)** — Você registra o pedido e o processo classifica o
   tamanho: mudança local e de baixo risco → trilha `small`; produto novo com
   várias camadas → `large`. Nasce a pasta do incremento com a ficha
   (`brief.md`) e a etiqueta (`incremento.yaml`). A ficha congela aqui.

2. **PRD (passo 01)** — O diagnóstico: quem usa o filtro, quais regras valem
   ("o status selecionado limita os resultados"), o que fica fora de escopo.
   Cada pergunta que a ficha levantou recebe um destino: vira requisito,
   premissa assumida ou pergunta em aberto.

3. **TechSpec (passo 02, trilhas `medium`/`large`)** — A planta: quais telas,
   endpoints e dados mudam, e quais decisões técnicas valem para todos.

4. **Tasks e cenários (passo 03)** — O trabalho vira ordens de serviço
   pequenas, cada uma com cenários de comportamento observável ("DADO que
   existem tarefas abertas e concluídas, QUANDO filtro por abertas, ENTÃO vejo
   apenas abertas") e a proposta de alteração do manual.

5. **Auditoria (passo 04)** — Antes de escrever código, alguém confere se a
   especificação fecha: requisitos rastreáveis, cenários testáveis, nada
   contradizendo o manual oficial. Só `PRONTO` libera a implementação — é um
   portão, não uma sugestão.

6. **Execução (passo 06)** — O agente (ou a pessoa) implementa task por task,
   com testes que citam os cenários. Regra de ouro: ninguém edita o manual
   oficial durante a implementação.

7. **Review e QA (passos 07 e 08)** — O review lê o código procurando bugs e
   violações de contrato; o QA usa o sistema como um usuário usaria. Problemas
   viram registros com severidade (`P0` é gravíssimo, `P3` é cosmético).

8. **Bugfix (passo 09, se precisar)** — Corrige causa raiz, cria teste de
   regressão, e volta para review/QA até passar.

9. **Fechamento (passo 10)** — Com tudo verde, a proposta de alteração é
   aplicada ao manual oficial, e a pasta inteira da entrega vai para o arquivo
   morto. O sistema agora *promete* filtrar tarefas por status — e o próximo
   incremento vai ler isso antes de mexer.

## Perguntas de iniciante

**Por que PRD até para mudança pequena?**
Porque a mudança pequena de hoje é a dúvida de daqui a seis meses. Um PRD
enxuto (meia página) registra objetivo, regra e fora de escopo — barato agora,
valioso depois.

**Por que não editar `sdd/contratos/` direto?**
O manual oficial só muda no fechamento, quando a entrega foi implementada,
revisada e testada. Se mudasse durante a implementação, descreveria intenção,
não realidade — e deixaria de ser confiável.

**O que significa small / medium / large?**
Trilhas de rigor: quanto maior o risco, mais etapas obrigatórias. `small` pula
a TechSpec; `large` passa por tudo. Os critérios e o mapa de rota estão em
[`00-iniciar-incremento-sdd.md`](../00-iniciar-incremento-sdd.md).

**O QA reprovou. E agora?**
Os bugs são registrados, o passo 09 corrige, e o QA roda de novo nos cenários
reprovados. A entrega só fecha com QA aprovado e sem problema grave (`P0`/`P1`)
aberto.

**Onde vejo o que o sistema faz hoje?**
`sdd/contratos/` — um arquivo por domínio (tarefas, usuários, pagamentos...),
escrito em comportamento observável, legível por qualquer pessoa.

**Por que a ficha (brief) nunca muda?**
Ela é a evidência histórica da triagem. Meses depois, responde "por que este
incremento existiu e por que foi classificado assim" — o valor dela é
exatamente não mudar.

**De onde vem o nome "incremento"?**
Do desenvolvimento iterativo e incremental — linhagem que vai de Harlan Mills
(IBM, anos 70), passa pelo modelo espiral de Boehm e chega ao Scrum, onde
*Increment* é o resultado "pronto" e entregável de uma Sprint. A distinção
clássica do par: *incremental* é **adicionar** (cada fatia acrescenta
capacidade completa ao sistema), *iterativo* é **refinar** (repassar o mesmo
trabalho melhorando). Aqui o incremento segue o sentido do Scrum — fatia
vertical completa, com definição de "pronto" nos gates do fechamento — e
carrega um segundo sentido: cada entrega **incrementa o contrato vivo**.
`sdd/contratos/` só cresce, nunca regride, e `sdd/historico/` é literalmente a
sequência de incrementos aplicados ao manual do sistema. O lado *iterativo*
também existe, mas dentro do incremento: os loops auditoria → correção,
review → bugfix e QA → bugfix são iteração; o incremento fecha quando a
iteração converge.

## Próximos passos

1. Leia [`_comum.md`](../_comum.md) — as regras compartilhadas em uma página.
2. Leia o [`README.md`](../README.md) — visão geral, fluxo e tabela de artefatos.
3. Rode o passo [`00-iniciar-incremento-sdd.md`](../00-iniciar-incremento-sdd.md)
   com um pedido real e pequeno. O fluxo ensina o resto.
