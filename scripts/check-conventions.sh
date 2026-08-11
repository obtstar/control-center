#!/usr/bin/env bash
# check-conventions.sh — CONVENTIONS 规模红线机器检查（执行点：git hook / 手动）
#
# 用法: check-conventions.sh [repo-root]   （默认 $PWD）
#
# 检查项与依据（/home/dev/control-api/CONVENTIONS.md）：
#   §1   单文件 ≤300 行（代码文件；.md/.yaml 等文档/数据文件不在此限）
#   §1   单函数 ≤60 行（Go，调 go/ast 工具 scripts/gitconventions；
#        未安装 go 命令时降级 WARN 跳过，不 FAIL）
#   §1   单包 ≤8 个 .go 文件
#   §1   go.mod require ≤12（不含 // indirect 间接依赖）
#   §2   禁 util/common/helper 垃圾桶包（含 .go 文件的同名目录）
#   §3   internal/ 包禁 panic/os.Exit/log.Fatal（main 包除外）
#   §3   Go 仓：gofmt -l 无输出、go vet ./... 全绿（无 go 命令降级 WARN）
#   §3   Web 仓：存在 eslint.config.* 时 pnpm lint 零 error（warning 不拦截；
#        无 pnpm 或 node_modules 未安装时降级 WARN）
#
# 非 Go 仓（无 go.mod）只跑 §1 文件行数通用项，Go 项打印 SKIP。
# eslint 项与 Go 项独立：任何仓存在 eslint.config.* 都会执行。
# 每条 FAIL 均携带「依据 + 处置」；退出码：任一 FAIL → 1，全过 → 0。
# 挂接：install-hooks.sh 将本脚本装为目标仓 pre-commit hook。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${1:-$PWD}" && pwd)"
FAILS=0
CITE1='CONVENTIONS.md §1 规模红线——防文件/函数/包/依赖随时间暴涨'
# 代码文件扩展名（文档/数据类 .md/.yaml/.json/.txt 等不适用 §1 行数红线）
CODE_EXT=(go py sh js ts tsx jsx java c h cc cpp rs)

fail() { printf 'FAIL: %s\n  依据: %s\n  处置: %s\n' "$1" "$2" "$3"; FAILS=$((FAILS + 1)); }
pass() { printf 'PASS: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
skip() { printf 'SKIP: %s\n' "$*"; }

# 在 REPO 下找代码文件（跳过依赖与产物目录）
find_code_files() {
  local args=() e
  for e in "${CODE_EXT[@]}"; do args+=(-name "*.$e" -o); done
  unset 'args[${#args[@]}-1]'
  find "$REPO" \( -name .git -o -name vendor -o -name node_modules -o -name dist \) \
    -prune -o -type f \( "${args[@]}" \) -print
}

# §1 单文件 ≤300 行（通用项，Go/非 Go 仓都跑）
# 机生成文件（头 5 行含 auto-generated / Code generated / DO NOT EDIT）豁免：
# 其规模由生成源（如 openapi.yaml）决定，不适用手写红线
check_file_lines() {
  local max=300 count=0 f n fix='拆分为多个文件'
  [ -f "$REPO/go.mod" ] && fix='按 §2 拆分为同包多文件（store.go → store.go + store_task.go），不新建包'
  while IFS= read -r f; do
    if head -5 "$f" | grep -qiE 'auto-generated|code generated|do not (edit|make direct changes)'; then
      continue
    fi
    count=$((count + 1))
    n=$(wc -l < "$f")
    if [ "$n" -gt "$max" ]; then
      fail "${f#"$REPO"/} $n 行（上限 $max）" "$CITE1" "$fix"
    fi
  done < <(find_code_files)
  [ "$FAILS" -eq 0 ] && pass "§1 单文件行数 ≤$max（检查 $count 个代码文件）"
}

# §1 单函数 ≤60 行（go/ast；无 go 命令降级 WARN）
check_func_lines() {
  local out rc
  if ! command -v go >/dev/null 2>&1; then
    warn '§1 单函数行数：未找到 go 命令，降级跳过（不 FAIL）；安装 Go 后本项恢复强制'
    return
  fi
  # 先整体捕获拿到 go run 真实退出码，再过滤其回显的 "exit status N" 行
  out=$(cd "$SCRIPT_DIR/gitconventions" && go run . "$REPO" 2>&1); rc=$?
  out=$(printf '%s\n' "$out" | grep -v '^exit status ' || true)
  case $rc in
    0) pass '§1 单函数行数 ≤60（go/ast）' ;;
    1)
      fail '存在超过 60 行的函数（见下）' "$CITE1" '按 §1 提取子函数'
      printf '%s\n' "$out" | sed 's/^/    /' ;;
    *) warn "§1 单函数行数：检查工具执行失败，降级跳过（不 FAIL）：$out" ;;
  esac
}

# §1 单包 ≤8 个 .go 文件
check_pkg_files() {
  local max=8 found=0 line n d
  while IFS= read -r line; do
    n="${line%% *}"; d="${line#* }"
    if [ "$n" -gt "$max" ]; then
      found=1
      fail "${d#"$REPO"/}/ $n 个 .go 文件（上限 $max）" "$CITE1" \
        '该包承担了多个领域：拆新包并在 MR 描述中说明它拥有的领域（需人评审）'
    fi
  done < <(find "$REPO" \( -name .git -o -name vendor \) -prune -o -type f -name '*.go' -print \
    | xargs -r -n1 dirname | sort | uniq -c | sed 's/^ *//')
  [ "$found" -eq 0 ] && pass "§1 单包文件数 ≤$max"
}

