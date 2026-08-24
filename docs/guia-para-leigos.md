# Guia para leigos

## A ideia

Imagine uma reforma:

- o **brief** registra por que a reforma começou;
- o **PRD** diz o que precisa mudar para o morador;
- a **TechSpec** explica como a obra será feita;
- o **plano** lista ordem, materiais, riscos e como provar que terminou;
- as **tasks** são serviços pequenos;
- a **auditoria** verifica o plano antes de quebrar a parede;
- a **implementação** executa;
- o **review** procura erros técnicos;
- o **QA** usa a casa como morador;
- o **PR/merge** leva a mudança para a construção oficial;
- o **deploy** entrega a reforma no lugar certo;
- o **contrato vivo** atualiza a planta oficial;
- os **aprendizados** evitam repetir problemas na próxima obra.

## Por que quatro classificações

### Rigor

Quanto detalhe precisamos escrever.

### Risco

O tamanho do estrago se algo der errado.

### Autonomia

Até onde o agente pode trabalhar sem nova autorização.

### Alvo

Onde o comportamento precisa existir para ser considerado verdadeiro: local,
branch ou produção.

Essas coisas não são iguais.

## O que é um gate

Gate é uma porta com condição.

Exemplo:

```text
O auditor concluiu que o plano está pronto.
Mas a mudança altera autorização.
Então uma pessoa ainda precisa aprovar.
```

O parecer do agente verifica. O gate humano autoriza.
Escrever “aprovado” num arquivo não basta: um verificador externo confirma
quem aprovou, o escopo e a versão exata do código.

## O que é contrato vivo

É o manual do comportamento atual:

```text
Quando o usuário faz X, o sistema responde Y.
```

Durante uma mudança, não alteramos esse manual. Criamos um impacto temporário.
Depois que a mudança estiver confirmada no alvo correto, o passo 13 atualiza o
manual. Antes da escrita, o guard cria uma autorização curta ligada à versão do
código e somente aos domínios declarados; mudar apenas o status não abre o
contrato.

## O que impede o agente de ignorar regras

Há três níveis:

1. prompt/rule: explica;
2. policy/hook/CI: bloqueia;
3. eval: garante que futuras mudanças no harness não quebrem a regra.

Regra crítica apenas escrita em prompt é frágil.

## Exemplo curto

Pedido: filtrar tarefas por status.

1. `00`: cria o incremento e classifica.
2. `01`: define requisitos e fora de escopo.
3. `03`: cria plano, tasks e cenários.
4. `04`: auditor independente confere.
5. `06`: agente implementa.
6. `07`: revisor independente valida implementação e testes.
7. `08`: QA testa como usuário.
8. `10`: prepara PR.
9. `11`: confirma checks e merge.
10. `13`: atualiza o contrato vivo.
11. `14`: registra aprendizado útil.

## Quando usar fluxo completo

Use `large` ou risco alto para:

- segurança e permissões;
- dados sensíveis;
- migrações;
- contratos públicos;
- billing;
- múltiplas camadas;
- mudanças difíceis de reverter.

Para correção local e reversível, use `small`, mas não pule evidência.
