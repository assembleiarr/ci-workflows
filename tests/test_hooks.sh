#!/usr/bin/env bash

# @file test_hooks.sh
# @brief Testa os hooks do .pre-commit-hooks.yaml em repos git descartáveis.
# @description
#   Copia a árvore de trabalho deste repo (arquivos versionados e novos, inclusive mudanças não
#   comitadas) para um repo temporário com um commit próprio, porque o `pre-commit try-repo`
#   exige um HEAD. Para cada caso, cria outro repo temporário, adiciona arquivos ao índice (sem
#   commit) e roda o hook com `pre-commit try-repo`. Confere se o hook passa ou falha como
#   esperado; erro do próprio pre-commit conta como falha do teste. Não usa rede.
#
#   Pré-requisitos: git, tar e pre-commit no PATH.
#
# @example
#   ./tests/test_hooks.sh

set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

failures=0
cases=0

# Cópia da árvore de trabalho, com commit, para o try-repo.
HOOKS_REPO="${WORK_DIR}/hooks-repo"
mkdir -p "${HOOKS_REPO}"
git -C "${SOURCE_REPO}" ls-files -z --cached --others --exclude-standard |
  (cd "${SOURCE_REPO}" && tar -cf - --null -T -) | tar -xf - -C "${HOOKS_REPO}"
git -C "${HOOKS_REPO}" init -q
git -C "${HOOKS_REPO}" add -A
git -C "${HOOKS_REPO}" -c user.name=test -c user.email=test@example.invalid \
  commit -q --no-verify -m "test: cópia da árvore de trabalho"

# @description Cria um repo git vazio e imprime o caminho dele.
# @arg $1 string Nome do caso, usado no nome do diretório.
new_repo() {
  local dir="${WORK_DIR}/$1"
  mkdir -p "${dir}"
  git -C "${dir}" init -q
  echo "${dir}"
}

# @description Grava um arquivo no repo e o adiciona ao índice com o modo pedido.
# @arg $1 string Repo.
# @arg $2 string Caminho relativo do arquivo.
# @arg $3 string Modo no índice: 644 ou 755.
# @arg $4 string Conteúdo.
add_file() {
  local repo="$1" path="$2" mode="$3" content="$4"
  mkdir -p "$(dirname "${repo}/${path}")"
  printf '%s\n' "${content}" >"${repo}/${path}"
  git -C "${repo}" add -- "${path}"
  if [[ "${mode}" == 755 ]]; then
    git -C "${repo}" update-index --chmod=+x -- "${path}"
  else
    git -C "${repo}" update-index --chmod=-x -- "${path}"
  fi
}

# @description Roda um hook no repo e compara o resultado com o esperado.
# @arg $1 string Nome do caso.
# @arg $2 string Resultado esperado: pass ou fail.
# @arg $3 string Id do hook.
# @arg $4 string Repo.
expect() {
  local name="$1" want="$2" hook="$3" repo="$4" got
  cases=$((cases + 1))
  if (cd "${repo}" && pre-commit try-repo "${HOOKS_REPO}" "${hook}" --all-files) >"${WORK_DIR}/${name}.log" 2>&1; then
    got=pass
  elif grep -q -- "- hook id: ${hook}" "${WORK_DIR}/${name}.log"; then
    got=fail
  else
    got=erro
  fi
  if [[ "${got}" == "${want}" ]]; then
    echo "[OK]   ${name}: ${hook} ${got}"
  else
    echo "[FAIL] ${name}: ${hook} ${got}, esperado ${want}" >&2
    sed 's/^/       /' "${WORK_DIR}/${name}.log" >&2
    failures=$((failures + 1))
  fi
}

SHDOC_OK='#!/bin/sh

# @file run.sh
# @brief Roda o app.
# @description
#   Exemplo.
#
# @example
#   ./run.sh

set -eu
echo ok'

