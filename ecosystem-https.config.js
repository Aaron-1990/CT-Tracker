module.exports = {
  apps: [{
    name: "vsm-dashboard-borgwarner-https",
    script: "server-https.js",
    watch: false,
    instances: 1,
    exec_mode: "fork",
    env: {
      NODE_ENV: "production",
      HTTP_PORT: 3001,
      HTTPS_PORT: 3443
    },
    env_production: {
      NODE_ENV: "production",
      HTTP_PORT: 3001,
      HTTPS_PORT: 3443
    },
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    error_file: "./logs/error-https.log",
    out_file: "./logs/output-https.log",
    log_file: "./logs/combined-https.log",
    max_memory_restart: "1G",
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: "10s",
    kill_timeout: 5000
  }]
};
