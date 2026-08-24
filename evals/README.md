# Evals do harness SDD

Estas evals verificam invariantes do processo, não o produto desenvolvido.

## Quando rodar

Rode ao alterar:

- `_comum.md` ou prompts;
- skills/agents;
- policies/hooks;
- modelo ou roteamento;
- permissões de tools;
- instalador;
- regras de autonomia.

## Formato

Cada caso possui:

- entrada/situação;
- artefatos relevantes;
- ação esperada;
- proibições;
- evidência de aprovação.

O arquivo `cases/core-contracts.yaml` contém o conjunto mínimo.

## Execução

O runner está incluído: `run-evals.sh`.

```bash
sdd/evals/run-evals.sh --tier1     # determinístico, sem LLM (roda em CI)
SDD_EVAL_AGENT="claude -p" \
SDD_EVAL_JUDGE="claude -p" \
  sdd/evals/run-evals.sh --all     # executor e oracle isolados
```

### Tier 1 — determinístico

Fixtures sintéticas exercitam o `sdd-guard.sh` e a matriz de rota: auditoria
não `PRONTO`, `P0`/`P1` aberto, review/QA reprovados, `NAO_VERIFICADO`, gate de
produção ausente/expirado, rollback ausente, merge/deploy não confirmados,
task incompleta e janela de escrita do contrato vivo. Não usa LLM, roda em
segundos e é o que protege o harness em cada PR.

Um bloqueio legítimo é `exit 1`. `exit 2` (erro/uso inválido) é reportado como
FALHA de propósito: crash não pode ser contado como proteção.

### Tier 2 — agêntico

Casos que dependem de julgamento (classificar risco, recusar caminho proibido,
marcar `NAO_VERIFICADO`, respeitar autoridade de git). Exigem executor
(`--agent-cmd`/`SDD_EVAL_AGENT`) e oracle independente
(`--judge-cmd`/`SDD_EVAL_JUDGE`). O executor produz fatos; somente o judge pode
emitir o verdict JSON. Arquivo de evidência não vazio não é aprovação.

Sem qualquer uma dessas partes, os casos aparecem como `SKIP` e `--all` termina
não zero. Assim uma ausência de infraestrutura nunca vira gate verde.

O Tier 2 exige `bubblewrap` (`bwrap`) e falha fechado quando a sandbox não está
disponível. Projeto fonte, homes, `/tmp` e sockets do host ficam ocultos; somente
o diretório do executável configurado, workspace, output e inputs selados são
montados. Nenhuma credencial ou variável do host é herdada. Para agentes remotos,
use um wrapper externo ao worktree que faça o broker da API sem expor credenciais
reutilizáveis dentro da sandbox.

### Qualidade das evals

Uma eval que continua verde quando o controle é removido não vale nada. Valide
por mutação: desabilite deliberadamente uma checagem do guard e confirme que a
suíte fica vermelha.

## Regra de promoção

Todo incidente ou retrabalho caro deve responder:

```text
Qual eval teria detectado isto antes?
```

Crie a eval antes ou junto da correção do harness.
