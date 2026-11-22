from pathlib import Path

paths = [
    Path(r"D:\B2 qwen\qlnu-campus\game\write_test.txt"),
    Path(r"C:\Users\孔阿美\AppData\Roaming\Godot\write_test.txt"),
    Path(r"D:\14app\write_test.txt"),
    Path(r"C:\Users\孔阿美\AppData\Local\Temp\write_test.txt"),
]

for path in paths:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("ok", encoding="utf-8")
        print(f"OK   {path}")
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL {path}: {exc}")