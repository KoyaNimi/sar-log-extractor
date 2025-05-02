# 入力フォルダの指定（処理対象の .txt ファイルをこの中に入れてください）
$inputFolder = ".\sar_files"

# 出力フォルダの指定（結果がここに出力されます）
$outputFolder = ".\output"

# 出力フォルダが存在しない場合は作成
if (-not (Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory | Out-Null
}

# 抽出したい列名の一覧（完全一致で比較されます）
$targetCols = @("%usr", "rtps", "wtps", "%memused", "rxkB/s", "txkB/s")

# .txt ファイルをすべて処理（フォルダ内のファイルを1つずつ処理します）
Get-ChildItem -Path $inputFolder -Filter "*.txt" | ForEach-Object {

    # 現在処理中のファイル情報
    $file = $_.FullName                    # フルパス（例：C:\xxx\xxx.txt）
    $baseName = $_.BaseName               # 拡張子なしのファイル名
    $outputFile = Join-Path $outputFolder "filtered_$baseName.tsv"  # 出力ファイル名

    # 進捗表示
    Write-Host "処理中: $($_.Name) → $(Split-Path $outputFile -Leaf)"

    # 出力ファイルがすでに存在していたら削除（上書き対策）
    Remove-Item $outputFile -ErrorAction SilentlyContinue

    # ヘッダーと有効な列の初期化
    $headers = @()
    $validCols = @()

    # 入力ファイルを1行ずつ処理
    Get-Content $file | ForEach-Object {

        $line = $_.Trim()  # 行の前後の空白を除去
        $fields = $line -split "\s+" | Where-Object { $_ -ne "" }  # 空白で分割し、空要素を除外

        # ヘッダー行の検出（targetCols のどれかがこの行にある場合）
        if ($targetCols | Where-Object { $fields -contains $_ }) {

            # "Time" を先頭に追加し、現在のヘッダーを保存
            $headers = @("Time") + $fields

            # targetCols の中から、今のヘッダーに含まれるものだけ抽出（完全一致）
            $validCols = $targetCols | Where-Object { $fields -contains $_ }

            # 該当列が存在すれば、出力ファイルにヘッダー行を書き込む（タブ区切り）
            if ($validCols.Count -gt 0) {
                $csvHeader = @("Time") + $validCols
                Add-Content -Path $outputFile -Value ($csvHeader -join "`t")
            }
        }

        # ヘッダーの次にくるデータ行を処理
        elseif ($validCols.Count -gt 0) {
            $cols = $line -split "\s+" | Where-Object { $_ -ne "" }  # データ行も空白で分割し空要素除去

            # データ行の列数がヘッダーに合っているか確認（Time列除いて比較）
            if ($cols.Count -ge $headers.Count - 1) {

                # 1列目の時刻データ（例：00:00:01）を取得
                $timeValue = $cols[0]

                # 対象列のインデックスをヘッダーから取得
                $indices = $validCols | ForEach-Object { $headers.IndexOf($_) }

                # インデックスがすべて有効な場合にのみ出力
                if ($indices -notcontains -1) {

                    # 対象の列値を抽出（Time列の分だけインデックスを -1 補正）
                    $output = $indices | ForEach-Object { $cols[$_ - 1] }

                    # 時刻と抽出したデータ列を1行として結合（タブ区切り）
                    $outputLine = @($timeValue) + $output
                    Add-Content -Path $outputFile -Value ($outputLine -join "`t")
                }
            }
        }
    }
}

# 完了メッセージ
Write-Host "`nすべてのファイルの処理が完了しました。出力先: $outputFolder"
