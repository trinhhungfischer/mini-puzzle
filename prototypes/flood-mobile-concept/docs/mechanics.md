# Flood Mobile — Mechanics Notes

Ghi chú sống (living doc) để thêm/theo dõi các cơ chế mới cho prototype
`prototype.html` (gameplay) và `editor.html` (level editor, tách riêng).
Đây không phải GDD chính thức — chỉ là backlog ý tưởng trong giai đoạn prototype.

## File trong prototype này

| File | Vai trò |
|---|---|
| `prototype.html` | Gameplay thuần — chơi, không có công cụ dựng level |
| `editor.html` | Level Editor riêng biệt — dựng kích thước map, vẽ khối (kèm cơ chế), đặt điểm khởi đầu, xuất/nạp JSON |
| `levels/` | 44 level dựng sẵn (7 tutorial tay + 37 random, 4x4 → 8x8, số màu tăng dần) — **gameplay tải trực tiếp từ đây lúc mở trang**, xem mục riêng bên dưới |
| `docs/mechanics.md` | File này |

## Cơ chế hiện có (đã implement)

| Cơ chế | Mô tả | File / vị trí |
|---|---|---|
| Flood-fill từ điểm khởi đầu | Vùng bắt đầu ở `startIndex` (mặc định ô (0,0)), chạm màu để đổi cả vùng và gộp ô liền kề cùng màu | `prototype.html` — `onPickColor()`, `bfsRegion()` |
| Giới hạn lượt | Người chơi có `MAX_MOVES` lượt để phủ kín lưới 1 màu | `prototype.html` — biến `MAX_MOVES` |
| Lưới W×H, 5 màu (mặc định 8×8) | Kích thước/số màu rút gọn so với bản gốc; W và H độc lập (không bắt buộc vuông) | `prototype.html` — `DEFAULT_W`, `DEFAULT_H`, `DEFAULT_COLORS` |
| Chạm cùng màu = không tốn lượt | Nếu chọn đúng màu hiện tại, không tính là 1 lượt | `prototype.html` — `onPickColor()` |
| Mảnh polyomino (không bắt buộc tetromino) | Lưới được lát ngẫu nhiên bằng các mảnh liền nhau 1-4 ô (1x1, domino, L/T/S/Z/I...), mỗi mảnh là 1 đơn vị màu — không phải mọi mảnh đều 4 ô | `prototype.html`, `editor.html` — `generateRandomPieces()` / `randomizeGrid()`, `cellPieceId` |
| Ô bo tròn + khoảng cách giữa các ô (gameplay) | Visual gốc theo yêu cầu: mỗi ô có `border-radius: 6px` và cách nhau `gap: 3px` (khung `#board` bo `14px`) | `prototype.html` — CSS `.cell` |
| **Bảng màu tách biệt khỏi bảng chơi, trông rõ là nút bấm** | Palette dùng chung màu + cùng kiểu bo góc với ô trên bảng chơi nên trước đây trông như "dính" vào bảng, không rõ là khu vực điều khiển riêng. Giờ bọc trong khay nền riêng `#paletteWrap` (giống khay HUD phía trên), và mỗi nút màu có bóng đổ 3 lớp (viền đáy đặc **10px** + bóng mềm lan toả 14px/18px-blur + bevel trong 4px, tăng dần qua vài lần chỉnh theo yêu cầu — bắt đầu từ 3px) tạo cảm giác nổi hẳn lên khỏi khay — khi bấm thì bóng phẳng lại + nút lún xuống **10px** (khớp đúng độ dày viền đáy), giống nút vật lý thật bị ấn xuống sát mặt khay | `prototype.html` — CSS `#paletteWrap`, `.swatch`, `.swatch:active` |
| **Gộp khối cùng nhóm thành 1 khối bo góc liền mạch** | Các ô cùng "nhóm" (cùng 1 mảnh chưa-chiếm, hoặc mọi ô đã-chiếm gộp chung 1 nhóm "lãnh thổ") tự nối liền qua khe `gap` bằng các mảnh nối nhỏ cùng màu (`.bridge`), và chỉ bo góc ở góc thực sự nằm ngoài biên nhóm (góc mà cả 2 ô vuông góc + ô chéo đều khác nhóm) — góc nằm trong lòng nhóm bị làm vuông (`border-radius: 0`) để nối liền mạch. Kết quả: 1 mảnh nhiều ô hoặc cả vùng lãnh thổ trông như 1 khối bo góc duy nhất thay vì nhiều ô rời rạc | `prototype.html` — `groupOf()`, `addBridge()`, phần tính góc "flat" trong `renderBoard()` |
| **Đường trắng bao quanh trọn vùng lãnh thổ** | Không dùng `border` từng ô nữa (kiểu đó vẽ *bên trong* hộp mỗi ô nên bị đứt đoạn ở mọi khe hở). Thay vào đó vùng đã-chiếm được vẽ lại thành 1 hình ghép trên lớp riêng `#territoryLayer` (các ô + các bridge nối chúng), rồi dùng 4 `drop-shadow` trắng nối tiếp (±3px theo 2 trục) — hiệu ứng này "nở" alpha của cả hình ghép ra ngoài, tạo **một đường trắng liền mạch ôm trọn chu vi thật** của vùng, kể cả quanh phần bridge và các khuyết lõm | `prototype.html` — CSS `#territoryLayer`, `addTerritoryCell()`, `renderBoard()` |
| Link Gameplay ↔ Editor tự nhận ngữ cảnh | Bản deploy bật `cleanUrls` (Vercel) nên `href="editor.html"` từ route đẹp `/flood` bị phân giải thành `/editor` → không khớp route nào → 404. Hai trang giờ tự tính href lúc chạy: URL `*.html` (mở file local) → `editor.html`/`prototype.html`; `/flood` ↔ `/flood/editor`; `.../prototype` ↔ `.../editor`. Đồng thời bỏ `target="_blank"` (mở cùng tab) cho chắc chắn trên mobile và file:// | `prototype.html` (`#editorLink`), `editor.html` (`#gameplayLink`), `vercel.json` |
| Lệch toạ độ bridge (đã sửa) | Bridge/overlay định vị `absolute` trong `#board`, mà containing block là **padding box** → phải cộng `BOARD_PADDING` vào toạ độ. Trước đây thiếu bước này nên mọi bridge bị lệch lên-trái đúng 6px, rơi vào *trong lòng ô* (cùng màu nên tàng hình) còn khe hở thật vẫn tối — đây là lý do các khối "gộp" suốt nhiều vòng trước trông vẫn rời rạc/khớp nối thô | `prototype.html` — `renderBoard()` (`cellLeftPx`/`cellTopPx`) |
| Board luôn vuông từng ô | `layoutBoard()` đo chiều rộng khung chứa thực tế, trừ đi tổng khoảng `gap`, rồi tính `cellSize` nguyên (px) áp cho cả cột lẫn hàng — loại bỏ lỗi ô bị kéo dãn không đều theo chiều ngang/dọc, kể cả khi có gap | `prototype.html`, `editor.html` — `layoutBoard()` |
| Khoá thật màu không mở rộng lãnh thổ | Màu nào không có mảnh chưa-chiếm nào liền kề vùng đã chiếm sẽ bị làm tối **và vô hiệu hoá thật sự** (`disabled`, không bấm được, không tốn lượt) — trước đó chỉ làm tối nhưng vẫn bấm được và vẫn tốn lượt, gây sai luật | `prototype.html` — `frontierColors()`, `renderPalette()` (`btn.disabled`), `onPickColor()` (guard chặn cả khi bị ép gọi) |
| Load level JSON (chơi) | Tải file JSON để chơi level dựng sẵn (từ Editor hoặc tự viết tay) — chèn ngay sau vị trí hiện tại trong gói level đang chơi, Next/Back vẫn hoạt động bình thường sau đó | `prototype.html` — `loadCustomLevel()`, nút "Tải level JSON khác…" |
| **Gói level tải từ `levels/`** + Next/Back | Không còn nút "Ngẫu nhiên" trong gameplay. Lúc mở trang, `fetch()` `levels/index.json` rồi tải song song (`Promise.all`) từng file trong đó (qua `validateConfig()` — cùng bộ kiểm tra "Tải level JSON khác…" dùng) → gói 44 level thật (7 tutorial + 37 random), không còn sinh ngẫu nhiên lúc chạy nữa. "Next"/"Back" duyệt qua gói, khoá ở 2 đầu; "Chơi lại" reset đúng level đang đứng. Nếu `fetch()` thất bại (ví dụ mở file `.html` trực tiếp mà trình duyệt chặn fetch giữa các file cục bộ — tuỳ trình duyệt, không phải lúc nào cũng bị chặn) thì tự lùi về gói 5 level ngẫu nhiên như cũ (`buildRandomStarterPack()`), có log cảnh báo ở console chứ không báo lỗi cho người chơi | `prototype.html` — `buildStarterPack()`, `buildCuratedStarterPack()`, `buildRandomStarterPack()`, `levelsBaseUrl()`, `loadPackLevel()`, `pack`/`packIndex` |
| **Level Editor riêng** | Trang `editor.html` độc lập, không nằm trên UI gameplay: đặt kích thước W×H, vẽ từng khối (chọn màu, chạm ô liền kề để gộp vào khối), xoá ô khỏi khối, đặt điểm khởi đầu, **nút "Ngẫu nhiên"** để random hoá nhanh rồi chỉnh tay tiếp, xuất/nạp JSON. Ô chưa vẽ sẽ tự động lấp bằng khối 1x1 khi xuất | `editor.html` — `randomizeGrid()`, `#randomBtn` |
| Ngẫu nhiên: 2 khối liền kề không trùng màu | `randomizeGrid()` giờ dựng đồ thị kề giữa các mảnh (`buildAdjacencyFor()`) rồi tô màu kiểu greedy graph-coloring: mỗi mảnh chọn ngẫu nhiên trong các màu mà **không mảnh liền kề nào** đang dùng. Trước đây mỗi mảnh random màu độc lập nên hay bị 2 mảnh cạnh nhau trùng màu, trông như dính thành 1 mảnh lớn (gây nhầm và làm sai độ khó thật) | `editor.html` — `randomizeGrid()`, `buildAdjacencyFor()` |
| **Số lượt tối thiểu để phá đảo** | Hiển thị trong khu Import/Export, tự tính lại mỗi khi board đổi. Dùng BFS đúng nghĩa trên đồ thị trạng thái "tập mảnh đã chiếm" (không phải heuristic đoán) — vì BFS duyệt theo thứ tự số lượt tăng dần, trạng thái đầu tiên chiếm hết bàn chính là đáp án tối thiểu thật. Có giới hạn an toàn (≤80 mảnh, ≤60.000 trạng thái, ≤150ms) để không treo trình duyệt với bàn quá lớn — vượt giới hạn thì hiện "≥ N (ước tính)" thay vì số chính xác | `editor.html` — `solveMinMoves()`, `regionsFlood()`, `getEffectivePieceState()` |
| **Cơ chế khối: Ẩn màu (`hidden`)** | Khối giấu màu thật, hiện nền **xám** (`--hidden-bg: #8b919b` — trước là `#3a4252` xanh-đen, quá tối nên trông như lỗ trống thay vì một khối) + dấu "?" ở tâm khối, cho tới khi lãnh thổ đã chiếm chạm tới (liền kề) một trong các ô của khối — lúc đó lộ màu thật ngay (chưa bị chiếm, chỉ là hết ẩn). Vì `filled` chỉ tăng chứ không giảm trong 1 lượt chơi, trạng thái "đã lộ" được tính lại mỗi lần render thay vì lưu cờ riêng | `prototype.html` — `computeConcealedHiddenPieces()`, dùng trong `renderBoard()` |
| **Cơ chế khối: Băng (`ice`)** | Khối "đóng băng" `turns` lượt (đặt khi vẽ trong Editor). Trong lúc còn đóng băng: vẫn hiện đúng màu thật + lớp phủ băng + số lượt còn lại ở tâm khối, nhưng **không thể bị lãnh thổ đè lên dù trùng màu** (bfs bỏ qua khối này), và màu của nó cũng không tính vào "màu hữu ích" trong bảng chọn màu. Mỗi lượt đi thật (không phải lượt vô hiệu) trừ 1 vào bộ đếm của MỌI khối băng còn đóng băng; băng tan ngay trong lượt làm bộ đếm về 0, nên có thể bị chiếm ngay lượt đó nếu màu khớp | `prototype.html` — `isPieceFrozen()`, `bfsRegion()` (bỏ qua ô đóng băng), `frontierColors()` (loại màu của khối đang đóng băng), `onPickColor()` (trừ đếm băng trước khi tính flood) |
| Vẽ khối kèm cơ chế trong Editor | Dropdown "Cơ chế cho khối tiếp theo" (Bình thường / Ẩn màu / Băng) áp dụng cho khối đang vẽ; chọn Băng hiện thêm ô nhập số lượt tan băng. Đổi cơ chế khi đang vẽ dở sẽ cập nhật ngay khối đó (giống cách đổi màu). Khối có badge nhỏ góc trên-phải ("?" hoặc "❄N") để tác giả nhận biết — Editor luôn hiện màu thật (không giả lập ẩn) vì đây là công cụ thiết kế, không phải trải nghiệm người chơi | `editor.html` — `#mechanicSelect`, `#iceTurnsInput`, `pieceMechanicOf`, `.mechMark` |
| **Xuất JSON: chọn đúng tên file + đúng thư mục** | Ô "Tên file khi xuất" tách riêng khỏi "Tên level" (tên hiển thị trong game) — gõ thẳng tên khớp quy ước `levels/` (vd `level-45_8x8_c5.json`). Bấm "Xuất JSON": nếu trình duyệt hỗ trợ File System Access API (`showSaveFilePicker`), mở hộp thoại **Lưu** thật của hệ điều hành — chọn đúng thư mục (kể cả `prototypes/flood-mobile-concept/levels/`) và đúng tên, có thể ghi đè trực tiếp lên file cũ; nếu không hỗ trợ (hoặc bị từ chối, vd thiếu user-gesture), tự lùi về tải file thường (về Downloads) với đúng tên đã nhập, không báo lỗi | `editor.html` — `exportLevel()`, `sanitizeFilename()`, `#exportFilenameInput` |
| Import tự điền lại tên file xuất | "Tải JSON để sửa" giờ set luôn `#exportFilenameInput` = đúng tên file vừa mở — sửa xong bấm "Xuất JSON" mặc định ghi đè lại đúng file gốc thay vì phải gõ tay lại tên | `editor.html` — trong `fileInput` `change` handler |

