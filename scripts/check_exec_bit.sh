#!/usr/bin/env bash

# Cópia de al-rr/platform-modules scripts/ci/check_exec_bit.sh, versão do commit f688c4f
# (lab em ea97fb8). Correção vai primeiro para o platform-modules e depois é copiada.
# Mudanças em relação à origem, todas para rodar como hook do pre-commit, que executa o script
# a partir do cache do hook e não de dentro do repo verificado:
# - REPO_ROOT vem de `git rev-parse --show-toplevel`, não do caminho do script;
# - EXCEPTIONS_FILE fica no repo verificado: scripts/ci/exec_bit_exceptions.txt;
# - caminhos de uso e exemplo trocados para scripts/check_exec_bit.sh, e a referência ao
#   bash-script-standard.md passa a citar o repo de origem.
# Limitação herdada da origem: caminho com espaço é ignorado (al-rr/platform-modules#293).

# @file check_exec_bit.sh
# @brief Fail when a shell script's git-tracked executable bit is wrong.
# @description
#   Git stores one permission bit per file (100755 or 100644). Scripts that
#   are run directly must be 100755 so `./script` and `[[ -x ]]` callers
#   work on a fresh clone; libraries that are only sourced must be 100644.
#   See al-rr/platform-modules docs/standards/bash-script-standard.md
#   ("Executable bit").
#
#   Scope: every tracked `*.sh`, plus tracked files with no "." in their name
#   whose first line is a bash/sh shebang (e.g. packer/packerctl, modulesctl).
#
#   A file is a sourced-only LIBRARY (must be 100644) when any of these hold:
#   - its name is vars.sh, functions.sh or lib.sh, or it lives in a lib/ dir
#   - it has the must-be-sourced guard: an
#     `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` block that exits and does not
#     dispatch with `case` (a guard that dispatches subcommands marks a
#     dual-mode script, which is an ENTRYPOINT)
#   - it only defines things: its last statement is `}` and it has no
#     top-level `main "$@"`
#   Every other file is an ENTRYPOINT: it must be 100755 and start with a
#   shebang.
#
#   Paths listed in scripts/ci/exec_bit_exceptions.txt (one per line,
#   followed by a reason) are skipped; keep that list short and justified.
#
# @flag --help,-h Show usage information.
#
# @example
#   ./scripts/check_exec_bit.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
EXCEPTIONS_FILE="${REPO_ROOT}/scripts/ci/exec_bit_exceptions.txt"

log_error() { echo "[ERROR] $*" >&2; }

usage() {
	cat <<'USAGE'
Usage: ./scripts/check_exec_bit.sh

Fails if a tracked shell entrypoint is not 100755 (or lacks a shebang), or
if a sourced-only library is 100755.
USAGE
}

# @description Print "LIB" or "EXEC" for a file, per the rules above.
# @arg $1 string Repository-relative path.
classify() {
	local path="$1" base guard_block last
	base="$(basename "${path}")"
	case "${base}" in
	vars.sh | functions.sh | lib.sh)
		echo LIB
		return
		;;
	esac
	if [[ "/${path}" == */lib/*.sh ]]; then
		echo LIB
		return
	fi
	guard_block="$(awk '/BASH_SOURCE\[0\]\}" == "\$\{0\}"/{p=1} p{print} p&&/^[[:space:]]*fi[[:space:]]*$/{exit}' "${path}")"
	if [[ -n "${guard_block}" ]]; then
		if grep -qE '^[[:space:]]*case[[:space:]]' <<<"${guard_block}"; then
			echo EXEC
			return
		fi
		if grep -qE '(^|[[:space:];])(exit|return)([[:space:]]|$)' <<<"${guard_block}"; then
			echo LIB
			return
		fi
	fi
	last="$(grep -vE '^[[:space:]]*(#|$)' "${path}" | tail -n 1 || true)"
	if [[ "${last}" == "}" ]] && ! grep -qE '^[[:space:]]*main[[:space:]]+"\$@"' "${path}"; then
		echo LIB
		return
	fi
	echo EXEC
}

is_exception() {
	[[ -f "${EXCEPTIONS_FILE}" ]] || return 1
	awk -v p="$1" '!/^[[:space:]]*(#|$)/ && $1 == p {found=1} END {exit !found}' "${EXCEPTIONS_FILE}"
}

main() {
	case "${1:-}" in
	--help | -h)
		usage
		exit 0
		;;
	"") ;;
	*)
		usage >&2
		exit 2
		;;
	esac

	cd "${REPO_ROOT}"
	local mode path kind failures=0 checked=0
	while read -r mode path; do
		if [[ "${path}" != *.sh ]]; then
			# Extensionless files only (no "." in the name): skips .envrc,
			# *.example templates and other non-script files.
			[[ "$(basename "${path}")" == *.* ]] && continue
			head -n 1 "${path}" 2>/dev/null | grep -qE '^#!.*/(env[[:space:]]+)?(ba)?sh([[:space:]]|$)' || continue
		fi
		is_exception "${path}" && continue
		checked=$((checked + 1))
		kind="$(classify "${path}")"
		if [[ "${kind}" == LIB && "${mode}" != 100644 ]]; then
			log_error "${path}: sourced-only library tracked as ${mode}; expected 100644 (git update-index --chmod=-x)"
			failures=$((failures + 1))
		elif [[ "${kind}" == EXEC && "${mode}" != 100755 ]]; then
			log_error "${path}: entrypoint tracked as ${mode}; expected 100755 (git update-index --chmod=+x)"
			failures=$((failures + 1))
		elif [[ "${kind}" == EXEC ]] && ! head -n 1 "${path}" | grep -q '^#!'; then
			log_error "${path}: entrypoint has no shebang"
			failures=$((failures + 1))
		fi
	done < <(git ls-files -s | awk '$1 ~ /^100(755|644)$/ {print $1, $4}')

	if ((failures > 0)); then
		log_error "${failures} of ${checked} shell file(s) have the wrong executable bit."
		exit 1
	fi
	echo "[INFO] ${checked} shell file(s) checked; executable bits are consistent."
}

main "$@"
