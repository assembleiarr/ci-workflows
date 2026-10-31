# ci-workflows

Hooks compartilhados do [pre-commit](https://pre-commit.com/) para as verificações de repositório
dos repos das orgs `assembleiarr` (apps) e `al-rr` (infra). Este README é o contrato de cada hook:
o que verifica, que arquivos lê e o que precisa para rodar. Quais hooks cada repo liga, e como o CI
os roda, fica no padrão da org:

| Org | Fonte normativa |
| --- | --- |
| `assembleiarr` | `assembleiarr/app-catalog`: `docs/padroes/ci-devsecops.md` e `docs/padroes/scripts-shell.md` |
| `al-rr` | `ednillibanio/platform-catalog`: `docs/standards/pre-commit-standard.md` (ADR-0006) |

> **Nada interno.** O repo é público: o pre-commit e o CI dos dois lados clonam ele sem credencial.
> Nada aqui pode ter segredo, configuração de ambiente, nome de servidor, endereço ou caminho
> interno. Uma verificação que precise desses dados fica como hook `repo: local` no repo que a usa.

## Hooks

| Id | O que barra | Arquivos |
| --- | --- | --- |
| `sem-env` | `.env` e `.env.*` no commit; só o `.env.example` entra no git | `.env`, `.env.*` em qualquer diretório |
| `check-exec-bit` | Entrypoint shell sem `100755` ou sem shebang; biblioteca carregada com `source` com `100755` | O repo inteiro, a cada execução |
| `check-shdoc` | Entrypoint shell (`100755`) sem `@file`, `@brief`, `@description` ou `@example` no cabeçalho shdoc | Scripts shell do commit |

Este repo é a origem do `check-exec-bit`. Ele nasceu como cópia do `scripts/ci/check_exec_bit.sh`
do `al-rr/platform-modules`; as cópias que ainda existem nos repos do `al-rr` são temporárias e
saem quando cada repo adota o hook. O hook trata como biblioteca o arquivo chamado `vars.sh`,
`functions.sh` ou `lib.sh`, o que fica num diretório `lib/` e o que só define funções. Caminho com
espaço também é verificado. Exceção temporária fica no repo verificado, em
`scripts/ci/exec_bit_exceptions.txt`: um caminho por linha seguido do motivo. Um caminho com
espaço não entra nessa lista; renomeie o arquivo.

## Uso

**Repo de app da `assembleiarr`:** no `.pre-commit-config.yaml` do app, a partir do
`templates/app/.pre-commit-config.yaml` do app-catalog:

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

**Repo do `al-rr`:** no `.pre-commit-config.yaml` do repo, a partir do modelo do
`al-rr/provision-template` (o modelo entra pela al-rr/provision-template#10). O `al-rr` adota a partir da `v0.2.0`, a primeira tag com a correção de
caminho com espaço no `check-exec-bit`. O repo que liga o `check-exec-bit` apaga a sua cópia de
`scripts/ci/check_exec_bit.sh` no mesmo PR.

```yaml
repos:
  - repo: https://github.com/assembleiarr/ci-workflows
    rev: v0.2.0
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

Quem usa aponta para uma tag `vX.Y.Z`, nunca para uma branch. As regras de versão e de publicação
de tag estão no [`AGENTS.md`](AGENTS.md#versões); do lado do `al-rr`, a seção "Pinning" do
`pre-commit-standard.md` do platform-catalog diz o mesmo.

## Desenvolvimento

```bash
pre-commit install
./tests/test_hooks.sh
pre-commit run --all-files
```

`tests/test_hooks.sh` roda cada hook em repos git descartáveis, com casos que precisam passar e
casos que precisam falhar. Precisa de `git`, `tar` e `pre-commit` no `PATH`, e não usa rede. O
fluxo de contribuição está no [`AGENTS.md`](AGENTS.md).