## Cách thêm ý tưởng cơ chế mới

Copy khối dưới đây cho mỗi ý tưởng, điền vào rồi thêm vào phần "Backlog ý tưởng":

```
### [Tên cơ chế]
- **Mô tả**: ...
- **Vì sao đáng thử**: ...
- **Ảnh hưởng tới độ khó / thời gian chơi**: ...
- **Trạng thái**: Ý tưởng / Đang thử / Đã thử — kết quả / Bỏ
```

## Schema JSON cho level (dùng với "Tải JSON" ở gameplay, "Tải JSON để sửa" / "Xuất JSON" ở editor)

```json
{
  "name": "Level 01",
  "gridWidth": 6,
  "gridHeight": 8,
  "maxMoves": 12,
  "startIndex": 0,
  "colors": ["#ff6b6b", "#ffd93d", "#4f8cff", "#35c98f", "#c084fc"],
  "pieceMap": [0, 0, 1, 1, 2, 3, ...],
  "pieceColors": [0, 2, 1, 3, ...],
  "pieceMechanics": [
    { "type": "normal" },
    { "type": "hidden" },
    { "type": "ice", "turns": 3 },
    { "type": "normal" }
  ]
}
```

- `gridWidth` / `gridHeight`: số ô theo chiều ngang/dọc, độc lập nhau. 2-24 mỗi chiều.
  (Tương thích ngược: nếu file cũ chỉ có `gridSize`, cả hai chiều dùng chung giá trị đó.)
