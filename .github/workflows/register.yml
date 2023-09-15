name: Register APP

on:
  workflow_dispatch:

jobs:
  Register:
    runs-on: ubuntu-latest
    if: ${{ github.event.repository.private }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          ref: master
          token: ${{ secrets.PAT }}

      - name: Sync with upstream
        run: bash wrapper.sh pull

      - name: Check environment variables
        env:
          USER: ${{ secrets.USER }}
          PASSWD: ${{ secrets.PASSWD }}
        run: bash wrapper.sh check_env

      - name: Setup nodejs
        id: setup-nodejs
        uses: actions/setup-node@v3
        with:
          node-version: 18.14.2
          # cache: 'npm'
          # cache-dependency-path: '**/package.json'

      - name: Set up python
        id: setup-python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10.10'

      - name: Load cached utils
        id: cached-utils
        uses: actions/cache@v3
        with:
          path: ~/.local
          key: ${{ runner.os }}-utils-az-poetry-20230204
          restore-keys: |
            ${{ runner.os }}-utils-

      # - name: Check utils version
      #   id: utils-version
      #   run: |
      #     echo "~/.local/bin" >> $GITHUB_PATH
      #     {
      #       export PATH=~/.local/bin:$PATH
      #       [ "$(az version -o tsv --query "\"azure-cli\"")" = "2.39.0" ] && echo "az=true"
      #       poetry -V | grep -q 1.3.2 && echo "poetry=true"
      #     } 2>/dev/null | tee -a $GITHUB_OUTPUT || true

      - name: Install poetry
        # if: steps.utils-version.outputs.poetry != 'true'
        if: steps.cached-utils.outputs.cache-hit != 'true'
        uses: snok/install-poetry@v1
        with:
          version: 1.3.2
          virtualenvs-create: true
          virtualenvs-in-project: true
          installer-parallel: true

      # https://github.com/Azure/azure-cli/issues/7124
      - name: Install specific version of azure-cli
        if: steps.cached-utils.outputs.cache-hit != 'true'
        run: |
          [ "$(az version -o tsv --query "\"azure-cli\"")" = "2.39.0" ] && exit 0

          sudo apt-get remove azure-cli -y
          sudo apt-get autoremove -y
          # the default variables are fine
          # PIPX_HOME=~/.local/pipx PIPX_BIN_DIR=~/.local/bin pipx install azure-cli==2.39.0
          pipx install azure-cli==2.39.0
          # this path has been added by the previous step
          # echo "~/.local/bin" >> $GITHUB_PATH

      - name: Load cached venv
        id: cached-poetry-dependencies
        uses: actions/cache@v3
        with:
          path: .venv
          key: ${{ runner.os }}-python-${{ steps.setup-python.outputs.python-version }}-venv-${{ hashFiles('**/poetry.lock') }}

      - name: Install python dependencies
        if: steps.cached-poetry-dependencies.outputs.cache-hit != 'true'
        run: poetry install --no-interaction --no-root --only main

      - name: Load cached node dependencies
        id: cached-node-dependencies
        uses: actions/cache@v3
        with:
          path: register/node_modules
          key: ${{ runner.os }}-node-${{ steps.setup-nodejs.outputs.node-version }}-pkg-${{ hashFiles('**/package.json') }}

      - name: Install node dependencies
        if: steps.cached-node-dependencies.outputs.cache-hit != 'true'
        run: cd register && npm install

      - name: Register apps
        env:
          USER: ${{ secrets.USER }}
          PASSWD: ${{ secrets.PASSWD }}
        run: bash wrapper.sh register

      - name: Commit and push
        run: bash wrapper.sh push "generate app config"
