'use strict';

exports.handler = async (event, context) => {
  const requestHeaders = event.Records[0].cf.request.headers;
  console.log(`Request Processed In: ${process.env.AWS_REGION}`);

  let headerTable = '<table border="1" width="100%"><thead><tr><td><h1>Header</h1></td><td><h1>Value</h1></td></tr></thead><tbody>';
  for (const [key, value] of Object.entries(requestHeaders)) {
    headerTable += `<tr><td>${key}</td><td>${value[0].value}</td></tr>`;
  }
  headerTable += '</tbody></table>';

  const content = `<html lang="en">
                    <body>
                        <table border="1" width="100%">
                        <thead>
                            <tr><td><h1>Lambda@Edge </h1></td></tr>
                        </thead>
                        <tfoot>
                            <tr><td>Lamdba@Edge </td></tr>
                        </tfoot>
                        <tbody>
                            <tr><td>Response sent by Lambda@Edge in ${process.env.AWS_REGION}</td></tr>
                        </tbody>
                        <tbody>
                        <tr><td>${headerTable}</td></tr>
                        </tbody>
                        </table>
                    </body>
                </html>`;

  const response = {
    status: '200',
    statusDescription: 'OK',
    headers: {
      'cache-control': [{ key: 'Cache-Control', value: 'max-age=100' }],
      'content-type': [{ key: 'Content-Type', value: 'text/html' }],
      'content-encoding': [{ key: 'Content-Encoding', value: 'UTF-8' }]
    },
    body: content
  };

  return response;
};
