module.exports = {
  apps: [{
    name: "vsm-dashboard-borgwarner",
    script: "server.js",
    watch: false,
    instances: 1,
    exec_mode: "fork",
    env: {
      NODE_ENV: "production",
      PORT: 3001
    },
    env_production: {
      NODE_ENV: "production",
      PORT: 3001
    },
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    error_file: "./logs/error.log",
    out_file: "./logs/output.log",
    log_file: "./logs/combined.log",
    max_memory_restart: "1G",
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: "10s",
    kill_timeout: 5000
  }]
};
