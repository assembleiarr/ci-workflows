# ci-workflows

Hooks compartilhados do [pre-commit](https://pre-commit.com/) para as verificações de repositório
dos apps da org `assembleiarr`. As regras de cada verificação ficam no `assembleiarr/app-catalog`,
em `docs/padroes/ci-devsecops.md` e `docs/padroes/scripts-shell.md`.

## Hooks

| Id | O que barra | Arquivos |
| --- | --- | --- |
| `sem-env` | `.env` e `.env.*` no commit; só o `.env.example` entra no git | `.env`, `.env.*` em qualquer diretório |
| `check-exec-bit` | Entrypoint shell sem `100755` ou sem shebang; biblioteca carregada com `source` com `100755` | O repo inteiro, a cada execução |
| `check-shdoc` | Entrypoint shell (`100755`) sem `@file`, `@brief`, `@description` ou `@example` no cabeçalho shdoc | Scripts shell do commit |

O `check-exec-bit` é cópia do `scripts/ci/check_exec_bit.sh` do `al-rr/platform-modules`; o
cabeçalho do script diz o commit de origem e o que mudou. Ele trata como biblioteca o arquivo
chamado `vars.sh`, `functions.sh` ou `lib.sh`, o que fica num diretório `lib/` e o que só define
funções. Exceção temporária fica no repo verificado, em `scripts/ci/exec_bit_exceptions.txt`: um
caminho por linha seguido do motivo.

Limitação conhecida: o `check-exec-bit` ignora, sem aviso, script com espaço no caminho. A correção
vai primeiro para a origem (al-rr/platform-modules#293) e depois é copiada para cá. Até lá, não use
espaço em nome de script.

## Uso

No `.pre-commit-config.yaml` do app, a partir do `templates/app/.pre-commit-config.yaml` do
app-catalog:

```yaml
repos:
  - repo: https://github.com/assembleiarr/ci-workflows
    rev: v0.1.0
    hooks:
      - id: sem-env
      # Só se o repo tem scripts shell:
      - id: check-exec-bit
      - id: check-shdoc
```

Depois, uma vez por clone:

```bash
pre-commit install
pre-commit run --all-files
```

O primeiro `pre-commit run` clona este repo na tag pedida, sem credencial: o repo é público. Os
hooks precisam de `bash` (a partir da 3.2, a do macOS), `git` e das ferramentas básicas de Unix
(`awk`, `grep`, `head`, `tail`).

Para corrigir o que o `check-exec-bit` aponta:

```bash
git update-index --chmod=+x docker/entrypoint.sh   # entrypoint
git update-index --chmod=-x scripts/lib.sh         # biblioteca
```

## Versões

Os apps apontam para uma tag `vX.Y.Z`. As regras de versão e de publicação de tag estão no
[`AGENTS.md`](AGENTS.md#versões).

## Desenvolvimento

```bash
pre-commit install
./tests/test_hooks.sh
pre-commit run --all-files
```

`tests/test_hooks.sh` roda cada hook em repos git descartáveis, com casos que precisam passar e
casos que precisam falhar. Precisa de `git`, `tar` e `pre-commit` no `PATH`, e não usa rede. O
fluxo de contribuição está no [`AGENTS.md`](AGENTS.md).
