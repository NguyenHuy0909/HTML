# Kho lưu trữ mới

Thư mục này đóng vai trò **khung khởi tạo repository** để bạn đẩy lên GitHub.

## Cấu trúc
- `README.md`: mô tả dự án và hướng dẫn đẩy mã nguồn.
- `data/`: nơi chứa dữ liệu mẫu (được giữ bằng `.gitkeep`).

## Cách commit và đẩy lên GitHub
Từ thư mục gốc dự án:

```bash
git add kho-luu-tru-moi
git commit -m "feat: add kho-luu-tru-moi scaffold"
```

Thiết lập remote (chỉ cần làm 1 lần):

```bash
git remote add origin <github-repo-url>
```

Đẩy mã nguồn lên GitHub:

```bash
git push -u origin work
```

> Nếu nhánh chính của bạn là `main`, thay `work` bằng `main`.