- `maxMoves`: số lượt tối đa.
- `startIndex` (tuỳ chọn, mặc định 0): chỉ số ô phẳng (row-major, `y*gridWidth+x`)
  nơi vùng chiếm bắt đầu. Đặt qua công cụ "Đặt điểm khởi đầu" trong Editor.
- `colors` (tuỳ chọn): bảng màu hex, mặc định dùng bảng 5 màu có sẵn nếu bỏ qua.
- `pieceMap`: mảng phẳng độ dài `gridWidth*gridHeight`, theo thứ tự hàng (row-major),
  mỗi phần tử là **id mảnh** mà ô đó thuộc về. Các ô cùng id nên liền kề nhau.
- `pieceColors`: mảng theo id mảnh (index = piece id), giá trị là **chỉ số màu**
  trong `colors`.
- `pieceMechanics` (tuỳ chọn, mặc định toàn bộ `{"type":"normal"}` nếu bỏ qua):
  mảng theo id mảnh, song song với `pieceColors`. Mỗi phần tử là
  `{"type":"normal"}`, `{"type":"hidden"}`, hoặc `{"type":"ice","turns":N}`
  (N nguyên dương, số lượt tới khi tan băng).
- Cách nhanh nhất để có level tuỳ chỉnh: mở `editor.html`, bấm "Ngẫu nhiên" để
  có sẵn khối rồi chỉnh tay (hoặc vẽ từ đầu), đặt điểm khởi đầu, bấm "Xuất JSON"
  — rồi vào `prototype.html` bấm "Tải level JSON khác…" chọn đúng file đó. Level
  sẽ được chèn ngay sau level đang chơi trong gói, Next/Back vẫn dùng được tiếp.
  Đã kiểm tra vòng lặp Editor → Xuất → Gameplay → Tải hoạt động đúng.

