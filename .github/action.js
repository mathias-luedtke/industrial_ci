'use strict';
var {spawnSync} = require('child_process');
console.log(process.env);
var r = spawnSync(__dirname + '/action.sh', { stdio: 'inherit'});
if (r.error) {
  throw r.error;
}
process.exit(r.status !== null ? r.status : 1);
