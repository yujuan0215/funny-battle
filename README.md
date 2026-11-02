# FUNNY BATTLE · 小小反擊

Godot 4.7 側視道具反擊原型。觀察 Boss 起手，利用場地與道具讓弱小主角借力反擊。

## 本地試玩

匯入 `project.godot` 後按 F5。預設視窗 1600×900，尖刺場地鏡頭拉近 25%，UI 維持 1280×720 邏輯尺寸。

- **冒險地圖**：第 1 章「木棧前哨」可玩；第 2–6 章可查看背景、配裝與 Boss 構想，標示為規劃中。
- **試驗場**：主選單或冒險地圖右側的燒瓶圖示。保留遠端原版對打與原難度尖刺挑戰，使用獨立通關紀錄。
- **第一章**：香蕉、彈簧兩種工具；主角／Boss 各 12 HP，Boss 只有固定單拳與衝撞；有一次落橋安全繩。三次成功彈簧反擊可獲勝。
- **操作**：1／2 選工具，點橋面部署；預設 0.5×，按住 Space 進入 0.15×。R 重試、Esc 暫停。道具也會影響主角，放置前會顯示接觸範圍。

## 整體設計

[玩法、六章場地、道具解鎖與最終 Boss](docs/整體玩法與關卡設計.md)。核心循環為「觀察 → 部署 → 連鎖效果 → 反擊」，正式冒險每關最多三種工具。

首關採用像素森林背景。主選單、路線地圖、HUD 與暫停共用刻木銅框、原創像素圖示與實際配送的繁體像素字體；血條有分段與延遲損血顯示。按鈕包含滑入、按下、禁用與鍵盤焦點狀態。共同規範見 [DESIGN.md](DESIGN.md)。後續五章目前只有設計藍圖和背景草圖，尚未實作機關或 Boss。

原本的開打、干擾決鬥、閃光格檔、大亂鬥仍在 `scenes/main.tscn`。原難度尖刺為 `scenes/spikes_challenge.tscn`。遠端 `62be378` 的對打、依位置發射的彈簧與暫停 UI 保存在 `upstream/level_two/`，由試驗場進入。

素材紀錄：[森林背景與生成提示詞](assets/environments/art-direction.md)、[道具來源](assets/props/CREDITS.md)、[像素字體來源與 OFL 授權](assets/fonts/CREDITS.md)。UI 圖記與木銅九宮格由本專案原創程式繪製並快取。森林背景是原型視覺樣板，未宣稱已鎖定量產調色盤。

## 驗證

```sh
Godot --headless --editor --import --quit
Godot --headless --script res://tests/fork_test.gd
Godot --headless --fixed-fps 120 --script res://tests/test_spring_counter.gd
Godot --headless --script res://tests/test_player_feedback.gd
Godot --headless --script res://tests/test_intro_campaign.gd
Godot --headless --script res://tests/test_pixel_ui.gd
```

311 項檢查涵蓋原模式、試驗場、30／60／120 FPS 的實際香蕉／彈簧反擊、入門難度、安全繩、通關紀錄、暫停／重試、冒險藍圖與未解鎖工具阻擋，以及三種視窗比例的控制項邊界、焦點、真實 HP 與繁體字形。所有自動測試使用獨立紀錄。

開發執行檔短測可用 `Godot --script res://tools/profile_game.gd`，每場景暖機 2 秒後取樣 3 秒。M5 Pro／1600×900 本次主選單、冒險地圖、首關皆約 120 FPS；不是發布版、長時間或低階裝置保證。Metal 的 GPU 計時若為 0，代表此路徑沒有有效數據。
