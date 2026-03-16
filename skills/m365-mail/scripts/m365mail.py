#!/Users/paulr/clawd/skills/m365-mail/.venv/bin/python3
"""
m365mail - Microsoft 365 Mail CLI via Microsoft Graph API
Requires: pip install msal requests
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

try:
    import msal
    import requests
except ImportError:
    print("Missing dependencies. Run: pip install msal requests", file=sys.stderr)
    sys.exit(1)

# Config
CONFIG_DIR = Path.home() / ".m365mail"
TOKEN_CACHE_FILE = CONFIG_DIR / "token_cache.json"
CONFIG_FILE = CONFIG_DIR / "config.json"
GRAPH_BASE = "https://graph.microsoft.com/v1.0"
SCOPES = ["Mail.ReadWrite", "Mail.Send"]


def load_config():
    """Load client config from file."""
    if not CONFIG_FILE.exists():
        return None
    with open(CONFIG_FILE) as f:
        return json.load(f)


def save_config(client_id: str, tenant_id: str):
    """Save client config to file."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump({"client_id": client_id, "tenant_id": tenant_id}, f)
    print(f"Config saved to {CONFIG_FILE}")


def get_msal_app(config: dict) -> msal.PublicClientApplication:
    """Create MSAL app with token cache."""
    cache = msal.SerializableTokenCache()
    if TOKEN_CACHE_FILE.exists():
        cache.deserialize(TOKEN_CACHE_FILE.read_text())

    app = msal.PublicClientApplication(
        config["client_id"],
        authority=f"https://login.microsoftonline.com/{config['tenant_id']}",
        token_cache=cache,
    )
    return app, cache


def save_cache(cache: msal.SerializableTokenCache):
    """Persist token cache to disk."""
    if cache.has_state_changed:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        TOKEN_CACHE_FILE.write_text(cache.serialize())


def get_token(config: dict, interactive: bool = False) -> str:
    """Get access token, using cache or device code flow."""
    app, cache = get_msal_app(config)

    # Try silent auth first
    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(SCOPES, account=accounts[0])
        if result and "access_token" in result:
            save_cache(cache)
            return result["access_token"]

    if not interactive:
        print("No cached token. Run: m365mail auth", file=sys.stderr)
        sys.exit(1)

    # Device code flow
    flow = app.initiate_device_flow(scopes=SCOPES)
    if "user_code" not in flow:
        print(f"Auth failed: {flow.get('error_description', 'Unknown error')}", file=sys.stderr)
        sys.exit(1)

    print(flow["message"])
    result = app.acquire_token_by_device_flow(flow)

    if "access_token" in result:
        save_cache(cache)
        return result["access_token"]
    else:
        print(f"Auth failed: {result.get('error_description', 'Unknown error')}", file=sys.stderr)
        sys.exit(1)