# §1 go.mod require ≤12（不含 // indirect 间接依赖）
check_require_count() {
  local max=12 n
  n=$(awk '
    /^require[ \t]*\(/                        { blk=1; next }
    blk && /^\)/                              { blk=0; next }
    blk && /\/\/[ \t]*indirect/               { next }
    blk && NF                                 { n++ }
    /^require[ \t]+[^ \t(]/ && !/indirect/    { n++ }
    END                                       { print n+0 }
  ' "$REPO/go.mod")
  if [ "$n" -gt "$max" ]; then
    fail "go.mod require $n 个直接依赖（上限 $max）" "$CITE1" \
      '加依赖先登记 DEPENDENCIES.md 并在 MR 说明“为什么标准库/现有依赖不够”'
  else
    pass "§1 go.mod require ≤$max（当前 $n 个直接依赖）"
  fi
}

# §2 禁 util/common/helper 垃圾桶包
check_blacklist_pkgs() {
  local found=0 d
  while IFS= read -r d; do
    if find "$d" -maxdepth 1 -name '*.go' -print -quit | grep -q .; then
      found=1
      fail "${d#"$REPO"/}/ 为禁止的垃圾桶包（util/common/helper）" \
        'CONVENTIONS.md §2 包与文件组织——共享代码要么属于某领域，要么进 internal/config' \
        '代码并入对应领域包或 internal/config，删除该目录'
    fi
  done < <(find "$REPO" \( -name .git -o -name vendor \) -prune -o -type d \
    \( -name util -o -name common -o -name helper \) -print)
  [ "$found" -eq 0 ] && pass '§2 无 util/common/helper 包'
}

# §3 internal/ 禁 panic/os.Exit/log.Fatal
check_internal_banned() {
  local hits
  hits=$(find "$REPO" \( -name .git -o -name vendor \) -prune -o -type d -name internal -print0 \
    | xargs -0 -r grep -rnE '\b(panic|os\.Exit|log\.Fatal)\(' --include='*.go' 2>/dev/null)
  if [ -n "$hits" ]; then
    fail 'internal/ 包存在 panic/os.Exit/log.Fatal（见下）' \
      'CONVENTIONS.md §3 代码风格——只在 main 里允许退出' \
      '错误用 fmt.Errorf("...: %w", err) 逐层包装向上返回，由 main 决定退出'
    printf '%s\n' "$hits" | sed "s|$REPO/||" | sed 's/^/    /'
  else
    pass '§3 internal/ 无 panic/os.Exit/log.Fatal'
  fi
}

# §3 gofmt -l 无输出
check_gofmt() {
  if ! command -v gofmt >/dev/null 2>&1; then
    warn '§3 gofmt：未找到 gofmt 命令，降级跳过（不 FAIL）；安装 Go 后本项恢复强制'
    return
  fi
  local out
  out=$(cd "$REPO" && gofmt -l . 2>/dev/null | grep -v '^vendor/' || true)
  if [ -n "$out" ]; then
    fail '存在未 gofmt 格式化的文件（见下）' \
      'CONVENTIONS.md §3 代码风格——gofmt + go vet 全绿' \
      'gofmt -w 修正后重新提交'
    printf '%s\n' "$out" | sed 's/^/    /'
  else
    pass '§3 gofmt 无格式偏差'
  fi
}

# §3 go vet ./... 全绿
check_govet() {
  if ! command -v go >/dev/null 2>&1; then
    warn '§3 go vet：未找到 go 命令，降级跳过（不 FAIL）；安装 Go 后本项恢复强制'
    return
  fi
  local out rc
  out=$(cd "$REPO" && go vet ./... 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    fail 'go vet 报告问题（见下）' \
      'CONVENTIONS.md §3 代码风格——gofmt + go vet 全绿' \
      '按 vet 提示修正后重新提交'
    printf '%s\n' "$out" | sed 's/^/    /'
  else
    pass '§3 go vet 全绿'
  fi
}

# §3 Web：存在 eslint.config.* 时 pnpm lint 零 error
check_eslint() {
  local cfg=''
  for f in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts; do
    [ -f "$REPO/$f" ] && cfg="$f" && break
  done
  if [ -z "$cfg" ]; then
    skip '无 eslint.config.*：跳过 eslint 项'
    return
  fi
  if ! command -v pnpm >/dev/null 2>&1 || [ ! -d "$REPO/node_modules" ]; then
    warn '§3 eslint：pnpm 或 node_modules 不可用，降级跳过（不 FAIL）；安装依赖后本项恢复强制'
    return
  fi
  local out rc
  out=$(cd "$REPO" && pnpm lint 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    fail 'eslint 报告 error（见下）' \
      'CONVENTIONS.md §3 代码风格——静态检查全绿方可提交' \
      '按提示修正，或 pnpm lint:fix 自动修复后重新提交'
    printf '%s\n' "$out" | grep -E 'error|problem' | sed 's/^/    /'
  else
    pass '§3 eslint 零 error'
  fi
}

echo "== check-conventions: $REPO =="
check_file_lines
if [ -f "$REPO/go.mod" ]; then
  check_func_lines
  check_pkg_files
  check_require_count
  check_blacklist_pkgs
  check_internal_banned
  check_gofmt
  check_govet
else
  skip '无 go.mod：非 Go 仓，跳过 Go 项（函数行数/包文件数/require/黑名单包/internal 禁词/gofmt/vet）'
fi
check_eslint
echo
if [ "$FAILS" -gt 0 ]; then
  printf '结果: FAIL（%d 处违规）\n' "$FAILS"
  exit 1
fi
echo '结果: PASS（全部检查通过）'
