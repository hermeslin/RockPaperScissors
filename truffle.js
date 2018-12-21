require('@babel/register');
require('@babel/polyfill');

module.exports = {
  networks: {
    development: {
      host: "ganache-cli",
      port: 6666,
      network_id: "6666"
    }
  }
};