# --- sem-env ---------------------------------------------------------------------------------
r="$(new_repo env-raiz)"
add_file "${r}" .env 644 'SEGREDO=1'
expect env-raiz fail sem-env "${r}"

r="$(new_repo env-subdir)"
add_file "${r}" config/.env.local 644 'SEGREDO=1'
expect env-subdir fail sem-env "${r}"

r="$(new_repo env-link)"
add_file "${r}" config/real.txt 644 'SEGREDO=1'
ln -s config/real.txt "${r}/.env"
git -C "${r}" add -- .env
expect env-link fail sem-env "${r}"

r="$(new_repo env-example)"
add_file "${r}" .env.example 644 'SEGREDO='
add_file "${r}" README.md 644 '# app'
expect env-example pass sem-env "${r}"

# --- check-exec-bit --------------------------------------------------------------------------
r="$(new_repo exec-sem-bit)"
add_file "${r}" docker/run.sh 644 "${SHDOC_OK}"
expect exec-sem-bit fail check-exec-bit "${r}"

r="$(new_repo exec-com-bit)"
add_file "${r}" docker/run.sh 755 "${SHDOC_OK}"
expect exec-com-bit pass check-exec-bit "${r}"

r="$(new_repo exec-lib-755)"
add_file "${r}" scripts/lib.sh 755 'f() {
  echo f
}'
expect exec-lib-755 fail check-exec-bit "${r}"

r="$(new_repo exec-excecao)"
add_file "${r}" docker/run.sh 644 "${SHDOC_OK}"
add_file "${r}" scripts/ci/exec_bit_exceptions.txt 644 'docker/run.sh motivo do teste'
expect exec-excecao pass check-exec-bit "${r}"

r="$(new_repo exec-espaco-sem-bit)"
add_file "${r}" "docker/my run.sh" 644 "${SHDOC_OK}"
expect exec-espaco-sem-bit fail check-exec-bit "${r}"

r="$(new_repo exec-espaco-com-bit)"
add_file "${r}" "docker/my run.sh" 755 "${SHDOC_OK}"
expect exec-espaco-com-bit pass check-exec-bit "${r}"

r="$(new_repo exec-espaco-lib-755)"
add_file "${r}" "scripts/lib/my util.sh" 755 'f() {
  echo f
}'
expect exec-espaco-lib-755 fail check-exec-bit "${r}"

r="$(new_repo exec-sem-shell)"
add_file "${r}" README.md 644 '# app'
expect exec-sem-shell pass check-exec-bit "${r}"

# --- check-shdoc -----------------------------------------------------------------------------
r="$(new_repo shdoc-ok)"
add_file "${r}" run.sh 755 "${SHDOC_OK}"
expect shdoc-ok pass check-shdoc "${r}"

r="$(new_repo shdoc-sem-cabecalho)"
add_file "${r}" run.sh 755 '#!/bin/sh
set -eu
echo ok'
expect shdoc-sem-cabecalho fail check-shdoc "${r}"

r="$(new_repo shdoc-file-vazio)"
add_file "${r}" run.sh 755 "${SHDOC_OK/@file run.sh/@file}"
expect shdoc-file-vazio fail check-shdoc "${r}"

r="$(new_repo shdoc-tag-fora-do-cabecalho)"
add_file "${r}" run.sh 755 '#!/bin/sh

# @file run.sh
# @brief Roda o app.
# @description
#   Exemplo.

set -eu
# @example
#   ./run.sh'
expect shdoc-tag-fora-do-cabecalho fail check-shdoc "${r}"

r="$(new_repo shdoc-biblioteca)"
add_file "${r}" lib/util.sh 644 'f() {
  echo f
}'
expect shdoc-biblioteca pass check-shdoc "${r}"

if ((failures > 0)); then
  echo "[ERROR] ${failures} de ${cases} caso(s) falharam." >&2
  exit 1
fi
echo "[INFO] ${cases} caso(s) passaram."
