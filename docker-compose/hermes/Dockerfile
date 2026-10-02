# Hermes + the official Claude Code CLI, so Hermes can run on the Claude subscription
# (plugin: claude-subscription-directsdk). App code lives in the image; only ./data is mounted.
FROM nousresearch/hermes-agent:latest
RUN npm install -g @anthropic-ai/claude-code && claude --version
# The CLI login lives in Hermes own data folder (bind mount), not a shared ~/.claude
ENV CLAUDE_CONFIG_DIR=/opt/data/claude
