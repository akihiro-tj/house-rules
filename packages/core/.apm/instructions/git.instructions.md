---
description: ブランチと PR の運用
---

# git

- main に直接コミットしない。ブランチを切って PR を作り、CI が通ってからマージする（superpowers の subagent-driven-development や executing-plans は、指示がないと main に直接コミットし続けるため）
