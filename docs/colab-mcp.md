# Optional official Google Colab MCP

Google's [Colab MCP server](https://github.com/googlecolab/colab-mcp) connects a
local MCP client to a browser notebook. Clients must handle dynamic
`notifications/tools/list_changed` updates and run on the local device.

An optional Codex entry follows the
[official MCP format](https://learn.chatgpt.com/docs/extend/mcp?surface=cli):

```toml
[mcp_servers.colab]
command = "uvx"
args = ["git+https://github.com/googlecolab/colab-mcp@REVIEWED_FULL_COMMIT_SHA"]
startup_timeout_sec = 60
```

Replace the placeholder with an upstream commit you reviewed. Install `uv`,
merge into private configuration, and restart the client. No installer here
enables this server.

Verify in two stages:

1. Perform one bounded initialize/tools-list handshake and close it. This
   proves startup and discovery, not notebook access.
2. Connect the notebook with the exposed connection tool. Wait for the
   tool-list update and rediscover notebook tools. Confirm your client's
   dynamic discovery behavior before relying on it.

Initialization does not prove a browser connection. Keep notebook URLs,
cookies, OAuth state, outputs, and account details private. Runtime allocation
or execution remains a separate authorized action.
