// gitconventions — CONVENTIONS §1「单函数 ≤60 行」机器检查（go/ast 实现）。
//
// 用法: gitconventions <repo-root>
// 每个违规函数输出一行 "相对路径:行号: 函数名 N 行（上限 60）"。
// 退出码: 0 无违规；1 存在违规；2 参数或解析错误。
// 依据: /home/dev/control-api/CONVENTIONS.md §1 规模红线——防函数随时间暴涨。
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

const maxFuncLines = 60

type violation struct {
	file  string
	line  int
	name  string
	lines int
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "用法: gitconventions <repo-root>")
		os.Exit(2)
	}
	violations, err := scan(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "gitconventions:", err)
		os.Exit(2)
	}
	for _, v := range violations {
		fmt.Printf("%s:%d: %s %d 行（上限 %d）\n",
			v.file, v.line, v.name, v.lines, maxFuncLines)
	}
	if len(violations) > 0 {
		os.Exit(1)
	}
}

// scan 遍历 root 下全部 .go 文件（跳过 vendor 等目录），汇总违规函数。
func scan(root string) ([]violation, error) {
	var out []violation
	walk := func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if skipDir(d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		if strings.HasSuffix(d.Name(), ".go") {
			v, err := checkFile(root, path)
			if err != nil {
				return err
			}
			out = append(out, v...)
		}
		return nil
	}
	err := filepath.WalkDir(root, walk)
	return out, err
}

func skipDir(name string) bool {
	switch name {
	case ".git", "vendor", "node_modules", "dist":
		return true
	}
	return false
}

// checkFile 解析单个 Go 文件，返回其中超过行数上限的函数（含方法）。
// 行数从 func 关键字行算到函数体右大括号行（含两端，不含文档注释）。
func checkFile(root, path string) ([]violation, error) {
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, path, nil, 0)
	if err != nil {
		return nil, fmt.Errorf("解析 %s: %w", path, err)
	}
	rel, err := filepath.Rel(root, path)
	if err != nil {
		rel = path
	}
	var out []violation
	for _, decl := range f.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || fn.Body == nil {
			continue
		}
		start := fset.Position(fn.Type.Func).Line
		end := fset.Position(fn.Body.Rbrace).Line
		if n := end - start + 1; n > maxFuncLines {
			out = append(out, violation{rel, start, fn.Name.Name, n})
		}
	}
	return out, nil
}
