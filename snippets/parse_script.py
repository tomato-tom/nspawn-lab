#!/usr/bin/env python3
import os
import re
import sys
from collections import defaultdict

class ShellScriptAnalyzer:
    def __init__(self):
        self.functions = {}  # {file: {func_name: {args, line_num, calls}}}
        self.sources = {}    # {file: [sourced_files]}
        self.analyzed_files = set()
    
    def analyze_file(self, filepath):
        """シェルスクリプトファイルを解析"""
        if filepath in self.analyzed_files or not os.path.exists(filepath):
            return
        
        self.analyzed_files.add(filepath)
        self.functions[filepath] = {}
        self.sources[filepath] = []
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except UnicodeDecodeError:
            try:
                with open(filepath, 'r', encoding='shift_jis') as f:
                    lines = f.readlines()
            except:
                return  # ファイル読み込み失敗は無視
        
        current_function = None
        condition_depth = 0
        current_condition = None
        
        for line_num, line in enumerate(lines, 1):
            original_line = line
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # 条件分岐の開始を検出
            condition_start = self._detect_condition_start(line)
            if condition_start:
                condition_depth += 1
                current_condition = condition_start
                continue
            
            # 条件分岐の終了を検出
            if self._detect_condition_end(line):
                condition_depth -= 1
                if condition_depth <= 0:
                    condition_depth = 0
                    current_condition = None
                continue
            
            # 関数定義を検出
            func_match = re.match(r'^(\w+)\s*\(\s*\)\s*\{?', line)
            if not func_match:
                func_match = re.match(r'^function\s+(\w+)\s*(\(\s*\))?\s*\{?', line)
            
            if func_match:
                func_name = func_match.group(1)
                self.functions[filepath][func_name] = {
                    'args': self._extract_args(lines, line_num),
                    'line': line_num,
                    'calls': []
                }
                current_function = func_name
                condition_depth = 0  # 関数内では条件をリセット
                current_condition = None
                continue
            
            # source/. コマンドを検出
            source_match = re.match(r'^\s*(?:source|\.|bash)\s+([^\s;|&]+)', line)
            if source_match:
                sourced_file = source_match.group(1).strip('"\'')
                sourced_file = self._resolve_path(sourced_file, filepath)
                self.sources[filepath].append(sourced_file)
                self.analyze_file(sourced_file)
            
            # 関数呼び出しを検出
            if current_function or not current_function:  # グローバルスコープも含める
                self._find_function_calls(line, current_function or "GLOBAL", filepath, current_condition)
    
    def _detect_condition_start(self, line):
        """条件分岐の開始を検出"""
        patterns = [
            (r'^if\s+(.+?)(?:\s*;?\s*then)?$', 'if'),
            (r'^elif\s+(.+?)(?:\s*;?\s*then)?$', 'elif'),
            (r'^else\s*$', 'else'),
            (r'^case\s+(.+?)\s+in', 'case'),
            (r'^while\s+(.+?)(?:\s*;?\s*do)?$', 'while'),
            (r'^for\s+(.+?)(?:\s*;?\s*do)?$', 'for'),
            (r'^\s*\*?\)\s*$', 'case_branch'),  # case の分岐
            (r'^\s*[^)]*\)\s*$', 'case_branch'),  # case の分岐
        ]
        
        for pattern, condition_type in patterns:
            match = re.match(pattern, line, re.IGNORECASE)
            if match:
                if condition_type == 'case_branch':
                    return f"case_branch: {line}"
                elif len(match.groups()) > 0:
                    return f"{condition_type}: {match.group(1)}"
                else:
                    return condition_type
        return None
    
    def _detect_condition_end(self, line):
        """条件分岐の終了を検出"""
        end_patterns = [
            r'^fi\s*$',
            r'^done\s*$', 
            r'^esac\s*$',
            r'^\}\s*$',
            r';;'
        ]
        
        for pattern in end_patterns:
            if re.match(pattern, line, re.IGNORECASE):
                return True
        return False
    
    def _resolve_path(self, sourced_file, current_file):
        """パスを解決"""
        if not os.path.isabs(sourced_file):
            sourced_file = os.path.join(os.path.dirname(current_file), sourced_file)
        return sourced_file
    
    def _extract_args(self, lines, func_line_num):
        """関数の引数を抽出"""
        args = set()
        brace_count = 0
        
        for i in range(func_line_num - 1, min(func_line_num + 50, len(lines))):
            line = lines[i].strip()
            
            # 関数の終了を検出
            brace_count += line.count('{') - line.count('}')
            if i > func_line_num - 1 and brace_count <= 0:
                break
            
            # 引数パターンを検出
            arg_matches = re.findall(r'\$([1-9][0-9]*)', line)
            for match in arg_matches:
                args.add(f'${match}')
            
            if re.search(r'\$[@*#]', line):
                args.add('$@')
        
        return sorted(list(args))
    
    def _find_function_calls(self, line, current_function, filepath, condition=None):
        """行内の関数呼び出しを検出"""
        # 全ファイルから関数名を収集
        all_functions = set()
        for file_funcs in self.functions.values():
            all_functions.update(file_funcs.keys())
        
        # よくあるシェルコマンドは除外
        system_commands = {
            'echo', 'printf', 'read', 'cd', 'ls', 'cp', 'mv', 'rm', 'mkdir', 
            'chmod', 'chown', 'grep', 'sed', 'awk', 'cut', 'sort', 'uniq',
            'cat', 'head', 'tail', 'find', 'xargs', 'test', 'exit', 'return',
            'export', 'unset', 'shift', 'getopts', 'trap', 'kill', 'wait'
        }
        
        for func_name in all_functions:
            if func_name in system_commands:
                continue
                
            # 関数呼び出しパターン（緩い検出）
            patterns = [
                rf'\b{re.escape(func_name)}\b(?!\s*\()',  # 単純呼び出し
                rf'{re.escape(func_name)}\s*\([^)]*\)',   # 括弧付き呼び出し
                rf'\$\(\s*{re.escape(func_name)}\b',      # $(func ...)
                rf'`\s*{re.escape(func_name)}\b',         # `func ...`
            ]
            
            for pattern in patterns:
                if re.search(pattern, line):
                    args = self._extract_call_args(line, func_name)
                    
                    # グローバルスコープの場合は特別扱い
                    if current_function == "GLOBAL":
                        if filepath not in self.functions:
                            self.functions[filepath] = {}
                        if "GLOBAL" not in self.functions[filepath]:
                            self.functions[filepath]["GLOBAL"] = {
                                'args': [], 'line': 0, 'calls': []
                            }
                        target_func = self.functions[filepath]["GLOBAL"]
                    else:
                        if current_function not in self.functions.get(filepath, {}):
                            continue
                        target_func = self.functions[filepath][current_function]
                    
                    call_info = {
                        'function': func_name,
                        'args': args,
                        'condition': condition
                    }
                    target_func['calls'].append(call_info)
                    break
    
    def _extract_call_args(self, line, func_name):
        """関数呼び出しの引数を抽出（ざっくり）"""
        # 関数名の後の文字列を取得
        patterns = [
            rf'{re.escape(func_name)}\s+([^;|&<>\n`$()]*)',
            rf'{re.escape(func_name)}\s*\(([^)]*)\)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, line)
            if match:
                args_str = match.group(1).strip()
                if args_str:
                    return args_str[:50]  # 長すぎる場合は切り詰め
        return ""
    
    def generate_map(self, root_file):
        """関数マップを生成"""
        self.analyze_file(root_file)
        return self._build_map_tree(root_file)
    
    def _build_map_tree(self, filepath, indent=0):
        """マップツリーを構築"""
        result = []
        indent_str = "  " * indent
        
        if filepath not in self.analyzed_files:
            return result
        
        # ファイル名
        result.append(f"{indent_str}{os.path.basename(filepath)}")
        
        # source されたファイル
        for sourced in self.sources.get(filepath, []):
            if os.path.exists(sourced):
                result.append(f"{indent_str}  -> {os.path.basename(sourced)}")
        
        # 関数一覧
        functions = self.functions.get(filepath, {})
        for func_name, func_info in functions.items():
            if func_name == "GLOBAL":
                if func_info['calls']:  # グローバルスコープに呼び出しがある場合のみ表示
                    result.append(f"{indent_str}  [GLOBAL_SCOPE]")
                    for call in func_info['calls']:
                        call_args = f"({call['args']})" if call['args'] else ""
                        condition_info = f" [{call['condition']}]" if call['condition'] else ""
                        result.append(f"{indent_str}    -> {call['function']}{call_args}{condition_info}")
                continue
            
            args_str = f"({', '.join(func_info['args'])})" if func_info['args'] else ""
            result.append(f"{indent_str}  {func_name}{args_str}")
            
            # 関数内での呼び出し
            for call in func_info['calls']:
                call_args = f"({call['args']})" if call['args'] else ""
                condition_info = f" [{call['condition']}]" if call['condition'] else ""
                result.append(f"{indent_str}    -> {call['function']}{call_args}{condition_info}")
        
        return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 shell_analyzer.py <script.sh>")
        sys.exit(1)
    
    script_path = sys.argv[1]
    if not os.path.exists(script_path):
        print(f"Error: File '{script_path}' not found")
        sys.exit(1)
    
    analyzer = ShellScriptAnalyzer()
    map_lines = analyzer.generate_map(script_path)
    
    for line in map_lines:
        print(line)

if __name__ == "__main__":
    main()
