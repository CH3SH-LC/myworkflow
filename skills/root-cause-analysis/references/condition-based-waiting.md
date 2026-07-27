# 条件轮询替代盲等

## 核心原则
永远用条件轮询代替固定时间 sleep。盲等 = 不稳定（等不够）+ 浪费（等太久）。

## 通用实现 (Python)
```python
import time
from typing import Callable, TypeVar
T = TypeVar('T')

def wait_for(condition: Callable[[], T | None], timeout_ms: int = 5000,
             poll_interval_ms: int = 100, description: str = "condition") -> T:
    deadline = time.monotonic() + timeout_ms / 1000
    while time.monotonic() < deadline:
        result = condition()
        if result:
            return result
        time.sleep(poll_interval_ms / 1000)
    raise TimeoutError(f"等待 {description} 超时 ({timeout_ms}ms)")
```

## 领域专用 Helper
```python
def wait_for_event(event_store, event_type, timeout_ms=5000):
    return wait_for(lambda: event_store.get(event_type),
                    timeout_ms=timeout_ms, description=f"事件 {event_type}")

def wait_for_event_count(event_store, event_type, count, timeout_ms=5000):
    return wait_for(lambda: event_store.get(event_type) 
                    if len(event_store.get_all(event_type)) >= count else None,
                    timeout_ms=timeout_ms, description=f"事件 {event_type} x{count}")

def wait_for_state(get_state, expected, timeout_ms=5000):
    return wait_for(lambda: get_state() if get_state() == expected else None,
                    timeout_ms=timeout_ms, description=f"状态 → {expected}")

def wait_for_file(path, timeout_ms=5000):
    import os
    return wait_for(lambda: path if os.path.exists(path) else None,
                    timeout_ms=timeout_ms, description=f"文件 {path}")
```

## 模式速查表
| 需求 | 模式 | 
|------|------|
| 等待事件 | wait_for_event |
| 等待状态变化 | wait_for_state |
| 等待计数 | wait_for_event_count |
| 等待文件 | wait_for_file |
| 复合条件 | 自定义 condition 函数 |

## 三种常见错误
| 错误 | 为什么错 | 修复 |
|------|---------|------|
| 轮询太快（1ms） | CPU 空转 | 50-200ms 间隔 |
| 没有超时 | 条件永不满足时永远挂 | 始终设置 timeout_ms |
| 条件访问过期数据 | lambda 捕获了旧的闭包值 | 条件函数每次重新读取当前值 |

## 何时用固定 sleep？
仅限以下——且必须注释原因：
1. 验证"在 X ms 内确实没有事件发生"（负向断言）
2. 等待 rate limiter reset window
3. 硬件/协议时序交互
