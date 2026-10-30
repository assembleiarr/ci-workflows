#!/usr/bin/env bash

# @file check_shdoc.sh
# @brief Falha quando um entrypoint shell não tem o cabeçalho shdoc mínimo.
# @description
#   Confere, em cada arquivo recebido, as tags @file, @brief, @description e @example no
#   cabeçalho shdoc, conforme o scripts-shell.md do assembleiarr/app-catalog e o
#   shdoc-standard.md do al-rr/platform-modules. @file e @brief precisam de valor na mesma linha.
#
#   O cabeçalho é o bloco de comentários logo depois do shebang: termina na primeira linha que
#   não é comentário nem vazia.
#
#   Só entrypoints são conferidos: arquivos com modo 100755 no índice do git. Biblioteca
#   (100644) fica de fora, como no shdoc-standard.md. Quem confere se o modo está certo é o
#   check_exec_bit.sh.
#
# @arg $@ string Arquivos a conferir, relativos à raiz do repo.
# @flag --help,-h Mostra o uso.
#
# @example
#   ./scripts/check_shdoc.sh docker/entrypoint.sh

set -euo pipefail

log_error() { echo "[ERROR] $*" >&2; }

usage() {
  cat <<'USAGE'
Uso: ./scripts/check_shdoc.sh <arquivo>...

Falha se um entrypoint (100755 no índice do git) não tem @file, @brief, @description e
@example no cabeçalho shdoc.
USAGE
}

# @description Imprime o cabeçalho de comentários que vem logo depois do shebang.
# @arg $1 string Caminho do arquivo.
header() {
  awk 'NR == 1 && /^#!/ {next} /^[[:space:]]*#/ || /^[[:space:]]*$/ {print; next} {exit}' "$1"
}

# @description Confere as tags de um arquivo e imprime uma linha de erro por tag faltando.
# @arg $1 string Caminho do arquivo.
# @exitcode 0 Cabeçalho completo.
# @exitcode 1 Falta alguma tag.
check_file() {
  local path="$1" head rc=0 tag
  head="$(header "${path}")"
  for tag in file brief; do
    if ! grep -qE "^#[[:space:]]*@${tag}[[:space:]]+[^[:space:]]" <<<"${head}"; then
      log_error "${path}: cabeçalho shdoc sem @${tag} com valor"
      rc=1
    fi
  done
  for tag in description example; do
    if ! grep -qE "^#[[:space:]]*@${tag}([[:space:]]|$)" <<<"${head}"; then
      log_error "${path}: cabeçalho shdoc sem @${tag}"
      rc=1
    fi
  done
  return "${rc}"
}

main() {
  case "${1:-}" in
  --help | -h)
    usage
    exit 0
    ;;
  esac

  local path mode failures=0 checked=0
  for path in "$@"; do
    mode="$(git ls-files -s -- "${path}" | awk '{print $1; exit}')"
    [[ "${mode}" == 100755 ]] || continue
    checked=$((checked + 1))
    check_file "${path}" || failures=$((failures + 1))
  done

  if ((failures > 0)); then
    log_error "${failures} de ${checked} entrypoint(s) sem o cabeçalho shdoc mínimo."
    exit 1
  fi
  echo "[INFO] ${checked} entrypoint(s) conferido(s); cabeçalhos shdoc completos."
}

main "$@"
