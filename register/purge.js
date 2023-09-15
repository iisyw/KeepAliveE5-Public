const axios = require('axios');

/**
 * Permanently remove the deleted apps
 * @param {String} accessToken
 * @param {[String]} appNamePrefixes
 */
async function removeOldApps(accessToken, appNamePrefixes) {
  const client = axios.create({
    headers: {
      authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      ConsistencyLevel: 'eventual',
    },
  });

  const searchParams = appNamePrefixes
    .map((name) => `"displayName:${name}"`)
    .join(' OR ');

  const remove = (id) =>
    client.delete(
      `https://graph.microsoft.com/v1.0/directory/deletedItems/${id}`
    );

  const list = () =>
    client.get(
      'https://graph.microsoft.com/v1.0/directory/deleteditems/Microsoft.Graph.Application',
      {
        params: {
          $select: 'id',
          $search: searchParams,
          $count: 'true',
          $top: '999',
        },
      }
    );

  while (true) {
    const data = (await list()).data;
    if (data['@odata.count'] == 0) break;
    await Promise.all(data.value.map((obj) => remove(obj.id)));
  }
}

module.exports = removeOldApps;
