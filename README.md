# Gas Station Tycoon

GitHub lưu mã nguồn. Rojo đồng bộ với Roblox Studio hoặc build thành file place. GitHub Actions có thể đưa bản build lên place thử nghiệm qua Roblox Open Cloud.

## Nhập game hiện tại

Lưu bản sao game đang mở trong Studio dưới dạng Roblox XML Place (.rbxlx). Chạy `python tools/import_place.py /duong/dan/game.rbxlx` để trích script trạm và menu từ bản sao vào thư mục `src`. File place gốc được bỏ qua trong Git. Repo này hiện công khai, nên các file Luau đã push cũng công khai.

## Thử trong Studio

Chạy `rojo build -o station.rbxl`, mở bản build trong Studio, rồi bấm Play. Để sửa và xem thay đổi liên tục, chạy `rojo serve` và chọn Connect trong plugin Rojo trên bản build đang mở. Sau mỗi lần có commit mới, chạy `git pull --ff-only` trong repo local để Rojo nhận thay đổi. Bản build gồm Baseplate và hai script. Các object bạn tạo bằng tay trong Studio cần được đưa vào project Rojo trước khi triển khai.

## Tự cập nhật place thử nghiệm

1. Tạo và lưu một experience thử nghiệm riêng trên Roblox. Lấy Universe ID và Place ID của bản thử.
2. Tạo Open Cloud API key có quyền `universe-places:write` cho experience thử nghiệm.
3. Trong **Settings → Secrets and variables → Actions** của GitHub, thêm hai variables `ROBLOX_STAGING_UNIVERSE_ID` và `ROBLOX_STAGING_PLACE_ID`. Thêm API key vào **Secrets** với tên `ROBLOX_STAGING_API_KEY`.
4. Sau khi chạy thử bản build, đặt variable `ROBLOX_STAGING_ENABLED` thành `true`. Chạy workflow thủ công lần đầu trong tab **Actions**. Các lần push lên `main` có thay đổi mã hoặc cấu hình build sẽ tự cập nhật place thử nghiệm.

[Hướng dẫn Place Publishing của Roblox](https://create.roblox.com/docs/cloud/guides/usage-place-publishing)
