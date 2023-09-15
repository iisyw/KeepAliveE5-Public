import os
import signal
from concurrent.futures import ThreadPoolExecutor

CONFIG_PATH = "./config"


def multi_accounts_task(fn):
    configs = []
    try:
        for path in os.listdir(CONFIG_PATH):
            configs.append(os.path.join(CONFIG_PATH, path))
    except Exception:
        pass

    if len(configs) == 0:
        print("没有找到配置文件, 请执行应用注册 Action.")
        exit(1)

    with ThreadPoolExecutor() as executor:
        for future in [executor.submit(fn, cfg) for cfg in configs]:
            print(f"{future.result()}")


class GracefulKiller:
    """https://stackoverflow.com/questions/18499497/how-to-process-sigterm-signal-gracefully"""

    kill_now = False

    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)
        # https://stackoverflow.com/questions/33242630/how-to-handle-os-system-sigkill-signal-inside-python
        # signal.signal(signal.SIGKILL, self.exit_gracefully)

    def exit_gracefully(self, *args):
        self.kill_now = True
