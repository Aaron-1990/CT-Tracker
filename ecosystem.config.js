module.exports = {
  apps: [{
    name: "mi-servidor-web",
    script: "server.js",
    watch: false,
    env: {
      NODE_ENV: "production",
      PORT: 3000
    },
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    error_file: "./logs/error.log",
    out_file: "./logs/output.log",
    max_memory_restart: "500M"
  }]
};