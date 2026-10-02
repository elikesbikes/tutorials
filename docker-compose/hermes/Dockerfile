# Hermes + the official Claude Code CLI, so Hermes can run on the Claude subscription
# (plugin: claude-subscription-directsdk). App code lives in the image; only ./data is mounted.
FROM nousresearch/hermes-agent:latest
RUN npm install -g @anthropic-ai/claude-code && claude --version
# The CLI login lives in Hermes own data folder (bind mount), not a shared ~/.claude
ENV CLAUDE_CONFIG_DIR=/opt/data/claude

# Health = the gateway process answers its own /health (served by the gateway, so a dead gateway
# fails this even while the dashboard still responds). start-period covers plugin/skill sync on boot.
HEALTHCHECK --interval=30s --timeout=8s --start-period=120s --retries=3 \
  CMD ["/opt/hermes/.venv/bin/python","-c","import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8642/health',timeout=5).status==200 else 1)"]