## Thư mục `levels/` — 44 level dựng sẵn (đây là bộ gameplay tải lúc mở trang)

`level-01_2x2_c3.json` … `level-44_8x8_c5.json` (44 file) + `index.json`
(manifest liệt kê cả 44 level theo đúng thứ tự chơi: file, tên, kích thước,
số màu, maxMoves, số mảnh) + `_generate.pl` (script Perl sinh **phần
random** — chạy lại bằng `perl _generate.pl <thư_mục_đích>` nếu cần bộ
level random mới; xem ghi chú quan trọng bên dưới về phần tutorial).

> **Lịch sử**: bộ ban đầu có 50 level random (đánh số 8-57, gồm cả cỡ 3x3 và
> 9 level cỡ 4x4). Theo yêu cầu, đã bỏ hẳn cỡ 3x3 và cắt 4x4 từ 9 xuống 5
> level (đúng bằng việc xoá "level 8-20" trong cách đánh số cũ), còn lại 37
> level random (8-44). Nhịp tăng màu được đổi từ hằng số cứng "13 level/bậc"
> sang tính động theo tổng số level thực tế, để vẫn chạm 5 màu ở level cuối
> dù tổng số level đổi.

### Level 1-7: Tutorial (dựng tay, không tự sinh lại)

7 level đầu (`level-01_2x2_c3.json` … `level-07_5x5_c5.json`) là level dựng
tay qua Editor (xuất từ `editor.html`), KHÔNG phải sản phẩm của
`_generate.pl` — kích thước tăng dần nhẹ (2x2 → 5x5), Tutorial 04 và 05 giới
thiệu cơ chế Ẩn màu. `_generate.pl` biết về 7 file này qua bảng
`@TUTORIALS` (metadata cứng ở đầu script, dùng để ghi đúng mục trong
`index.json`) nhưng **không bao giờ ghi đè nội dung của chúng** — script chỉ
sinh level 8 trở đi. Muốn sửa nội dung tutorial: sửa trực tiếp file JSON
(hoặc mở lại trong Editor, chỉnh, xuất, ghi đè đúng tên file), rồi cập nhật
`@TUTORIALS` trong `_generate.pl` nếu tên/kích thước/maxMoves/số mảnh đổi
(để `index.json` vẫn khớp) trước khi chạy lại script.

