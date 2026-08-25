# A stdio bridge to the hosted MCP server at https://blinkcodes.com/mcp.
#
# The real server is remote — there is nothing in this repository to build or
# host. This image exists for clients and directory scanners that only speak
# stdio and want something they can `docker run`. It proxies to the same
# endpoint a native remote-MCP client would call directly, so prefer the direct
# URL if your client supports it (see README).
FROM node:22-alpine

ENV MCP_URL=https://blinkcodes.com/mcp

# Pinned: an unpinned proxy would change wire behaviour on an image rebuild.
RUN npm install -g mcp-remote@0.1.29

ENTRYPOINT ["sh", "-c", "exec npx -y mcp-remote \"$MCP_URL\""]
