# Desbloqueio administrativo da governança

Este procedimento trata do bootstrap de autorização para mudanças nos controles
SDD. **Não é uma instrução para ignorar checks vermelhos ou tornar o
`authority checker` permissivo.**

## Por que o PR #5 ainda falha

A execução `pull_request_target` usa o workflow, o guard e a policy
**da branch-base** (não as versões propostas no PR). Na configuração base
atual, `authority.check_command` e `authority.check_sha256` estão vazios
em `governanca/policies.yaml.example`. Assim, o comando
`protect-ci` recusa alterações de `install.sh`, `evals/`, scripts de
governança e workflows com a decisão `governance_change`, mesmo quando o
dono do projeto aprova verbalmente o trabalho. Essa recusa é intencional.

## O que o administrador do repositório precisa decidir

1. Definir uma **fonte externa verificável de aprovação**, com escopo de
   mudança, SHA do commit e identidade autorizadora. Um comentário ou um campo
   `aprovado: true` dentro da própria branch candidata não são fontes
   independentes.
2. Provisionar um executável `authority checker` confiável **fora do
   checkout**, executável no runner do CI e **com SHA-256 fixado na policy
   da base**. O checker deve recusar solicitações sem aprovação válida ou
   quando `SDD_AUTH_GATE`, `SDD_AUTH_HEAD` e `SDD_AUTH_TARGET` não coincidirem
   com o registro aprovado; a aprovação de `governance_change` é específica
   para um escopo, não uma permissão global.
3. Incorporar o provisionamento ao **workflow confiável da base**. A política
   deve referenciar o caminho absoluto desse executável e seu digest,
   por meio de `authority.check_command` e
   `authority.check_sha256`. Como o próprio workflow/policy estão
   protegidos, a primeira ativação requer um procedimento administrativo
   explícito e auditável (bootstrap separado), antes de tentar aprovar o
   PR funcional.
4. Exigir os checks de CI na regra de proteção de `main`, revisar o diff e
   o histórico de aprovação do bootstrap e só então repetir o `SDD guard`.
   Sem isso, a branch principal pode receber alterações mesmo que o guard
   esteja vermelho, o que tornaria o controle meramente informativo.

## Checklist de aceitação

- A policy confiável da `main` aponta para um checker existente fora do
  worktree, com SHA-256 idêntico ao arquivo executado.
- Uma tentativa sem aprovação externa **falha**, inclusive quando o PR
  contém alterações no próprio guard, na policy ou no workflow.
- Uma aprovação explícita para o SHA e caminhos de um PR específico libera
  apenas aqueles alvos; mudança posterior de SHA exige nova autorização.
- `Template checks` e `SDD guard` passam para o mesmo SHA do PR aprovado.
- O instalador retira os registros `PreToolUse` SDD antes de apagar
  `sdd/governanca/sdd-hook-claude.sh`, inclusive sob falha parcial, sem
  modificar hooks de terceiros.

## Limite da migração dos hooks

O arquivo `governanca/sdd-hook-claude.sh` permanece no *repositório do
template* durante a transição apenas porque a versão antiga do workflow
confiável exige sua presença. **Ele não é instalado como hook ativo pelo
novo instalador.** Após a promoção administrativamente autorizada do
workflow novo, a remoção definitiva do arquivo legado pode ocorrer em uma
segunda alteração revisada, com os mesmos gates.

Não use `exit 0` incondicional, não edite o workflow do PR para fingir que
a policy da base mudou e não trate o status de administrador no GitHub como
prova criptográfica de uma aprovação externa que ainda não foi implantada.
