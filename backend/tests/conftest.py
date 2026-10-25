import sys
from pathlib import Path

# 让 `pytest` 和 `python -m pytest` 都能从 backend 根目录导入 app 包
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))
