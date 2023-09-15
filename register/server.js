const fs = require('fs');
const qs = require('qs');
const axios = require('axios');
const express = require('express');

const configFile = process.argv[2];
const config = require(configFile);
const except = require('./except.js');
const removeOldApps = require('./purge.js');

setTimeout(() => {
  server.close();
  process.exit(1);
}, except.totalTimeout);

const app = express();

app.get('/', (req, res) => {
  res.send(req.query.code);

  server.close(async () => {
    try {
      const resp = await axios.post(
        'https://login.microsoftonline.com/common/oauth2/v2.0/token',
        qs.stringify({
          client_id: config.client_id,
          client_secret: config.client_secret,
          code: req.query.code,
          redirect_uri: config.redirect_uri,
          grant_type: 'authorization_code',
        })
      );

      config.refresh_token = resp?.data?.refresh_token || '';
      if (config.refresh_token.length < 5) {
        throw new Error('Getting token failed.');
      }
      fs.writeFileSync(configFile, JSON.stringify(config));
      removeOldApps(resp.data.access_token, config.old_app_name_prefixes).catch(
        () => {}
      );
      console.log(`✔ 账号 [${config.username}] 注册成功.`);
    } catch (error) {
      except.fatalError(config.username, error);
    }
  });
});

const server = app.listen(config.redirect_uri.match(/\d+/)[0]);