### Level 8-44: sinh ngẫu nhiên

- **Kích thước**: 5 cỡ lưới vuông 4x4 → 8x8, phân bố 5/8/8/8/8 level mỗi cỡ
  (tổng 37, đánh số 8-44). Cỡ 3x3 đã bị bỏ hẳn.
- **Số màu**: tăng dần theo chỉ số level toàn cục trong nhóm random (không
  theo từng cỡ riêng), chia làm 4 bậc đều nhau tính động
  (`$TIER_SIZE = ceil(tổng_level_random / 4)` = 10 với 37 level) — 10 level
  đầu dùng 2 màu, 10 tiếp 3 màu, 10 tiếp 4 màu, 7 cuối 5 màu.
- **maxMoves**: tính theo công thức `round(W*H / colorCount) + colorCount`
  (khớp đúng baseline gameplay: 8x8/5 màu → 18 lượt).
- **Không 2 mảnh cạnh nhau trùng màu**: `assign_colors()` trong
  `_generate.pl` dùng greedy graph-coloring giống `randomizeGrid()` của
  Editor — mỗi mảnh chọn màu không trùng mảnh liền kề.
- **Cơ chế khối**: toàn bộ 37 level random chỉ dùng khối "Bình thường".

### Gameplay tải bộ này thế nào

`prototype.html` lúc mở trang gọi `fetch('levels/index.json')` rồi tải song
song cả 44 file, dùng thẳng làm gói Next/Back (xem hàng "Gói level tải từ
`levels/`" ở bảng cơ chế phía trên). Nếu mở file `.html` trực tiếp và trình
duyệt chặn fetch giữa các file cục bộ, tự lùi về 5 level ngẫu nhiên tạo lúc
chạy (bộ cũ) — không phải lúc nào cũng bị chặn, tuỳ trình duyệt/thiết lập.

## Backlog ý tưởng

_(chưa có mục nào — thêm ý tưởng mới ở đây)_

## Ý tưởng đã cân nhắc nhưng cắt khỏi prototype ban đầu

- Nhiều màn chơi / độ khó tăng dần — đã có qua `levels/` (44 level, 7
  tutorial + 37 độ khó tăng dần), đã nối vào luồng chơi chính
- Lưu tiến trình (localStorage)
- Âm thanh / hiệu ứng
- Bảng xếp hạng số lượt tối thiểu
- Gợi ý / undo
- Thêm cơ chế khối khác ngoài Ẩn màu / Băng (ví dụ: khối di chuyển, khối
  nhân đôi lượt...)