def graph_request(token: str, endpoint: str, method: str = "GET", data: dict = None) -> dict:
    """Make a Graph API request."""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    url = f"{GRAPH_BASE}{endpoint}"
    
    if method == "GET":
        resp = requests.get(url, headers=headers)
    elif method == "POST":
        resp = requests.post(url, headers=headers, json=data)
    elif method == "PATCH":
        resp = requests.patch(url, headers=headers, json=data)
    elif method == "DELETE":
        resp = requests.delete(url, headers=headers)
        if resp.status_code == 204:
            return {"status": "deleted"}
    else:
        raise ValueError(f"Unsupported method: {method}")

    if resp.status_code >= 400:
        print(f"API Error {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)

    return resp.json() if resp.text else {}


def format_message(msg: dict, verbose: bool = False) -> dict:
    """Format a message for output."""
    result = {
        "id": msg["id"],
        "from": msg.get("from", {}).get("emailAddress", {}).get("address", ""),
        "subject": msg.get("subject", "(no subject)"),
        "received": msg.get("receivedDateTime", ""),
        "isRead": msg.get("isRead", False),
        "hasAttachments": msg.get("hasAttachments", False),
    }
    if verbose:
        result["preview"] = msg.get("bodyPreview", "")[:200]
        result["to"] = [r["emailAddress"]["address"] for r in msg.get("toRecipients", [])]
    return result


# Commands

def cmd_setup(args):
    """Configure client credentials."""
    save_config(args.client_id, args.tenant_id)


def cmd_auth(args):
    """Authenticate with device code flow."""
    config = load_config()
    if not config:
        print("Run setup first: m365mail setup --client-id <id> --tenant-id <id>", file=sys.stderr)
        sys.exit(1)
    token = get_token(config, interactive=True)
    print("Authentication successful!")


def cmd_inbox(args):
    """List inbox messages."""
    config = load_config()
    if not config:
        print("Run setup first.", file=sys.stderr)
        sys.exit(1)
    token = get_token(config)

    params = []
    params.append(f"$top={args.limit}")
    params.append("$orderby=receivedDateTime desc")
    if args.unread:
        params.append("$filter=isRead eq false")
    
    endpoint = f"/me/mailFolders/inbox/messages?{'&'.join(params)}"
    result = graph_request(token, endpoint)

    messages = [format_message(m, args.verbose) for m in result.get("value", [])]
    
    if args.json:
        print(json.dumps(messages, indent=2))
    else:
        for m in messages:
            read_marker = "  " if m["isRead"] else "● "
            attach = " 📎" if m["hasAttachments"] else ""
            print(f"{read_marker}[{m['id'][:8]}] {m['from'][:30]:<30} | {m['subject'][:50]}{attach}")
            if args.verbose and m.get("preview"):
                print(f"    {m['preview'][:100]}...")


def cmd_read(args):
    """Read a specific message."""
    config = load_config()
    token = get_token(config)

    endpoint = f"/me/messages/{args.message_id}"
    msg = graph_request(token, endpoint)

    output = {
        "id": msg["id"],
        "from": msg.get("from", {}).get("emailAddress", {}),
        "to": [r["emailAddress"] for r in msg.get("toRecipients", [])],
        "cc": [r["emailAddress"] for r in msg.get("ccRecipients", [])],
        "subject": msg.get("subject", ""),
        "received": msg.get("receivedDateTime", ""),
        "body": msg.get("body", {}).get("content", ""),
        "bodyType": msg.get("body", {}).get("contentType", ""),
        "hasAttachments": msg.get("hasAttachments", False),
    }

    if args.json:
        print(json.dumps(output, indent=2))
    else:
        print(f"From: {output['from'].get('address', '')} ({output['from'].get('name', '')})")
        print(f"To: {', '.join(r.get('address', '') for r in output['to'])}")
        if output['cc']:
            print(f"Cc: {', '.join(r.get('address', '') for r in output['cc'])}")
        print(f"Subject: {output['subject']}")
        print(f"Date: {output['received']}")
        print("-" * 60)
        # Strip HTML if needed
        body = output['body']
        if output['bodyType'] == 'html':
            import re
            body = re.sub(r'<[^>]+>', '', body)
            body = re.sub(r'\s+', ' ', body).strip()
        print(body[:args.max_length] if args.max_length else body)


def cmd_search(args):
    """Search messages."""
    config = load_config()
    token = get_token(config)

    params = [f"$top={args.limit}", "$orderby=receivedDateTime desc"]
    
    # Build filter
    filters = []
    if args.query:
        params.append(f"$search=\"{args.query}\"")
    if args.from_addr:
        filters.append(f"from/emailAddress/address eq '{args.from_addr}'")
    if args.unread:
        filters.append("isRead eq false")
    if args.has_attachments:
        filters.append("hasAttachments eq true")
    
    if filters:
        params.append(f"$filter={' and '.join(filters)}")

    endpoint = f"/me/messages?{'&'.join(params)}"
    result = graph_request(token, endpoint)

    messages = [format_message(m, args.verbose) for m in result.get("value", [])]

    if args.json:
        print(json.dumps(messages, indent=2))
    else:
        for m in messages:
            read_marker = "  " if m["isRead"] else "● "
            attach = " 📎" if m["hasAttachments"] else ""
            print(f"{read_marker}[{m['id'][:8]}] {m['from'][:30]:<30} | {m['subject'][:50]}{attach}")


def cmd_send(args):
    """Send an email."""
    config = load_config()
    token = get_token(config)

    to_recipients = [{"emailAddress": {"address": addr}} for addr in args.to]
    cc_recipients = [{"emailAddress": {"address": addr}} for addr in (args.cc or [])]

    body_content = args.body
    if args.body_file:
        body_content = Path(args.body_file).read_text()

    message = {
        "message": {
            "subject": args.subject,
            "body": {
                "contentType": "HTML" if args.html else "Text",
                "content": body_content,
            },
            "toRecipients": to_recipients,
        }
    }

    if cc_recipients:
        message["message"]["ccRecipients"] = cc_recipients

    if args.reply_to:
        message["message"]["conversationId"] = args.reply_to

    endpoint = "/me/sendMail"
    graph_request(token, endpoint, method="POST", data=message)
    print(f"Email sent to {', '.join(args.to)}")


def cmd_folders(args):
    """List mail folders."""
    config = load_config()
    token = get_token(config)

    endpoint = "/me/mailFolders?$top=50"
    result = graph_request(token, endpoint)

    folders = [{"id": f["id"], "name": f["displayName"], "unread": f.get("unreadItemCount", 0), "total": f.get("totalItemCount", 0)} for f in result.get("value", [])]

    if args.json:
        print(json.dumps(folders, indent=2))
    else:
        for f in folders:
            unread = f"({f['unread']} unread)" if f['unread'] > 0 else ""
            print(f"[{f['id'][:8]}] {f['name']:<30} {f['total']:>5} items {unread}")


def cmd_move(args):
    """Move a message to a folder."""
    config = load_config()
    token = get_token(config)

    # Resolve folder name to ID if needed
    folder_id = args.folder
    if not folder_id.startswith("AAM"):  # Likely a name, not ID
        folders_resp = graph_request(token, "/me/mailFolders?$top=50")
        for f in folders_resp.get("value", []):
            if f["displayName"].lower() == args.folder.lower():
                folder_id = f["id"]
                break

    endpoint = f"/me/messages/{args.message_id}/move"
    result = graph_request(token, endpoint, method="POST", data={"destinationId": folder_id})
    print(f"Message moved to {args.folder}")


def cmd_delete(args):
    """Delete a message."""
    config = load_config()
    token = get_token(config)

    endpoint = f"/me/messages/{args.message_id}"
    graph_request(token, endpoint, method="DELETE")
    print(f"Message {args.message_id[:8]}... deleted")


def cmd_mark(args):
    """Mark message as read/unread."""
    config = load_config()
    token = get_token(config)

    endpoint = f"/me/messages/{args.message_id}"
    graph_request(token, endpoint, method="PATCH", data={"isRead": args.read})
    status = "read" if args.read else "unread"
    print(f"Message marked as {status}")


def main():
    parser = argparse.ArgumentParser(description="Microsoft 365 Mail CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # setup
    p_setup = subparsers.add_parser("setup", help="Configure client credentials")
    p_setup.add_argument("--client-id", required=True, help="Entra ID app client ID")
    p_setup.add_argument("--tenant-id", required=True, help="Entra ID tenant ID")
    p_setup.set_defaults(func=cmd_setup)

    # auth
    p_auth = subparsers.add_parser("auth", help="Authenticate (device code flow)")
    p_auth.set_defaults(func=cmd_auth)

    # inbox
    p_inbox = subparsers.add_parser("inbox", help="List inbox messages")
    p_inbox.add_argument("-n", "--limit", type=int, default=20, help="Number of messages")
    p_inbox.add_argument("-u", "--unread", action="store_true", help="Only unread")
    p_inbox.add_argument("-v", "--verbose", action="store_true", help="Show preview")
    p_inbox.add_argument("--json", action="store_true", help="JSON output")
    p_inbox.set_defaults(func=cmd_inbox)

    # read
    p_read = subparsers.add_parser("read", help="Read a message")
    p_read.add_argument("message_id", help="Message ID (or prefix)")
    p_read.add_argument("--max-length", type=int, help="Truncate body")
    p_read.add_argument("--json", action="store_true", help="JSON output")
    p_read.set_defaults(func=cmd_read)

    # search
    p_search = subparsers.add_parser("search", help="Search messages")
    p_search.add_argument("query", nargs="?", help="Search query")
    p_search.add_argument("-f", "--from-addr", help="Filter by sender")
    p_search.add_argument("-u", "--unread", action="store_true", help="Only unread")
    p_search.add_argument("-a", "--has-attachments", action="store_true", help="Has attachments")
    p_search.add_argument("-n", "--limit", type=int, default=20, help="Number of results")
    p_search.add_argument("-v", "--verbose", action="store_true", help="Show preview")
    p_search.add_argument("--json", action="store_true", help="JSON output")
    p_search.set_defaults(func=cmd_search)

    # send
    p_send = subparsers.add_parser("send", help="Send an email")
    p_send.add_argument("--to", required=True, nargs="+", help="Recipients")
    p_send.add_argument("--cc", nargs="+", help="CC recipients")
    p_send.add_argument("--subject", required=True, help="Subject")
    p_send.add_argument("--body", help="Body text")
    p_send.add_argument("--body-file", help="Read body from file")
    p_send.add_argument("--html", action="store_true", help="Send as HTML")
    p_send.add_argument("--reply-to", help="Conversation ID to reply to")
    p_send.set_defaults(func=cmd_send)

    # folders
    p_folders = subparsers.add_parser("folders", help="List mail folders")
    p_folders.add_argument("--json", action="store_true", help="JSON output")
    p_folders.set_defaults(func=cmd_folders)

    # move
    p_move = subparsers.add_parser("move", help="Move message to folder")
    p_move.add_argument("message_id", help="Message ID")
    p_move.add_argument("folder", help="Destination folder name or ID")
    p_move.set_defaults(func=cmd_move)

    # delete
    p_delete = subparsers.add_parser("delete", help="Delete a message")
    p_delete.add_argument("message_id", help="Message ID")
    p_delete.set_defaults(func=cmd_delete)

    # mark
    p_mark = subparsers.add_parser("mark", help="Mark message read/unread")
    p_mark.add_argument("message_id", help="Message ID")
    p_mark.add_argument("--read", action="store_true", default=True, help="Mark as read")
    p_mark.add_argument("--unread", action="store_false", dest="read", help="Mark as unread")
    p_mark.set_defaults(func=cmd_mark)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
