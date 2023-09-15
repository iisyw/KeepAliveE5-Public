# import time
import json
import random
import requests
from concurrent.futures import ThreadPoolExecutor
from util import multi_accounts_task, GracefulKiller

MIN_INVOKE_TIMES = 176
MAX_INVOKE_TIMES = 237
EXECUTOR_KILLER = GracefulKiller()


def config(path, data=None):
    if not data:
        with open(path, mode="r") as conf:
            return json.load(conf)

    # fast-fail
    json.loads(json.dumps(data))
    with open(path, mode="w") as conf:
        json.dump(data, conf)

    # with open(path, mode="r+") as conf:
    #     if not data:
    #         return json.load(conf)
    #     json.dump(data, conf, sort_keys=True, indent=4)


def get_access_token(app):
    try:
        return requests.post(
            "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            data={
                "grant_type": "refresh_token",
                "refresh_token": app["refresh_token"],
                "client_id": app["client_id"],
                "client_secret": app["client_secret"],
                "redirect_uri": app["redirect_uri"],
            },
        ).json()
    except Exception:
        return {}


def invoke_api(path):
    app = config(path)
    tokens = get_access_token(app)
    access_token = tokens.get("access_token", "")
    refresh_token = tokens.get("refresh_token", "")
    username = app["username"]

    if len(access_token) < 5 or len(refresh_token) < 5:
        return f"✘ 账号 [{username}] 调用失败."

    apis = [
        "https://graph.microsoft.com/v1.0/groups",
        "https://graph.microsoft.com/v1.0/sites/root",
        "https://graph.microsoft.com/v1.0/sites/root/sites",
        "https://graph.microsoft.com/v1.0/sites/root/drives",
        "https://graph.microsoft.com/v1.0/sites/root/columns",
        "https://graph.microsoft.com/v1.0/me/",
        "https://graph.microsoft.com/v1.0/me/events",
        "https://graph.microsoft.com/v1.0/me/people",
        "https://graph.microsoft.com/v1.0/me/contacts",
        "https://graph.microsoft.com/v1.0/me/calendars",
        "https://graph.microsoft.com/v1.0/me/drive",
        "https://graph.microsoft.com/v1.0/me/drive/root",
        "https://graph.microsoft.com/v1.0/me/drive/root/children",
        "https://graph.microsoft.com/v1.0/me/drive/recent",
        "https://graph.microsoft.com/v1.0/me/drive/sharedWithMe",
        "https://graph.microsoft.com/v1.0/me/onenote/pages",
        "https://graph.microsoft.com/v1.0/me/onenote/sections",
        "https://graph.microsoft.com/v1.0/me/onenote/notebooks",
        "https://graph.microsoft.com/v1.0/me/outlook/masterCategories",
        "https://graph.microsoft.com/v1.0/me/mailFolders",
        "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta",
        "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messageRules",
        "https://graph.microsoft.com/v1.0/me/messages",
        "https://graph.microsoft.com/v1.0/me/messages?$filter=importance eq 'high'",
        'https://graph.microsoft.com/v1.0/me/messages?$search="hello world"',
        "https://graph.microsoft.com/beta/me/messages?$select=internetMessageHeaders&$top",
    ]
    headers = {"Authorization": f"Bearer {access_token}"}

    def single_period(period):
        if EXECUTOR_KILLER.kill_now:
            return ""

        result = "=" * 100 + "\n"
        random.shuffle(apis)
        probability = random.random()
        for api in apis:
            if random.random() < probability:
                continue
            try:
                if requests.get(api, headers=headers).status_code == 200:
                    result += "{:>20s} | {:>6s} | {:<50s}\n".format(
                        f"账号: {username}", f"周期: {period}", f"成功: {api}"
                    )
            except Exception:
                # time.sleep(random.random()*3)
                pass

            if EXECUTOR_KILLER.kill_now:
                return result

        return result

    with ThreadPoolExecutor() as executor:
        max = random.randint(MIN_INVOKE_TIMES, MAX_INVOKE_TIMES)
        futures = [executor.submit(single_period, period) for period in range(1, max)]
        result = "".join((f.result() for f in futures))

    # save refresh_token
    app["refresh_token"] = refresh_token
    config(path, app)

    return f"{result}✔ 账号 [{username}] 调用成功."


if __name__ == "__main__":
    multi_accounts_task(invoke_api)