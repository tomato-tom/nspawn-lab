# ローカルAIテスト用のプロンプト
Qwen3.7-Plus

MacBook Air 6,1 (Haswell) のようなリソース制約の厳しい環境では、以下の3つの観点で性能を測るプロンプトが有効です。

### 1. 論理推論・数学（CPUの単コア性能と正確性を測定）
MoEモデルは「考える」際に複数のエキスパートを呼び出すため、単純な文章生成よりも負荷がかかります。

```text
以下の問題を段階的に考えて解いてください。最後に答えだけを出力してください。

問題：
ある店では、リンゴ1個とバナナ2本のセットが300円、リンゴ2個とバナナ1本のセットが400円で売られています。
リンゴ1個とバナナ1本の合計価格はいくらですか？

思考プロセス：
```

*   **見るべき点**: `eval rate` (tokens/s)。Haswell i5-4260U で Q4_K_M の場合、**15〜25 t/s** が出れば良好です。10 t/s を下回ると実用性が低下します。

### 2. 日本語要約・文脈理解（メモリ帯域幅とキャッシュ効率を測定）
長いテキストを処理すると KV キャッシュが増大し、メモリ帯域幅を圧迫します。MBA 6,1 のボトルネックはここにあります。

```text
以下の文章を200字以内で要約してください。

[ここに新聞記事やブログ記事など、500〜1000文字程度の日本語テキストを貼り付ける]
```

*   **見るべき点**: プロンプト処理速度 (`prompt eval rate`) と、生成中のトークン速度の低下具合。要約中に速度が極端に落ちる場合は、メモリ不足でスワップが発生している可能性があります。

### 3. コード生成・構造化出力（命令追従能力と安定性）
小さなモデルでも、コード生成は構文エラーが出やすいため、モデルの「賢さ」の指標になります。

```text
Pythonで、フィボナッチ数列を計算する再帰関数を書いてください。
ただし、メモ化を用いて計算効率を改善し、n=100 まで高速に計算できるようにしてください。
コメントは日本語で記述してください。
```

*   **見るべき点**: 出力の正確性と、`total duration`。MoEモデルはコード生成時に特定のエキスパート（プログラミング担当）を活性化する必要があるため、Denseモデルとの差が出やすいタスクです。

---

### 📊 測定時のTips for MBA 6,1

1.  **スワップ監視**: `vm_stat 1` や `top` を別ターミナルで開き、Swap In/Out が急増していないか確認してください。
2.  **コンテキスト制限**: デフォルトの 128K は MBA 6,1 では重すぎるため、必ず `--num-ctx 4096` または `8192` で制限して比較してください。
3.  **比較対象**: `granite3-moe:3b` と並行して `qwen2.5-coder:3b` (Dense) を同じプロンプトで実行し、**「MoEによる軽量化効果」**が実際に速度向上につながっているか確認するのが最も有意義です。

特に「1. 論理推論」の結果で `eval rate` が 20 t/s を超えていれば、MBA 6,1 としては非常に快適に動作していると言えます。


MacBook Air 6,1 (Haswell) で小さなモデル（3B以下）の性能を測るための、**英語版・軽量ベンチマークプロンプト**です。

英語はトークン化が効率的で、日本語よりも処理が軽いため、ハードウェアの限界性能を引き出しやすいです。

### 1. Logic & Math (CPU単コア性能・推論能力)
最も基本的な「頭脳」テストです。MoEモデルはここでルーティングの正確性が問われます。

```text
Solve this step-by-step:
If 3 cats can catch 3 mice in 3 minutes, how many minutes will it take 100 cats to catch 100 mice?
Provide only the final number at the end.
```
*   **正解**: 3
*   **見るべき点**: `eval rate` (t/s)。Haswell i5-4260U + Q4_K_M で **20 t/s 以上**なら優秀です。

### 2. Code Generation (構造化出力・命令追従)
Pythonの簡単なコード生成。シンタックスエラーが出ないか、そして速度が落ちないかを測ります。

```text
Write a Python function called 'is_prime' that checks if a number is prime. 
Include docstrings and handle edge cases (numbers less than 2).
Keep it concise.
```
*   **見るべき点**: コードの正確性と、生成中のトークン速度。小さなモデルでもこの程度はスラスラ出るはずです。

### 3. Summarization (メモリ帯域幅・KVキャッシュ負荷)
短い英文を要約させ、メモリ使用量の変化を見ます。

```text
Summarize the following text in under 15 words:
"The Industrial Revolution was a period of major industrialization and innovation during the late 1700s and early 1800s. It began in Great Britain and quickly spread throughout Western Europe and North America. This transition included going from hand production methods to machines, new chemical manufacturing and iron production processes, the increasing use of steam and water power, the development of machine tools and the rise of the mechanized factory system."
```

*   **見るべき点**: プロンプト処理速度 (`prompt eval rate`) と、要約生成時の安定性。

ojj

---

### 🚀 MBA 6,1 での実行コマンド例

メモリ圧迫を防ぐため、コンテキスト長を **4096** に制限して実行してください。

```bash
# Granite 3.0 MoE 3B の場合
ollama run granite3-moe:3b --num-ctx 4096 --verbose

# 比較用：Qwen2.5-Coder 3B (Dense) の場合
ollama run qwen2.5-coder:3b --num-ctx 4096 --verbose
```

### 📊 判定基準 (MBA 6,1 / i5-4260U)

| 指標 | 良好 (Good) | 普通 (Average) | 要注意 (Slow) |
| :--- | :--- | :--- | :--- |
| **Prompt Eval Rate** | > 40 t/s | 20 - 40 t/s | < 20 t/s |
| **Eval Rate (生成)** | > 20 t/s | 10 - 20 t/s | < 10 t/s |
| **Load Duration** | < 5s | 5 - 10s | > 10s |

