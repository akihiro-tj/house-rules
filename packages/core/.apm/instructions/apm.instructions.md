---
description: house-rules から展開したファイルの扱い
applyTo: ".claude/**"
---

# APM で展開したファイル

- `apm.lock.yaml` の `deployed_files` にあるファイル（house-rules から展開した rules・skills・hooks）は直さない。`apm install` や `apm update` で黙って元に戻るため。変えたいときは house-rules のパッケージを直す
