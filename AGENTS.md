# AGENTS.md

Regras para agentes (Claude Code, Codex etc.) que trabalham no `assembleiarr/ci-workflows`.
Os padrões completos ficam no [`assembleiarr/app-catalog`](https://github.com/assembleiarr/app-catalog).
Este arquivo traz o que você precisa para trabalhar aqui sem consultar o catálogo.

## O repo

Hooks compartilhados do pre-commit para as verificações de repositório dos apps da org
`assembleiarr` (`docs/padroes/ci-devsecops.md` do app-catalog). Depois recebe os workflows
reutilizáveis do CI.

O repo é público: o pre-commit e o CI dos apps clonam ele sem credencial. Por isso nada aqui pode
ter segredo, configuração de ambiente, nome de servidor ou dado interno.

- `.pre-commit-hooks.yaml`: os hooks publicados (`sem-env`, `check-exec-bit`, `check-shdoc`).
- `scripts/check_exec_bit.sh`: origem do `check-exec-bit`; nasceu como cópia do
  `al-rr/platform-modules`, e o cabeçalho diz o que mudou desde então. Correção entra aqui
  primeiro; as cópias temporárias nos repos do `al-rr` recebem a mesma correção em PR próprio.
  Mantenha a indentação com tab.
- `scripts/check_shdoc.sh`: verificador do cabeçalho shdoc, deste repo.
- `tests/test_hooks.sh`: testa os hooks em repos git descartáveis.

## Comandos

```bash
pre-commit install   # uma vez por clone; antes, uma vez por máquina: brew install pre-commit (macOS) ou pipx install pre-commit
```

| Tarefa | Comando |
| --- | --- |
| Testes dos hooks | `./tests/test_hooks.sh` |
| Verificações de repositório | `pre-commit run --all-files` |

O hook do pre-commit roda as verificações de repositório a cada commit; os hooks deste repo rodam
direto da árvore de trabalho (`repo: local`). Rode os testes antes de todo commit que muda
`scripts/`, `tests/` ou `.pre-commit-hooks.yaml`. São os mesmos comandos do CI.

## Checks do CI

Nomes como aparecem em `gh pr checks`.

| Check | Tipo | Issue dos achados |
| --- | --- | --- |
| `higiene` | obrigatório | — |
| `gitleaks` | obrigatório | — |
| `titulo-do-pr` | obrigatório | — |
| `testes` | obrigatório | — |

## Versões

Os repos de app apontam para uma tag (`rev: vX.Y.Z` no `.pre-commit-config.yaml`). Tags seguem
SemVer:

- **patch**: correção que não muda o que um hook aceita ou barra;
- **minor**: hook novo, ou hook que passa a barrar algo novo;
- **major**: hook removido ou renomeado, ou mudança que quebra a config de quem usa.

Uma tag publicada nunca é movida nem apagada. Tag nova só com pedido explícito, depois do merge e
com o CI verde na `main`. Ao subir a tag usada pelos apps, atualize também o
`templates/app/.pre-commit-config.yaml` do app-catalog.

## Fluxo de trabalho

Branch de integração: `main`. O repo nasceu dentro dos padrões, sem fase `lab`.

1. **Issue** para todo trabalho:
   `gh issue create -R assembleiarr/ci-workflows --title "<resultado esperado>" --body "<contexto, o que fazer, critério de pronto>" --label <bug|enhancement|standard|security>`
2. **Branch** a partir da `main`:
   `git fetch origin && git switch -c <tipo>/<numero-da-issue>-<assunto> origin/main`.
   Tipos: `feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `build`, `chore`.
3. **Commits** em Conventional Commits: `<tipo>: <descrição no imperativo>`, corpo explicando o
   porquê e `Refs #<N>` no fim.
4. **PR** contra a `main`, com título no mesmo formato e corpo com o que mudou, por quê,
   `Closes #<N>`, como foi testado e o resultado da revisão:
   `git push -u origin HEAD && gh pr create --base main --title "<tipo>: <descrição>" --body "<corpo>"`.
   Depois: `gh pr checks --watch`. CI vermelho se corrige na mesma branch.
5. **Merge** com os checks obrigatórios verdes, revisão feita e pedido ou confirmação da pessoa na
   sessão. Antes, rode `gh pr checks <N>`: se um check obrigatório falhou ou ainda está rodando,
   **não faça o merge**. A conferência é sua.
   Depois: `gh pr merge --squash --delete-branch`. Confira se a issue fechou; se não, feche com
   `gh issue close <N> --comment "<o que foi entregue>"`.

## Revisão

Antes de abrir o PR e antes do merge:

1. Rode `./tests/test_hooks.sh` e `pre-commit run --all-files`.
2. Leia o diff inteiro: `git diff origin/main...HEAD`. Confira que trata só da issue e que não tem
   segredo nem dado interno, e que README e `AGENTS.md` acompanham a mudança.
3. Se o diff mexe em documentação e a skill `technical-documentation` está disponível na sessão,
   rode a auditoria sobre esses arquivos e registre no PR a tabela de achados. Sem a skill, siga
   sem mencionar.
4. Se `[ "$ASSEMBLEIARR_CODEX_REVIEW" = "1" ] && command -v codex-review` der certo, rode também o
   `codex-review --cd . --base main --brief <brief.md>`, conforme o
   [padrão de revisão](https://github.com/assembleiarr/app-catalog/blob/main/docs/padroes/revisao.md).
   Se a variável não for `1`, não rode e não mencione.

## Limites

Nunca, sem pedido explícito:

- push direto na `main` ou `--force` em branch compartilhada;
- `git commit --no-verify` ou desligar uma verificação para o commit passar: corrija o achado;
- criar, mover ou apagar tag;
- alterar configurações do repo no GitHub;
- comitar segredo, configuração de ambiente ou dado interno.
